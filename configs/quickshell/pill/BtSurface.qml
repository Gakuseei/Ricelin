pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * 歯 BLUETOOTH surface: kanji header, scan with 25s auto-stop, adapter toggle,
 * a connected block on top and the nearby list below. Connected rows are
 * taller and carry a full-width battery thread fed by Peripherals (UPower),
 * since BlueZ keeps Battery1 behind Experimental; USB-dongle peripherals with
 * a battery join that block as display-only rows. Known devices use the
 * Quickshell connect/disconnect calls; unpaired devices run a bluetoothctl
 * pair-trust-connect flow with an inline ember while running and a transient
 * failure line. Standalone root surface, so Escape and the backdrop dismiss
 * it like every other surface.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    readonly property var adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var devices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []

    /**
     * BlueZ hands the cache out in arbitrary order; sort connected first,
     * then paired, then named devices, nameless MACs last so a discovery scan
     * doesn't churn the useful rows around. Reads connectedCount so a
     * connect flip re-sorts, which the raw device list never signals.
     */
    readonly property var devicesSorted: {
        var tick = Peripherals.connectedCount;
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return (d.name && d.name.length) ? 2 : 3;
        }
        return devices.slice().sort(function(a, b) {
            var r = rank(a) - rank(b);
            if (r !== 0) return r;
            return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
        });
    }

    /**
     * Rows for the connected block: every connected Bluetooth device paired
     * with its UPower battery entry by MAC, then USB-dongle peripherals that
     * have no Bluetooth counterpart. `up` is null when nothing reports charge.
     */
    readonly property var connectedRows: {
        var rows = [];
        var byMac = Peripherals.byMac;
        for (var i = 0; i < devicesSorted.length; i++) {
            var d = devicesSorted[i];
            if (!d || !d.connected) continue;
            rows.push({ bt: d, up: byMac[String(d.address || "").toUpperCase()] || null });
        }
        var usb = Peripherals.usb;
        for (var j = 0; j < usb.length; j++)
            rows.push({ bt: null, up: usb[j] });
        return rows;
    }
    readonly property var nearbyRows: devicesSorted.filter(function(d) { return d && !d.connected; })
    readonly property bool discovering: adapter ? adapter.discovering === true : false

    property string pairingAddress: ""
    property string failedAddress: ""

    /**
     * Address of the known device whose inline confirm row (disconnect or
     * connect, plus forget) is open, mirroring the wifi surface's expanded
     * SSID.
     */
    property string expandedAddress: ""

    implicitHeight: listFrame.y + listFrame.height

    /**
     * Maps the BlueZ device-class icon name onto a baked glyph: audio gear reads
     * as a speaker, input devices as their shape, displays and computers as a
     * monitor, players as a note; anything unknown falls back to bluetooth.
     */
    function iconFor(d) {
        var ic = (d && d.icon) ? String(d.icon) : "";
        if (ic.indexOf("audio-") === 0 || ic === "audio-card") return "speaker";
        if (ic === "input-mouse") return "mouse";
        if (ic === "input-keyboard") return "keyboard";
        if (ic === "input-gaming") return "gamepad";
        if (ic === "video-display" || ic === "computer") return "monitor";
        if (ic === "multimedia-player") return "music";
        return "bluetooth";
    }

    function metaFor(d) {
        if (!d) return "";
        var parts = [];
        if (d.paired) parts.push("paired");
        if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
            var st = BluetoothDeviceState.toString(d.state);
            if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
        }
        if (d.address && d.address.length) parts.push(d.address);
        return parts.join(" · ");
    }

    function batteryFor(row) {
        if (row.up) return Peripherals.pct(row.up);
        var d = row.bt;
        if (!d || d.battery === undefined || d.battery === null || d.battery <= 0) return -1;
        return Math.round(d.battery <= 1 ? d.battery * 100 : d.battery);
    }

    function rowName(row) {
        if (row.bt) return row.bt.deviceName || row.bt.name || "Unknown";
        return (row.up && row.up.model) ? row.up.model : "Unknown";
    }

    /**
     * Click dispatch for a device row. A connected or paired device toggles
     * the inline confirm row rather than acting at once; an unpaired device
     * runs the bluetoothctl pair-trust-connect flow.
     */
    function activateDevice(d) {
        if (!d)
            return;
        if (d.connected || d.paired) {
            var addr = d.address || "";
            expandedAddress = (addr.length && expandedAddress === addr) ? "" : addr;
            return;
        }
        pairDevice(d);
    }

    function connectDevice(d) {
        expandedAddress = "";
        if (d && typeof d.connect === "function")
            d.connect();
    }

    function disconnectDevice(d) {
        expandedAddress = "";
        if (d && typeof d.disconnect === "function")
            d.disconnect();
    }

    /**
     * Unpairs through the Quickshell device object, the same layer the
     * connect and disconnect calls use; BlueZ drops the bond and the row
     * falls back to its Pair chip.
     */
    function forgetDevice(d) {
        expandedAddress = "";
        if (d && typeof d.forget === "function")
            d.forget();
    }

    function pairDevice(d) {
        if (!d || !d.address || pairProc.running)
            return;
        pairingAddress = d.address;
        failedAddress = "";
        pairProc.command = ["sh", "-c",
            'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
            "sh", d.address];
        pairProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            if (adapter && adapter.enabled) {
                adapter.discovering = true;
                scanTimer.restart();
            }
        } else {
            scanTimer.stop();
            expandedAddress = "";
            if (adapter && adapter.discovering)
                adapter.discovering = false;
        }
    }

    Timer {
        id: scanTimer
        interval: 25000
        repeat: false
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    Timer {
        id: failTimer
        interval: 4000
        repeat: false
        onTriggered: root.failedAddress = ""
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            var addr = root.pairingAddress;
            root.pairingAddress = "";
            if (exitCode !== 0) {
                root.failedAddress = addr;
                failTimer.restart();
            }
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                text: "歯"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.adapter ? root.adapter.enabled === true : false
                text: root.discovering ? "Scanning…" : "Scan"
                color: root.discovering ? Theme.vermLit : Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.adapter)
                            return;
                        root.adapter.discovering = !root.adapter.discovering;
                        if (root.adapter.discovering)
                            scanTimer.restart();
                        else
                            scanTimer.stop();
                    }
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.adapter ? root.adapter.enabled === true : false
                onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    component Eyebrow: Item {
        property string label: ""
        width: parent ? parent.width : 0
        height: 18 * root.s

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2 * root.s
            text: parent.label
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4 * root.s
        }
    }

    /**
     * Inline confirm row under a known device: Disconnect or Connect plus
     * Forget, shared by the connected block and the nearby list.
     */
    component ConfirmRow: Item {
        id: confirm
        property var dev: null
        property bool connected: false
        width: parent ? parent.width : 0
        height: 30 * root.s

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10 * root.s
            anchors.right: confirmBtns.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: confirm.connected ? "Connected" : "Paired"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Row {
            id: confirmBtns
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: primaryLabel.implicitWidth + 20 * root.s
                height: 22 * root.s
                radius: 7 * root.s
                color: primaryArea.containsMouse ? Theme.tileBg : "transparent"
                border.width: 1
                border.color: primaryArea.containsMouse ? Theme.vermDim : Theme.border

                Text {
                    id: primaryLabel
                    anchors.centerIn: parent
                    text: confirm.connected ? "Disconnect" : "Connect"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3 * root.s
                }

                MouseArea {
                    id: primaryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirm.connected
                        ? root.disconnectDevice(confirm.dev)
                        : root.connectDevice(confirm.dev)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: forgetLabel.implicitWidth + 20 * root.s
                height: 22 * root.s
                radius: 7 * root.s
                color: forgetArea.containsMouse
                    ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.2)
                    : Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.45)

                Text {
                    id: forgetLabel
                    anchors.centerIn: parent
                    text: "Forget"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.3 * root.s
                }

                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.forgetDevice(confirm.dev)
                }
            }
        }
    }

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property bool empty: root.connectedRows.length === 0 && root.nearbyRows.length === 0
        height: empty ? 24 * root.s : Math.min(devCol.implicitHeight, 260 * root.s)

        Text {
            visible: listFrame.empty
            anchors.centerIn: parent
            text: root.discovering ? "Scanning…" : "No devices found"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
        }

        Flickable {
            id: devFlick
            visible: !listFrame.empty
            anchors.fill: parent
            contentHeight: devCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devCol
                width: devFlick.width
                spacing: 2 * root.s

                Eyebrow {
                    visible: root.connectedRows.length > 0
                    label: "CONNECTED"
                }

                Repeater {
                    model: root.connectedRows

                    Column {
                        id: conItem
                        required property var modelData
                        readonly property var bt: modelData ? modelData.bt : null
                        readonly property var up: modelData ? modelData.up : null
                        readonly property string addr: (bt && bt.address) ? bt.address : ""
                        readonly property int battery: root.batteryFor(modelData)
                        readonly property bool hasBattery: battery >= 0
                        readonly property bool charging: up ? Peripherals.charging(up) : false
                        readonly property bool low: hasBattery && !charging && battery <= Peripherals.lowAt
                        readonly property bool confirming: addr.length > 0 && root.expandedAddress === addr
                        readonly property bool busy: (bt && typeof BluetoothDeviceState !== "undefined")
                            ? bt.state === BluetoothDeviceState.Disconnecting : false
                        width: devCol.width
                        spacing: 2 * root.s

                        Rectangle {
                            width: parent.width
                            height: 50 * root.s
                            radius: 10 * root.s
                            color: (conHover.hovered && conItem.bt) ? Theme.frameBg : "transparent"

                            HoverHandler { id: conHover }

                            MouseArea {
                                anchors.fill: parent
                                enabled: conItem.bt !== null
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateDevice(conItem.bt)
                            }

                            Rectangle {
                                id: conTile
                                anchors.left: parent.left
                                anchors.leftMargin: 6 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32 * root.s
                                height: 32 * root.s
                                radius: 9 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: conItem.low ? Qt.alpha(Theme.vermLit, 0.55) : Theme.border

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 17 * root.s
                                    height: 17 * root.s
                                    name: conItem.bt ? root.iconFor(conItem.bt) : Peripherals.glyphFor(conItem.up)
                                    color: Theme.vermLit
                                    stroke: 1.7
                                }
                            }

                            Item {
                                anchors.left: conTile.right
                                anchors.leftMargin: 11 * root.s
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 8 * root.s
                                anchors.bottomMargin: 10 * root.s

                                Row {
                                    id: nameRow
                                    anchors.left: parent.left
                                    anchors.right: conRight.left
                                    anchors.rightMargin: 8 * root.s
                                    anchors.top: parent.top
                                    spacing: 6 * root.s

                                    Text {
                                        id: conName
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, nameRow.width - (usbTag.visible ? usbTag.width + nameRow.spacing : 0))
                                        text: root.rowName(conItem.modelData)
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 12 * root.s
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        id: usbTag
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: conItem.bt === null
                                        width: usbLabel.implicitWidth + 8 * root.s
                                        height: 13 * root.s
                                        radius: 4 * root.s
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.hair

                                        Text {
                                            id: usbLabel
                                            anchors.centerIn: parent
                                            text: "USB"
                                            color: Theme.faint
                                            font.family: Theme.font
                                            font.pixelSize: 7.5 * root.s
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: 1 * root.s
                                        }
                                    }
                                }

                                Row {
                                    id: conRight
                                    anchors.right: parent.right
                                    anchors.verticalCenter: nameRow.verticalCenter
                                    spacing: 5 * root.s

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: conItem.busy
                                        width: 4 * root.s
                                        height: 4 * root.s
                                        radius: width / 2
                                        color: Theme.flameGlow

                                        SequentialAnimation on opacity {
                                            running: conItem.busy
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    GlyphIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: conItem.charging
                                        width: 10 * root.s
                                        height: 10 * root.s
                                        name: "bolt"
                                        color: Theme.flameGlow
                                        stroke: 2
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: conItem.hasBattery
                                        text: conItem.battery + "%"
                                        color: conItem.low ? Theme.vermLit : (conItem.charging ? Theme.flameGlow : Theme.subtle)
                                        font.family: Theme.font
                                        font.pixelSize: 11 * root.s
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                    }
                                }

                                Filament {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    visible: conItem.hasBattery
                                    s: root.s
                                    kind: "battery"
                                    level: Math.max(0, conItem.battery) / 100
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2 * root.s
                                    visible: !conItem.hasBattery
                                    text: "No battery reading"
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9 * root.s
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        ConfirmRow {
                            visible: conItem.confirming
                            dev: conItem.bt
                            connected: true
                        }
                    }
                }

                Eyebrow {
                    visible: root.connectedRows.length > 0 && root.nearbyRows.length > 0
                    label: "NEARBY"
                }

                Repeater {
                    model: root.nearbyRows

                    Column {
                        id: devItem
                        required property var modelData
                        readonly property bool isPaired: modelData ? modelData.paired === true : false
                        readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
                        readonly property bool pairing: addr.length > 0 && root.pairingAddress === addr
                        readonly property bool failed: addr.length > 0 && root.failedAddress === addr
                        readonly property bool busy: (modelData && typeof BluetoothDeviceState !== "undefined")
                            ? modelData.state === BluetoothDeviceState.Connecting : false
                        readonly property bool confirming: addr.length > 0 && root.expandedAddress === addr
                        width: devCol.width
                        spacing: 2 * root.s

                        Rectangle {
                            width: parent.width
                            height: 38 * root.s
                            radius: 9 * root.s
                            color: rowHover.hovered ? Theme.frameBg : "transparent"

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateDevice(devItem.modelData)
                            }

                            Rectangle {
                                id: devTile
                                anchors.left: parent.left
                                anchors.leftMargin: 6 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: 8 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: Theme.border

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    name: root.iconFor(devItem.modelData)
                                    color: Theme.iconDim
                                    stroke: 1.7
                                }
                            }

                            Column {
                                anchors.left: devTile.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: devRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1 * root.s

                                Text {
                                    width: parent.width
                                    text: devItem.modelData ? (devItem.modelData.deviceName || devItem.modelData.name || "Unknown") : "Unknown"
                                    color: Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 11.5 * root.s
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: root.metaFor(devItem.modelData)
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * root.s
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: devRight
                                anchors.right: parent.right
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.pairing || devItem.busy
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: devItem.pairing || devItem.busy
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !devItem.isPaired && !devItem.pairing
                                    radius: 999
                                    color: pairArea.containsMouse ? Theme.frameBg : Theme.tileBg
                                    border.width: 1
                                    border.color: pairArea.containsMouse ? Theme.vermDim : Theme.border
                                    height: 18 * root.s
                                    width: pairText.implicitWidth + 16 * root.s
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                    Text {
                                        id: pairText
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: pairArea.containsMouse ? Theme.cream : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 9.5 * root.s
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: pairArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activateDevice(devItem.modelData)
                                    }
                                }
                            }
                        }

                        ConfirmRow {
                            visible: devItem.confirming
                            dev: devItem.modelData
                            connected: false
                        }

                        Text {
                            visible: devItem.failed
                            text: "Pairing failed"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 42 * root.s
                        }
                    }
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: devFlick
        }
    }
}
