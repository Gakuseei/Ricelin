pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Networking
import "Singletons"

/**
 * WLAN drill-in for the link surface: back chevron, wifi enable toggle and the
 * live network list sorted by signal strength. Security and known-profile
 * ground truth come from nmcli; clicking a secured unknown network expands an
 * inline password row that connects through `nmcli dev wifi connect`. The pill
 * body provides the surface material, so this item draws no background.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var nets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var netsSorted: nets.slice().sort(function(a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
    })

    property var securityMap: ({})
    property var knownProfiles: ({})
    property string expandedSsid: ""
    property bool connecting: false
    property bool connectFailed: false

    implicitHeight: listFrame.y + listFrame.height

    function isSecured(ssid) {
        var sec = securityMap[ssid];
        return sec !== undefined && sec !== "" && sec !== "--";
    }

    function refresh() {
        secProc.running = true;
        profProc.running = true;
    }

    /**
     * Splits one `nmcli -t` line at its last unescaped colon and unescapes the
     * leading field. Returns null for lines without a field separator.
     */
    function splitTerse(line) {
        for (var k = line.length - 1; k >= 0; k--) {
            if (line[k] === ":" && (k === 0 || line[k - 1] !== "\\"))
                return { head: line.slice(0, k).replace(/\\:/g, ":"), tail: line.slice(k + 1) };
        }
        return null;
    }

    /**
     * Click dispatch for a network row: disconnect when connected, connect
     * known or open networks directly, otherwise expand the inline password
     * row under that network.
     */
    function activateNetwork(net) {
        if (!net)
            return;
        var ssid = net.name || "";
        if (net.connected) {
            if (typeof net.disconnect === "function")
                net.disconnect();
            return;
        }
        if (knownProfiles[ssid] === true || !isSecured(ssid)) {
            expandedSsid = "";
            if (typeof net.connect === "function")
                net.connect();
            refresh();
            return;
        }
        connectFailed = false;
        expandedSsid = ssid;
    }

    function connectWithPassword(ssid, pw) {
        if (connProc.running || !pw.length)
            return;
        connecting = true;
        connectFailed = false;
        connProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", pw];
        connProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            refresh();
        } else {
            expandedSsid = "";
            connectFailed = false;
        }
    }

    Process {
        id: secProc
        command: ["nmcli", "-t", "-f", "SSID,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].length)
                        continue;
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length)
                        map[parts.head] = parts.tail;
                }
                root.securityMap = map;
            }
        }
    }

    Process {
        id: profProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var name = lines[i].replace(/\\:/g, ":").trim();
                    if (name.length)
                        set[name] = true;
                }
                root.knownProfiles = set;
            }
        }
    }

    Process {
        id: connProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.connecting = false;
            if (exitCode === 0) {
                root.expandedSsid = "";
                root.connectFailed = false;
                root.refresh();
            } else {
                root.connectFailed = true;
            }
        }
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

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 17 * root.s
                height: 17 * root.s

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: backArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "WLAN"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        LinkToggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.wifiOn
            onToggled: {
                if (typeof Networking !== "undefined" && Networking)
                    Networking.wifiEnabled = !Networking.wifiEnabled;
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

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.wifiOn ? Math.min(netCol.implicitHeight, 200 * root.s) : 0

        Flickable {
            id: netFlick
            anchors.fill: parent
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netCol
                width: netFlick.width
                spacing: 2 * root.s

                Repeater {
                    model: root.netsSorted

                    Column {
                        id: netItem
                        required property var modelData
                        readonly property string ssid: (modelData && modelData.name) ? modelData.name : ""
                        readonly property bool isActive: modelData ? modelData.connected === true : false
                        readonly property bool secured: root.isSecured(ssid)
                        readonly property bool expanded: ssid.length > 0 && root.expandedSsid === ssid
                        width: netCol.width
                        spacing: 2 * root.s

                        onExpandedChanged: {
                            if (expanded) {
                                pwField.text = "";
                                Qt.callLater(pwField.forceActiveFocus);
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 30 * root.s
                            radius: 9 * root.s
                            color: netItem.isActive ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, 0.14)
                                : (rowHover.hovered ? Theme.frameBg : "transparent")

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateNetwork(netItem.modelData)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: rowRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.ssid.length ? netItem.ssid : "Hidden"
                                color: netItem.isActive ? Theme.vermLit : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: netItem.isActive ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rowRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: netItem.secured
                                    width: 8 * root.s
                                    height: 8 * root.s
                                    name: "lock"
                                    color: Theme.faint
                                    stroke: 2.2
                                }

                                Filament {
                                    anchors.verticalCenter: parent.verticalCenter
                                    s: root.s
                                    kind: "signal"
                                    level: ((netItem.modelData && netItem.modelData.signalStrength) || 0) / 100
                                }
                            }
                        }

                        Item {
                            visible: netItem.expanded
                            width: parent.width
                            height: 30 * root.s

                            TextField {
                                id: pwField
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: pwRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                background: null
                                padding: 0
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                echoMode: TextInput.Password
                                placeholderText: "Passwort"
                                placeholderTextColor: Theme.faint
                                selectByMouse: true
                                selectionColor: Theme.verm
                                onAccepted: root.connectWithPassword(netItem.ssid, text)
                            }

                            Row {
                                id: pwRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.connecting && netItem.expanded
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: root.connecting && netItem.expanded
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: 420; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: 420; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "↵"
                                    color: enterArea.containsMouse ? Theme.cream : Theme.vermLit
                                    font.family: Theme.font
                                    font.pixelSize: 12 * root.s

                                    MouseArea {
                                        id: enterArea
                                        anchors.fill: parent
                                        anchors.margins: -6 * root.s
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectWithPassword(netItem.ssid, pwField.text)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: netItem.expanded && root.connectFailed
                            text: "Verbindung fehlgeschlagen"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 10 * root.s
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(event) {
                var max = Math.max(0, netFlick.contentHeight - netFlick.height);
                netFlick.contentY = Math.max(0, Math.min(max, netFlick.contentY - event.angleDelta.y / 120 * 36 * root.s));
                event.accepted = true;
            }
        }
    }
}
