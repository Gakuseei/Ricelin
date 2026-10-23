pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * 歯 BLUETOOTH surface: connected devices with their battery on top, nearby ones below; unknown devices pair through bluetoothctl.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    readonly property var adapter: Net.btAdapter
    readonly property bool btOn: Net.btOn
    readonly property var devices: Bluetooth.devices.values

    /** Connected, then paired, then named, nameless last; reads connectedCount because a connect flip never touches the list. */
    readonly property var devicesSorted: {
        var tick = Peripherals.connectedCount;
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return root.nameOf(d).length ? 2 : 3;
        }
        return devices.slice().sort(function(a, b) {
            var r = rank(a) - rank(b);
            if (r !== 0) return r;
            return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
        });
    }

    /** Connected Bluetooth devices paired with their UPower battery by MAC, then USB-dongle peripherals; `up` is null without a reading. */
    readonly property var connectedRows: {
        var rows = [];
        var byMac = Peripherals.byMac;
        for (var i = 0; i < devicesSorted.length; i++) {
            var d = devicesSorted[i];
            if (!d || !d.connected) continue;
            rows.push({ key: d, bt: d, up: byMac[String(d.address || "").toUpperCase()] || null });
        }
        var usb = Peripherals.usb;
        for (var j = 0; j < usb.length; j++)
            rows.push({ key: usb[j], bt: null, up: usb[j] });
        return rows;
    }
    readonly property var nearbyRows: btOn ? devicesSorted.filter(function(d) { return d && !d.connected; }) : []
    readonly property bool hasRows: connectedRows.length > 0 || nearbyRows.length > 0
    readonly property bool discovering: adapter ? adapter.discovering === true : false

    /** Keyboard order: connected Bluetooth devices, then nearby ones. */
    readonly property var navDevices: connectedRows.filter(function(r) { return r.bt !== null; })
        .map(function(r) { return r.bt; }).concat(nearbyRows)

    property string pairingAddress: ""
    property string failedAddress: ""
    property string expandedAddress: ""
    property string kbAddr: ""

    implicitHeight: listFrame.y + listFrame.height

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

    /** The device's own name, or empty when BlueZ only echoes the address back as one. */
    function nameOf(d) {
        var n = d ? String(d.deviceName || d.name || "") : "";
        if (n.length && d.address && n.replace(/[-_]/g, ":").toUpperCase() === String(d.address).toUpperCase())
            return "";
        return n;
    }

    function metaFor(d, pairing) {
        if (!d) return "";
        var parts = [];
        if (pairing) parts.push("Pairing…");
        else if (d.state === BluetoothDeviceState.Connecting) parts.push("Connecting…");
        else if (d.paired) parts.push("Paired");
        if (!nameOf(d).length && d.address) parts.push(d.address);
        return parts.join(" · ");
    }

    function batteryFor(row) {
        if (row.up) return Peripherals.pct(row.up);
        var d = row.bt;
        if (!d || d.battery === undefined || d.battery === null || d.battery <= 0) return -1;
        return Math.round(d.battery <= 1 ? d.battery * 100 : d.battery);
    }

    function rowName(row) {
        if (row.bt) return nameOf(row.bt) || "Unknown device";
        return (row.up && row.up.model) ? row.up.model : "Unknown device";
    }

    /** A connected or paired device opens its confirm row; an unpaired one pairs. */
    function activateDevice(d) {
        if (!d)
            return;
        kbAddr = d.address || "";
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

    function setScan(on) {
        if (!adapter)
            return;
        adapter.discovering = on;
        if (on)
            scanTimer.restart();
        else
            scanTimer.stop();
    }

    function back() {
        if (expandedAddress.length) {
            expandedAddress = "";
            return true;
        }
        return false;
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            var list = navDevices;
            if (!list.length)
                return false;
            var down = e.key === Qt.Key_Down;
            var i = -1;
            for (var k = 0; k < list.length; k++)
                if ((list[k].address || "") === kbAddr)
                    i = k;
            i = i < 0 ? (down ? 0 : list.length - 1) : Math.max(0, Math.min(list.length - 1, i + (down ? 1 : -1)));
            kbAddr = list[i].address || "";
            reveal(kbAddr);
            return true;
        }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (e.isAutoRepeat)
                return true;
            var d = navDevices.find(function(x) { return (x.address || "") === root.kbAddr; });
            if (!d)
                return false;
            activateDevice(d);
            return true;
        }
        return false;
    }

    function reveal(addr) {
        var reps = [conRep, nearRep];
        for (var r = 0; r < reps.length; r++) {
            for (var i = 0; i < reps[r].count; i++) {
                var it = reps[r].itemAt(i);
                if (it && it.addr === addr) {
                    if (it.y < devFlick.contentY)
                        devFlick.contentY = it.y;
                    else if (it.y + it.height > devFlick.contentY + devFlick.height)
                        devFlick.contentY = it.y + it.height - devFlick.height;
                    return;
                }
            }
        }
    }

    onActiveChanged: {
        if (active) {
            if (btOn)
                setScan(true);
        } else {
            scanTimer.stop();
            expandedAddress = "";
            kbAddr = "";
            if (adapter && adapter.discovering)
                adapter.discovering = false;
        }
    }

    onBtOnChanged: if (btOn && active) setScan(true)

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

    component Pulse: Rectangle {
        id: pulse
        property bool on: false
        visible: on
        width: 4 * root.s
        height: 4 * root.s
        radius: width / 2
        color: Theme.flameGlow

        SequentialAnimation on opacity {
            running: pulse.on && !Motion.calm
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
        }
    }

    SurfaceHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s
        s: root.s
        glyph: "歯"
        title: "Bluetooth"

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp.s * root.s

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.btOn
                s: root.s
                kind: "ghost"
                text: root.discovering ? "Scanning…" : "Scan"
                lit: root.discovering
                onClicked: root.setScan(!root.discovering)
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.btOn
                onToggled: Net.toggleBt()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: Theme.sp.s * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Column {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: Theme.sp.xs * root.s
        anchors.left: parent.left
        anchors.right: parent.right

        Item {
            visible: root.hasRows
            width: parent.width
            height: root.hasRows ? Math.min(devCol.implicitHeight, 260 * root.s) : 0

            Flickable {
                id: devFlick
                anchors.fill: parent
                contentHeight: devCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: devCol
                    width: devFlick.width
                    spacing: Theme.sp.xxs * root.s
                    move: Transition {
                        enabled: !Motion.calm
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    SettingsLabel {
                        visible: root.connectedRows.length > 0
                        s: root.s
                        text: "Connected"
                        leftPadding: Theme.sp.s * root.s
                        topPadding: Theme.sp.xs * root.s
                        bottomPadding: Theme.sp.xs * root.s
                    }

                    Repeater {
                        id: conRep
                        model: ScriptModel {
                            values: root.connectedRows
                            objectProp: "key"
                        }

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
                            readonly property bool busy: bt ? bt.state === BluetoothDeviceState.Disconnecting : false
                            readonly property bool lit: addr.length > 0 && root.kbAddr === addr
                            width: devCol.width
                            spacing: Theme.sp.xxs * root.s

                            Rectangle {
                                width: parent.width
                                height: 50 * root.s
                                radius: Theme.r.m * root.s
                                color: conPress.pressed ? Theme.pressBg : (conItem.lit ? Theme.frameBg : "transparent")
                                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                HoverHandler {
                                    onHoveredChanged: if (hovered && conItem.addr.length) root.kbAddr = conItem.addr
                                }

                                MouseArea {
                                    id: conPress
                                    anchors.fill: parent
                                    enabled: conItem.bt !== null
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activateDevice(conItem.bt)
                                }

                                Rectangle {
                                    id: conTile
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32 * root.s
                                    height: 32 * root.s
                                    radius: Theme.r.m * root.s
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
                                    anchors.leftMargin: Theme.sp.m * root.s
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.sp.m * root.s
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.topMargin: Theme.sp.s * root.s
                                    anchors.bottomMargin: Theme.sp.m * root.s

                                    Row {
                                        id: nameRow
                                        anchors.left: parent.left
                                        anchors.right: conRight.left
                                        anchors.rightMargin: Theme.sp.s * root.s
                                        anchors.top: parent.top
                                        spacing: Theme.sp.s * root.s

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, nameRow.width - (usbTag.visible ? usbTag.width + nameRow.spacing : 0))
                                            text: root.rowName(conItem.modelData)
                                            color: Theme.cream
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fs.body * root.s
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            id: usbTag
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: conItem.bt === null
                                            width: usbLabel.implicitWidth + Theme.sp.s * root.s
                                            height: usbLabel.implicitHeight + Theme.sp.xxs * root.s
                                            radius: Theme.r.xs * root.s
                                            color: "transparent"
                                            border.width: 1
                                            border.color: Theme.hair

                                            Text {
                                                id: usbLabel
                                                anchors.centerIn: parent
                                                text: "USB"
                                                color: Theme.textFaint
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fs.label * root.s
                                                font.weight: Font.Bold
                                                font.capitalization: Font.AllUppercase
                                                font.letterSpacing: Theme.labelTracking * root.s
                                            }
                                        }
                                    }

                                    Row {
                                        id: conRight
                                        anchors.right: parent.right
                                        anchors.verticalCenter: nameRow.verticalCenter
                                        spacing: Theme.sp.xs * root.s

                                        Pulse {
                                            anchors.verticalCenter: parent.verticalCenter
                                            on: conItem.busy
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
                                            font.pixelSize: Theme.fs.meta * root.s
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
                                        anchors.bottomMargin: -Theme.sp.xs * root.s
                                        visible: !conItem.hasBattery
                                        text: "No battery reading"
                                        color: Theme.textFaint
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fs.meta * root.s
                                    }
                                }
                            }

                            ConfirmRow {
                                visible: conItem.confirming
                                s: root.s
                                inset: Theme.sp.s
                                status: "Connected"

                                Button {
                                    s: root.s
                                    text: "Disconnect"
                                    onClicked: root.disconnectDevice(conItem.bt)
                                }
                                Button {
                                    s: root.s
                                    kind: "danger"
                                    text: "Forget"
                                    onClicked: root.forgetDevice(conItem.bt)
                                }
                            }
                        }
                    }

                    SettingsLabel {
                        visible: root.connectedRows.length > 0 && root.nearbyRows.length > 0
                        s: root.s
                        text: "Nearby"
                        leftPadding: Theme.sp.s * root.s
                        topPadding: Theme.sp.s * root.s
                        bottomPadding: Theme.sp.xs * root.s
                    }

                    Repeater {
                        id: nearRep
                        model: ScriptModel {
                            values: root.nearbyRows
                        }

                        Column {
                            id: devItem
                            required property var modelData
                            readonly property bool isPaired: modelData ? modelData.paired === true : false
                            readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
                            readonly property bool pairing: addr.length > 0 && root.pairingAddress === addr
                            readonly property bool failed: addr.length > 0 && root.failedAddress === addr
                            readonly property bool busy: modelData ? modelData.state === BluetoothDeviceState.Connecting : false
                            readonly property bool confirming: addr.length > 0 && root.expandedAddress === addr
                            readonly property bool lit: addr.length > 0 && root.kbAddr === addr
                            readonly property string meta: root.metaFor(modelData, pairing)
                            width: devCol.width
                            spacing: Theme.sp.xxs * root.s

                            Rectangle {
                                width: parent.width
                                height: 40 * root.s
                                radius: Theme.r.m * root.s
                                color: devPress.pressed ? Theme.pressBg : (devItem.lit ? Theme.frameBg : "transparent")
                                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                HoverHandler {
                                    onHoveredChanged: if (hovered && devItem.addr.length) root.kbAddr = devItem.addr
                                }

                                MouseArea {
                                    id: devPress
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activateDevice(devItem.modelData)
                                }

                                Rectangle {
                                    id: devTile
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26 * root.s
                                    height: 26 * root.s
                                    radius: Theme.r.s * root.s
                                    color: Theme.tileBg
                                    border.width: 1
                                    border.color: Theme.border

                                    GlyphIcon {
                                        anchors.centerIn: parent
                                        width: 15 * root.s
                                        height: 15 * root.s
                                        name: root.iconFor(devItem.modelData)
                                        color: devItem.lit ? Theme.cream : Theme.iconDim
                                        stroke: 1.7
                                    }
                                }

                                Column {
                                    anchors.left: devTile.right
                                    anchors.leftMargin: Theme.sp.m * root.s
                                    anchors.right: devRight.left
                                    anchors.rightMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.sp.xxs * root.s

                                    Text {
                                        width: parent.width
                                        text: root.nameOf(devItem.modelData) || "Unknown device"
                                        color: devItem.lit ? Theme.cream : Theme.subtle
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fs.body * root.s
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        visible: devItem.meta.length > 0
                                        text: devItem.meta
                                        color: Theme.textFaint
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fs.meta * root.s
                                        elide: Text.ElideRight
                                    }
                                }

                                Row {
                                    id: devRight
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.sp.s * root.s

                                    Pulse {
                                        anchors.verticalCenter: parent.verticalCenter
                                        on: devItem.pairing || devItem.busy
                                    }

                                    Button {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !devItem.isPaired && !devItem.pairing
                                        s: root.s
                                        text: "Pair"
                                        onClicked: root.activateDevice(devItem.modelData)
                                    }
                                }
                            }

                            ConfirmRow {
                                visible: devItem.confirming
                                s: root.s
                                inset: Theme.sp.s
                                status: "Paired"

                                Button {
                                    s: root.s
                                    kind: "primary"
                                    text: "Connect"
                                    onClicked: root.connectDevice(devItem.modelData)
                                }
                                Button {
                                    s: root.s
                                    kind: "danger"
                                    text: "Forget"
                                    onClicked: root.forgetDevice(devItem.modelData)
                                }
                            }

                            Text {
                                visible: devItem.failed
                                text: "Pairing failed, try again"
                                color: Theme.danger
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.meta * root.s
                                leftPadding: 46 * root.s
                                bottomPadding: Theme.sp.xs * root.s
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

        EmptyState {
            visible: !root.btOn
            anchors.horizontalCenter: parent.horizontalCenter
            s: root.s
            glyph: "bluetooth"
            text: "Bluetooth is off"
            action: "Turn on"
            onTriggered: Net.toggleBt()
        }

        EmptyState {
            visible: root.btOn && !root.hasRows
            anchors.horizontalCenter: parent.horizontalCenter
            s: root.s
            glyph: "bluetooth"
            text: root.discovering ? "Looking for devices…" : "No devices found"
            action: root.discovering ? "Stop" : "Scan"
            onTriggered: root.setScan(!root.discovering)
        }
    }
}
