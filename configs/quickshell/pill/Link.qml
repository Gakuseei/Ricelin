pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import "Singletons"

/**
 * 繋 LINK surface: connectivity rows (auto-detected Netz, Bluetooth) over the
 * 報 INBOX notification center, with WLAN and Bluetooth drill-in subviews that
 * cross-fade in place. Owns the `subview` state machine and exposes
 * `desiredW`, `emberX`/`emberY` (flame dock point on the 報 marker) and
 * `back()` for the pill's morph and Escape plumbing. Opening marks all
 * notifications seen after a short beat so unread embers register first.
 */
Item {
    id: root

    property real s: 1
    property bool active: false
    property string subview: "main"

    readonly property real desiredW: (subview === "wifi" ? 272 : subview === "bt" ? 286 : 330) * s

    readonly property point emberPoint: {
        void root.width;
        void root.height;
        void mainCol.implicitHeight;
        void root.subview;
        return inboxKanji.mapToItem(root, inboxKanji.width / 2, inboxKanji.height / 2);
    }
    readonly property real emberX: emberPoint.x
    readonly property real emberY: emberPoint.y

    implicitHeight: subview === "wifi" ? wifiPage.implicitHeight
        : subview === "bt" ? btPage.implicitHeight
        : mainCol.implicitHeight

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var eth: netDevices.find(function(d) { return d && d.type === DeviceType.Wired && d.connected }) || null
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wired: eth !== null

    readonly property real ethSpeed: (eth && eth.linkSpeed) ? eth.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""

    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null

    readonly property string netzSubText: wired
        ? ("Ethernet"
            + (ethSpeedText.length ? " · " + ethSpeedText : "")
            + (ethIp.length ? " · " + ethIp : ""))
        : (wifiActive ? (wifiActive.name || "") : (wifiOn ? "Nicht verbunden" : "Aus"))

    readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property var btConnected: btDevices.filter(function(d) { return d && d.connected })
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false
    readonly property var btPrimary: btConnected.length > 0 ? btConnected[0] : null
    readonly property int btBattery: batteryLevel(btPrimary)

    readonly property string btSubText: !btOn ? "Aus"
        : (btPrimary
            ? ((btPrimary.deviceName || btPrimary.name || "Unknown")
                + (btConnected.length > 1 ? " +" + (btConnected.length - 1) : ""))
            : "Keine Verbindung")

    property string ethIp: ""

    /**
     * Pops one navigation level: drill-in back to main returns true, main
     * returns false so the caller closes the surface instead.
     */
    function back() {
        if (subview !== "main") {
            subview = "main";
            return true;
        }
        return false;
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    onActiveChanged: {
        if (active) {
            subview = "main";
            seenTimer.restart();
        } else {
            seenTimer.stop();
        }
    }

    Timer {
        id: seenTimer
        interval: 600
        repeat: false
        onTriggered: Notifs.markAllSeen()
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global up | awk '{for(i=1;i<=NF;i++) if($i==\"inet\"){print $(i+1); exit}}' | cut -d/ -f1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.ethIp = this.text.trim() }
    }

    Timer {
        interval: 15000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    /**
     * Minimal warm toggle: matte tile at rest, terracotta fill when on, cream
     * knob sliding with the fast motion token.
     */
    component LinkToggle: Rectangle {
        id: toggle
        property bool on: false
        signal toggled()

        width: 28 * root.s
        height: 16 * root.s
        radius: 999
        color: on ? Theme.verm : Theme.tileBg
        border.width: on ? 0 : 1
        border.color: Theme.border

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10 * root.s
            height: 10 * root.s
            radius: width / 2
            color: Theme.cream
            x: toggle.on ? toggle.width - width - 3 * root.s : 3 * root.s
            Behavior on x { NumberAnimation { duration: Motion.fast } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    /**
     * Ember mark: a small flame-glow dot over a soft halo, the unread marker
     * shared by the header badge and unread notification titles.
     */
    component Ember: Item {
        id: ember
        property real size: 4 * root.s

        width: size * 2.2
        height: size * 2.2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: Theme.flameGlow
            opacity: 0.22
        }

        Rectangle {
            anchors.centerIn: parent
            width: ember.size
            height: ember.size
            radius: width / 2
            color: Theme.flameGlow
        }
    }

    Item {
        id: mainView
        anchors.fill: parent
        opacity: root.subview === "main" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "main" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Column {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4 * root.s

            Item {
                width: parent.width
                height: 24 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "繋"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 16 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LINK"
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
                    spacing: 6 * root.s
                    visible: Notifs.unread > 0

                    Ember {
                        id: headerEmber
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6 * root.s

                        SequentialAnimation on opacity {
                            running: headerEmber.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 1; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.unread + " NEU"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            Rectangle {
                id: netzRow
                width: parent.width
                height: 44 * root.s
                radius: 10 * root.s
                color: netzHover.hovered ? Theme.frameBg : "transparent"

                HoverHandler { id: netzHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "wifi"
                }

                GlyphIcon {
                    id: netzGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: root.wired ? "ethernet" : "wifi"
                    color: !root.wired && root.wifiOn ? Theme.vermLit : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: netzGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: netzRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: "Netz"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.netzSubText
                        color: !root.wired && root.wifiActive ? Theme.vermLit : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: !root.wired && root.wifiActive ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: netzRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.wired && root.wifiOn && root.wifiActive !== null
                        s: root.s
                        kind: "signal"
                        level: ((root.wifiActive && root.wifiActive.signalStrength) || 0) / 100
                    }

                    LinkToggle {
                        visible: !root.wired
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.wifiOn
                        onToggled: {
                            if (typeof Networking !== "undefined" && Networking)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                        }
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.iconDim
                        stroke: 1.8
                    }
                }
            }

            Rectangle {
                id: btRow
                width: parent.width
                height: 44 * root.s
                radius: 10 * root.s
                color: btHover.hovered ? Theme.frameBg : "transparent"

                HoverHandler { id: btHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "bt"
                }

                GlyphIcon {
                    id: btGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "bluetooth"
                    color: root.btConnected.length > 0 ? Theme.vermLit : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: btGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: btRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: "Bluetooth"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.btSubText
                        color: root.btPrimary ? Theme.vermLit : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: root.btPrimary ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: btRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.btPrimary !== null && root.btBattery >= 0
                        s: root.s
                        kind: "battery"
                        level: Math.max(0, root.btBattery) / 100
                    }

                    LinkToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.btOn
                        onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.iconDim
                        stroke: 1.8
                    }
                }
            }

            Item {
                width: parent.width
                height: 20 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s

                    Text {
                        id: inboxKanji
                        anchors.verticalCenter: parent.verticalCenter
                        text: "報"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INBOX"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.8 * root.s
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.count > 0
                    text: "払 CLEAR"
                    color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4 * root.s

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }
            }

            Item {
                visible: Notifs.count > 0
                width: parent.width
                height: notifFlick.height

                Flickable {
                    id: notifFlick
                    width: parent.width
                    height: Math.min(notifCol.implicitHeight, 280 * root.s)
                    contentHeight: notifCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: notifCol
                        width: notifFlick.width
                        spacing: 8 * root.s

                        Repeater {
                            model: Notifs.groups

                            Column {
                                id: group
                                required property var modelData
                                readonly property bool collapsed: Notifs.collapsedApps[modelData.app] === true
                                width: notifCol.width
                                spacing: 4 * root.s

                                Item {
                                    width: parent.width
                                    height: 14 * root.s

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6 * root.s

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: group.modelData.app
                                            color: Theme.dim
                                            font.family: Theme.font
                                            font.pixelSize: 8.5 * root.s
                                            font.weight: Font.Bold
                                            font.capitalization: Font.AllUppercase
                                            font.letterSpacing: 1.4 * root.s
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "· " + group.modelData.items.length
                                            color: Theme.faint
                                            font.family: Theme.font
                                            font.pixelSize: 8.5 * root.s
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: group.collapsed ? "▸" : "▾"
                                        color: Theme.faint
                                        font.pixelSize: 9 * root.s
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifs.toggleCollapsed(group.modelData.app)
                                    }
                                }

                                Column {
                                    visible: !group.collapsed
                                    width: parent.width
                                    spacing: 6 * root.s

                                    Repeater {
                                        model: group.modelData.items

                                        Row {
                                            id: notifRow
                                            required property var modelData
                                            readonly property bool live: modelData.live === true
                                            readonly property var n: modelData.n
                                            readonly property bool unseen: live && !Notifs.seenIds[modelData.n.id]
                                            readonly property var acts: live
                                                ? modelData.n.actions.filter(function(a) { return a.text.length > 0 })
                                                : []
                                            readonly property bool hovered: itemHover.hovered
                                            width: parent ? parent.width : 0
                                            spacing: 8 * root.s

                                            HoverHandler { id: itemHover }

                                            Rectangle {
                                                width: 28 * root.s
                                                height: 28 * root.s
                                                radius: 8 * root.s
                                                color: Theme.tileBg
                                                border.width: 1
                                                border.color: Theme.border

                                                Image {
                                                    id: tileImg
                                                    anchors.fill: parent
                                                    anchors.margins: notifRow.n.image ? 0 : 5 * root.s
                                                    source: notifRow.n.image
                                                        ? notifRow.n.image
                                                        : (notifRow.n.appIcon
                                                            ? Quickshell.iconPath(notifRow.n.appIcon, "")
                                                            : "")
                                                    sourceSize.width: 64
                                                    sourceSize.height: 64
                                                    fillMode: Image.PreserveAspectCrop
                                                    smooth: true
                                                    visible: source.toString().length > 0
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    visible: !tileImg.visible
                                                    width: 7 * root.s
                                                    height: 7 * root.s
                                                    radius: 2 * root.s
                                                    rotation: 45
                                                    color: notifRow.n.urgency === NotificationUrgency.Critical
                                                        ? Theme.vermLit : Theme.verm
                                                }
                                            }

                                            Column {
                                                width: parent.width - 36 * root.s
                                                spacing: 2 * root.s

                                                Item {
                                                    width: parent.width
                                                    height: titleText.implicitHeight

                                                    Ember {
                                                        id: titleEmber
                                                        visible: notifRow.unseen
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        size: 4 * root.s
                                                    }

                                                    Text {
                                                        id: titleText
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: notifRow.unseen ? titleEmber.width + 4 * root.s : 0
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - anchors.leftMargin - 30 * root.s
                                                        text: notifRow.n.summary
                                                        color: notifRow.unseen ? Theme.cream : Theme.subtle
                                                        font.family: Theme.font
                                                        font.pixelSize: 11.5 * root.s
                                                        font.weight: notifRow.unseen ? Font.DemiBold : Font.Medium
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: !notifRow.hovered
                                                        text: notifRow.live ? Notifs.ageLabel(notifRow.n) : ""
                                                        color: Theme.faint
                                                        font.family: Theme.font
                                                        font.pixelSize: 9 * root.s
                                                    }

                                                    Text {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: notifRow.hovered
                                                        text: "✕"
                                                        color: xArea.containsMouse ? Theme.cream : Theme.dim
                                                        font.pixelSize: 10.5 * root.s

                                                        MouseArea {
                                                            id: xArea
                                                            anchors.fill: parent
                                                            anchors.margins: -6 * root.s
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: notifRow.live
                                                                ? Notifs.dismissNotif(notifRow.n)
                                                                : Notifs.removeHistory(notifRow.n.id)
                                                        }
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    visible: notifRow.n.body.length > 0
                                                    text: notifRow.n.body
                                                    color: Theme.dim
                                                    font.family: Theme.font
                                                    font.pixelSize: 10.5 * root.s
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                    textFormat: Text.PlainText
                                                }

                                                Rectangle {
                                                    visible: notifRow.live && Notifs.progressOf(notifRow.n) >= 0
                                                    width: parent.width
                                                    height: 5 * root.s
                                                    radius: 999
                                                    color: Theme.threadBg

                                                    Rectangle {
                                                        width: parent.width * Math.max(0, Notifs.progressOf(notifRow.n)) / 100
                                                        height: parent.height
                                                        radius: 999
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: Theme.verm }
                                                            GradientStop { position: 1.0; color: Theme.vermLit }
                                                        }
                                                    }
                                                }

                                                Row {
                                                    visible: notifRow.acts.length > 0
                                                    spacing: 6 * root.s
                                                    topPadding: 4 * root.s

                                                    Repeater {
                                                        model: notifRow.acts

                                                        Rectangle {
                                                            id: actPill
                                                            required property var modelData
                                                            required property int index
                                                            radius: 999
                                                            color: Theme.tileBg
                                                            border.width: 1
                                                            border.color: Theme.border
                                                            height: 20 * root.s
                                                            width: actText.implicitWidth + 18 * root.s

                                                            Text {
                                                                id: actText
                                                                anchors.centerIn: parent
                                                                text: actPill.modelData.text
                                                                color: actPill.index === 0 ? Theme.vermLit : Theme.dim
                                                                font.family: Theme.font
                                                                font.pixelSize: 9.5 * root.s
                                                                font.weight: Font.DemiBold
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: actPill.modelData.invoke()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(event) {
                        var max = Math.max(0, notifFlick.contentHeight - notifFlick.height);
                        notifFlick.contentY = Math.max(0, Math.min(max, notifFlick.contentY - event.angleDelta.y / 120 * 36 * root.s));
                        event.accepted = true;
                    }
                }
            }

            Column {
                visible: Notifs.count === 0
                width: parent.width
                topPadding: 14 * root.s
                bottomPadding: 14 * root.s
                spacing: 4 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "静"
                    color: Theme.ghost
                    opacity: 0.55
                    font.family: Theme.font
                    font.pixelSize: 32 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "STILLE"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 2.2 * root.s
                }
            }
        }
    }

    LinkWifi {
        id: wifiPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "wifi"
        opacity: root.subview === "wifi" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "wifi" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onBack: root.subview = "main"
    }

    LinkBt {
        id: btPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "bt"
        opacity: root.subview === "bt" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "bt" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onBack: root.subview = "main"
    }
}
