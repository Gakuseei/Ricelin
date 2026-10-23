pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 波 WIFI surface: the network list by signal strength with inline connect, password and forget rows, plus the hotspot.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    readonly property var wifiDev: Net.wifiDev
    readonly property bool wifiOn: Net.wifiOn
    readonly property var nets: Net.wifiNets
    readonly property var activeNet: Net.wifiActive
    readonly property var netsSorted: nets.slice().sort(function(a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
    })
    readonly property string statusText: !wifiOn ? "Off"
        : (activeNet ? (activeNet.name || "Connected") : "Not connected")

    property var securityMap: ({})
    property var knownProfiles: ({})
    property string expandedSsid: ""
    property string kbSsid: ""
    property bool connecting: false
    property bool connectFailed: false
    property string connFailReason: ""
    property bool scanning: false

    /** Detail line under the connected row: IPv4 address plus band and bitrate from nmcli. */
    property string connIp: ""
    property string connBandRate: ""
    readonly property string connDetail: {
        var p = [];
        if (connIp.length) p.push(connIp);
        if (connBandRate.length) p.push(connBandRate);
        return p.join(" · ");
    }

    /** Saved password shown for one SSID; `revealResolved` tells "not read yet" from "read but empty". */
    property string revealedSsid: ""
    property string revealedPw: ""
    property bool revealResolved: false

    readonly property string hsCon: "RicelinHotspot"
    readonly property string hsIface: wifiDev ? (wifiDev.name || "wlan0") : "wlan0"
    property string hsName: "Ricelin"
    property string hsPw: ""
    property bool hsActive: false
    property bool hsBusy: false
    property string hsEdit: ""
    property string hsDraft: ""

    /** Password draft on the root, so a rescan that swaps the delegate's network object keeps what was typed. */
    property string pwDraft: ""
    property string pendingPw: ""
    property string attemptSsid: ""
    property bool attemptWasKnown: false

    implicitHeight: hsBlock.y + hsBlock.height
    holdsFocus: expandedSsid.length > 0 || hsEdit.length > 0

    function isSecured(ssid) {
        var sec = securityMap[ssid];
        return sec !== undefined && sec !== "" && sec !== "--";
    }

    function refresh() {
        secProc.running = true;
        profProc.running = true;
        if (root.wifiDev)
            detailProc.running = true;
    }

    /** Splits one `nmcli -t` line at its last unescaped colon and unescapes the leading field. */
    function splitTerse(line) {
        for (var k = line.length - 1; k >= 0; k--) {
            if (line[k] === ":" && (k === 0 || line[k - 1] !== "\\"))
                return { head: line.slice(0, k).replace(/\\:/g, ":"), tail: line.slice(k + 1) };
        }
        return null;
    }

    /** Saved or connected opens the confirm row, open connects at once, secured asks for a password; a second click closes. */
    function activateNetwork(net) {
        if (!net)
            return;
        var ssid = net.name || "";
        kbSsid = ssid;
        if (expandedSsid === ssid && ssid.length) {
            expandedSsid = "";
            return;
        }
        if (net.connected || knownProfiles[ssid] === true) {
            connectFailed = false;
            pwDraft = "";
            expandedSsid = ssid;
            return;
        }
        if (!isSecured(ssid)) {
            expandedSsid = "";
            if (typeof net.connect === "function")
                net.connect();
            refresh();
            return;
        }
        connectFailed = false;
        pwDraft = "";
        expandedSsid = ssid;
    }

    function connectKnown(net) {
        if (!net)
            return;
        expandedSsid = "";
        connecting = true;
        connectFailed = false;
        attemptSsid = net.name || "";
        connSpinTimer.restart();
        if (typeof net.connect === "function")
            net.connect();
        refresh();
    }

    function disconnectNetwork(net) {
        if (!net)
            return;
        expandedSsid = "";
        if (typeof net.disconnect === "function")
            net.disconnect();
        refresh();
    }

    /** The SSID goes in as its own argv element, so no character in it can break or inject the command. */
    function forgetNetwork(ssid) {
        if (forgetProc.running || !ssid.length)
            return;
        expandedSsid = "";
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }

    /** NetworkManager lets the owner read a saved secret unprivileged; a second click on the same row hides it. */
    function revealPassword(ssid) {
        if (!ssid.length)
            return;
        if (revealedSsid === ssid) {
            hidePassword();
            return;
        }
        revealedSsid = ssid;
        revealedPw = "";
        revealResolved = false;
        revealProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "id", ssid];
        revealProc.rerun();
    }

    function hidePassword() {
        revealedSsid = "";
        revealedPw = "";
        revealResolved = false;
    }

    /** The password goes in through stdin, since the command line is world-readable while nmcli runs. */
    function connectWithPassword(ssid, pw) {
        if (connProc.running || !pw.length)
            return;
        connecting = true;
        connectFailed = false;
        connFailReason = "";
        attemptSsid = ssid;
        attemptWasKnown = knownProfiles[ssid] === true;
        pendingPw = pw;
        connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }

    /** Forces a fresh nmcli rescan for up to 10 s; the device scanner keeps running anyway while the surface is open. */
    function startScan() {
        if (!wifiOn)
            return;
        scanning = true;
        rescanProc.running = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanning = false;
        scanTimer.stop();
    }

    function back() {
        if (hsEdit.length) {
            hsEdit = "";
            return true;
        }
        if (expandedSsid.length) {
            expandedSsid = "";
            return true;
        }
        return false;
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            var list = netsSorted;
            if (!list.length)
                return false;
            var down = e.key === Qt.Key_Down;
            var i = -1;
            for (var k = 0; k < list.length; k++)
                if (list[k] && (list[k].name || "") === kbSsid)
                    i = k;
            i = i < 0 ? (down ? 0 : list.length - 1) : Math.max(0, Math.min(list.length - 1, i + (down ? 1 : -1)));
            kbSsid = list[i] ? (list[i].name || "") : "";
            reveal(i);
            return true;
        }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (e.isAutoRepeat)
                return true;
            var net = netsSorted.find(function(n) { return n && (n.name || "") === root.kbSsid; });
            if (!net)
                return false;
            activateNetwork(net);
            return true;
        }
        return false;
    }

    function reveal(index) {
        var it = netRep.itemAt(index);
        if (!it)
            return;
        if (it.y < netFlick.contentY)
            netFlick.contentY = it.y;
        else if (it.y + it.height > netFlick.contentY + netFlick.height)
            netFlick.contentY = it.y + it.height - netFlick.height;
    }

    onActiveChanged: {
        if (active) {
            refresh();
            refreshHotspot();
            startScan();
        } else {
            stopScan();
            expandedSsid = "";
            kbSsid = "";
            connecting = false;
            connSpinTimer.stop();
            connectFailed = false;
            hsEdit = "";
            hidePassword();
        }
    }

    onWifiOnChanged: if (!wifiOn) stopScan()

    onExpandedSsidChanged: if (revealedSsid !== expandedSsid) hidePassword()

    /** The known-profile spinner ends when the attempted network connects; the detail line follows every change. */
    onActiveNetChanged: {
        if (root.activeNet && root.attemptSsid.length && (root.activeNet.name || "") === root.attemptSsid) {
            root.connecting = false;
            connSpinTimer.stop();
        }
        if (root.active && root.wifiDev)
            detailProc.running = true;
    }

    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.active && root.wifiOn
        when: root.wifiDev !== null
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: root.stopScan()
    }

    /** Safety net for the known-profile spinner when a connect silently never lands. */
    Timer {
        id: connSpinTimer
        interval: 10000
        onTriggered: root.connecting = false
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
    }

    /** Creates the hotspot profile on first use, updates it after, then brings it up; values go in as argv, never spliced. */
    function applyHotspot() {
        if (hsBusy || hsPw.length < 8)
            return;
        hsBusy = true;
        hsApplyProc.command = ["sh", "-c",
            'c="' + hsCon + '"; '
            + 'if nmcli -t connection show "$c" >/dev/null 2>&1; then '
            +   'nmcli connection modify "$c" 802-11-wireless.ssid "$1" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2"; '
            + 'else '
            +   'nmcli connection add type wifi ifname "$3" con-name "$c" autoconnect no 802-11-wireless.ssid "$1" 802-11-wireless.mode ap 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2" ipv4.method shared; '
            + 'fi; '
            + 'nmcli connection up "$c"',
            "sh", hsName, hsPw, hsIface];
        hsApplyProc.running = true;
    }

    function stopHotspot() {
        if (hsBusy)
            return;
        hsBusy = true;
        hsDownProc.running = true;
    }

    function refreshHotspot() {
        hsStateProc.running = true;
        hsReadProc.running = true;
    }

    /** A password under the WPA2 minimum of 8 is ignored; the profile is saved either way and a live hotspot re-applies. */
    function commitHotspotEdit() {
        if (hsEdit === "name") {
            if (hsDraft.length)
                hsName = hsDraft;
        } else if (hsEdit === "pw") {
            if (hsDraft.length >= 8)
                hsPw = hsDraft;
        }
        hsEdit = "";
        if (hsActive)
            applyHotspot();
        else
            saveHotspot();
    }

    /** Writes name and password into the profile without bringing it up, generating a password when none is set. */
    function saveHotspot() {
        if (hsPw.length < 8)
            hsPw = generatePw();
        hsSaveProc.command = ["sh", "-c",
            'c="' + hsCon + '"; '
            + 'if nmcli -t connection show "$c" >/dev/null 2>&1; then '
            +   'nmcli connection modify "$c" 802-11-wireless.ssid "$1" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2"; '
            + 'else '
            +   'nmcli connection add type wifi ifname "$3" con-name "$c" autoconnect no 802-11-wireless.ssid "$1" 802-11-wireless.mode ap 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2" ipv4.method shared; '
            + 'fi',
            "sh", hsName, hsPw, hsIface];
        hsSaveProc.running = true;
    }

    /** Eight characters from an alphabet without look-alikes. */
    function generatePw() {
        var cs = "abcdefghijkmnpqrstuvwxyz23456789";
        var s = "";
        for (var i = 0; i < 8; i++)
            s += cs.charAt(Math.floor(Math.random() * cs.length));
        return s;
    }

    Process {
        id: hsApplyProc
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsSaveProc
        onExited: root.refreshHotspot()
    }

    Process {
        id: hsDownProc
        command: ["nmcli", "connection", "down", root.hsCon]
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsStateProc
        command: ["sh", "-c", "nmcli -t -f NAME connection show --active | grep -qx \"$1\" && echo on || echo off", "sh", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: root.hsActive = this.text.trim() === "on"
        }
    }

    Process {
        id: hsReadProc
        command: ["nmcli", "-t", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.psk", "connection", "show", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                if (lines.length >= 1 && lines[0].length)
                    root.hsName = lines[0];
                if (lines.length >= 2 && lines[1].length)
                    root.hsPw = lines[1];
            }
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
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length && parts.tail === "802-11-wireless")
                        set[parts.head] = true;
                }
                root.knownProfiles = set;
            }
        }
    }

    /** Band and bitrate of the active row plus the interface IPv4, marker-prefixed so a missing half can't shift the parse. */
    Process {
        id: detailProc
        command: ["sh", "-c",
            "nmcli -t -f ACTIVE,BAND,RATE dev wifi list | awk -F: '$1==\"yes\"{print \"BR \" $2 \" \" $3}'; "
            + "ip -4 -o addr show dev \"$1\" scope global | awk '{split($4,a,\"/\"); print \"IP \" a[1]; exit}'",
            "sh", root.hsIface]
        stdout: StdioCollector {
            onStreamFinished: {
                var br = "";
                var ip = "";
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("BR ") === 0)
                        br = lines[i].slice(3).trim();
                    else if (lines[i].indexOf("IP ") === 0)
                        ip = lines[i].slice(3).trim();
                }
                root.connBandRate = br;
                root.connIp = ip;
            }
        }
    }

    Process {
        id: connProc
        stdinEnabled: true
        stdout: StdioCollector {}
        stderr: StdioCollector { id: connErr }
        onStarted: {
            write(root.pendingPw + "\n");
            root.pendingPw = "";
        }
        onExited: function(exitCode) {
            root.connecting = false;
            if (exitCode === 0) {
                root.expandedSsid = "";
                root.pwDraft = "";
                root.connectFailed = false;
                root.connFailReason = "";
                root.refresh();
            } else {
                root.connectFailed = true;
                var err = connErr.text.split("\n").filter(function(l) { return l.trim().length > 0; });
                var last = err.length ? err[err.length - 1].trim() : "";
                root.connFailReason = last.replace(/^Error:\s*/, "").replace(/\.$/, "");
                if (!root.attemptWasKnown && root.attemptSsid.length) {
                    cleanupProc.command = ["nmcli", "connection", "delete", "id", root.attemptSsid];
                    cleanupProc.running = true;
                }
            }
        }
    }

    /** A failed connect leaves a profile behind that would make the network look saved and fail forever. */
    Process {
        id: cleanupProc
        onExited: root.refresh()
    }

    Process {
        id: forgetProc
        onExited: root.refresh()
    }

    /** Reads one saved PSK on demand; empty means the profile is open or keeps no recoverable secret. */
    LatestProcess {
        id: revealProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.revealedPw = this.text.replace(/\n+$/, "");
                root.revealResolved = true;
            }
        }
    }

    onNetsChanged: if (active) secRefresh.restart()

    Timer {
        id: secRefresh
        interval: 1200
        onTriggered: if (root.active) secProc.running = true
    }

    /** Keyed by SSID so a rescan diffs into the existing rows and an open confirm or password row stays put. */
    ScriptModel {
        id: netModel
        objectProp: "name"
        values: root.netsSorted
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

    component Caps: Text {
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.fs.label * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Theme.labelTracking * root.s
    }

    SurfaceHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s
        s: root.s
        glyph: "波"
        title: "Wi-Fi"
        titleContent: Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 96 * root.s)
            text: root.statusText
            color: root.activeNet ? Theme.vermLit : Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp.s * root.s

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.wifiOn
                s: root.s
                kind: "ghost"
                text: root.scanning ? "Scanning…" : "Scan"
                lit: root.scanning
                onClicked: root.scanning ? root.stopScan() : root.startScan()
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.wifiOn
                onToggled: Net.toggleWifi()
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

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: Theme.sp.xs * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: !root.wifiOn ? offState.implicitHeight
            : (root.nets.length === 0 ? searchState.implicitHeight : Math.min(netCol.implicitHeight, 280 * root.s))

        EmptyState {
            id: offState
            visible: !root.wifiOn
            anchors.horizontalCenter: parent.horizontalCenter
            s: root.s
            glyph: "wifi"
            text: "Wi-Fi is off"
            action: "Turn on"
            onTriggered: Net.toggleWifi()
        }

        EmptyState {
            id: searchState
            visible: root.wifiOn && root.nets.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            s: root.s
            glyph: "wifi"
            text: "Looking for networks…"
        }

        Flickable {
            id: netFlick
            visible: root.wifiOn
            anchors.fill: parent
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netCol
                width: netFlick.width
                spacing: Theme.sp.xxs * root.s
                move: Transition {
                    enabled: !Motion.calm
                    NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: netRep
                    model: netModel

                    Column {
                        id: netItem
                        required property var modelData
                        readonly property string ssid: (modelData && modelData.name) ? modelData.name : ""
                        readonly property bool isActive: modelData ? modelData.connected === true : false
                        readonly property bool secured: root.isSecured(ssid)
                        readonly property bool known: root.knownProfiles[ssid] === true
                        readonly property bool expanded: ssid.length > 0 && root.expandedSsid === ssid
                        readonly property bool confirming: expanded && (isActive || known)
                        readonly property bool asking: expanded && !confirming
                        readonly property bool lit: ssid.length > 0 && root.kbSsid === ssid
                        width: netCol.width
                        spacing: Theme.sp.xxs * root.s

                        function syncPwField() {
                            pwField.text = root.pwDraft;
                            pwField.cursorPosition = pwField.text.length;
                            pwField.forceActiveFocus();
                        }

                        onExpandedChanged: if (asking) Qt.callLater(syncPwField)
                        Component.onCompleted: if (asking) Qt.callLater(syncPwField)

                        Rectangle {
                            width: parent.width
                            height: 32 * root.s
                            radius: Theme.r.m * root.s
                            color: rowPress.pressed ? Theme.pressBg
                                : netItem.isActive ? Qt.alpha(Theme.verm, netItem.lit ? 0.2 : 0.14)
                                : (netItem.lit ? Theme.frameBg : "transparent")
                            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            HoverHandler {
                                onHoveredChanged: if (hovered && netItem.ssid.length) root.kbSsid = netItem.ssid
                            }

                            MouseArea {
                                id: rowPress
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateNetwork(netItem.modelData)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp.s * root.s
                                anchors.right: rowRight.left
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.ssid.length ? netItem.ssid : "Hidden network"
                                color: netItem.isActive ? Theme.vermLit : (netItem.lit ? Theme.cream : Theme.subtle)
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                font.weight: netItem.isActive ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rowRight
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp.s * root.s

                                Pulse {
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: root.connecting && root.attemptSsid === netItem.ssid
                                }

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1.4 * root.s
                                    visible: netItem.secured
                                    width: 14 * root.s
                                    height: 14 * root.s

                                    GlyphIcon {
                                        anchors.fill: parent
                                        name: "lock-outline"
                                        color: netItem.isActive ? Theme.vermLit : Theme.iconDim
                                        stroke: 1.9
                                    }
                                }

                                WifiGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    s: root.s
                                    on: true
                                    level: (netItem.modelData && netItem.modelData.signalStrength) || 0
                                }
                            }
                        }

                        Text {
                            visible: netItem.isActive && root.connDetail.length > 0
                            width: parent.width
                            text: root.connDetail
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            leftPadding: Theme.sp.s * root.s
                            bottomPadding: Theme.sp.xxs * root.s
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        ConfirmRow {
                            visible: netItem.confirming
                            s: root.s
                            inset: Theme.sp.s

                            Button {
                                s: root.s
                                kind: netItem.isActive ? "secondary" : "primary"
                                text: netItem.isActive ? "Disconnect" : "Connect"
                                onClicked: netItem.isActive
                                    ? root.disconnectNetwork(netItem.modelData)
                                    : root.connectKnown(netItem.modelData)
                            }

                            Button {
                                id: revealBtn
                                visible: netItem.known
                                readonly property bool shown: root.revealedSsid === netItem.ssid
                                s: root.s
                                kind: "ghost"
                                text: revealBtn.shown ? "Hide" : "Show"
                                lit: revealBtn.shown
                                onClicked: root.revealPassword(netItem.ssid)
                            }

                            Button {
                                s: root.s
                                kind: "danger"
                                text: "Forget"
                                onClicked: root.forgetNetwork(netItem.ssid)
                            }
                        }

                        Item {
                            readonly property bool shown: netItem.confirming && root.revealedSsid === netItem.ssid
                            visible: shown
                            width: parent.width
                            height: shown ? 24 * root.s : 0

                            Caps {
                                id: revealCaption
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                            }

                            Text {
                                visible: root.revealResolved && root.revealedPw.length === 0
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: "No saved password"
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.meta * root.s
                            }

                            TextEdit {
                                visible: root.revealedPw.length > 0
                                anchors.left: revealCaption.right
                                anchors.leftMargin: Theme.sp.s * root.s
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: TextEdit.AlignRight
                                readOnly: true
                                selectByMouse: true
                                selectionColor: Theme.verm
                                wrapMode: TextEdit.NoWrap
                                clip: true
                                text: root.revealedSsid === netItem.ssid ? root.revealedPw : ""
                                color: Theme.flameCore
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                font.weight: Font.Medium
                            }
                        }

                        Item {
                            visible: netItem.asking
                            width: parent.width
                            height: 32 * root.s

                            QQC.TextField {
                                id: pwField
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp.s * root.s
                                anchors.right: pwRight.left
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                background: null
                                padding: 0
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                echoMode: TextInput.Password
                                placeholderText: "Password"
                                placeholderTextColor: Theme.textFaint
                                selectByMouse: true
                                selectionColor: Theme.verm
                                onTextEdited: root.pwDraft = text
                                onAccepted: root.connectWithPassword(netItem.ssid, text)
                            }

                            Row {
                                id: pwRight
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp.s * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp.s * root.s

                                Pulse {
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: root.connecting && netItem.asking
                                }

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14 * root.s
                                    height: 14 * root.s
                                    name: "return"
                                    color: enterArea.pressed ? Theme.flameGlow : (enterArea.containsMouse ? Theme.cream : Theme.vermLit)
                                    stroke: 1.8

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
                            visible: netItem.asking && root.connectFailed
                            width: parent.width
                            text: "Couldn't connect" + (root.connFailReason.length ? ": " + root.connFailReason : "")
                            color: Theme.danger
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            leftPadding: Theme.sp.s * root.s
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: netFlick
        }
    }

    Item {
        id: hsBlock
        anchors.top: listFrame.bottom
        anchors.topMargin: Theme.sp.s * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.wifiOn
        height: root.wifiOn ? hsCol.implicitHeight + Theme.sp.s * root.s : 0
        clip: true

        Rectangle {
            id: hsDivider
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        Column {
            id: hsCol
            anchors.top: hsDivider.bottom
            anchors.topMargin: Theme.sp.s * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.sp.xs * root.s

            component CredRow: Item {
                id: cr
                property string field: ""
                property string label: ""
                property string value: ""
                property bool secret: false
                readonly property bool editing: root.hsEdit === cr.field
                width: parent ? parent.width : 0
                height: 24 * root.s

                Caps {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.label
                }

                Text {
                    visible: !cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.value.length ? cr.value : "Click to set"
                    color: crArea.containsMouse ? Theme.bright : (cr.value.length ? (cr.secret ? Theme.flameCore : Theme.cream) : Theme.textFaint)
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }

                    MouseArea {
                        id: crArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.hsDraft = cr.value;
                            root.hsEdit = cr.field;
                            Qt.callLater(crField.forceActiveFocus);
                        }
                    }
                }

                QQC.TextField {
                    id: crField
                    visible: cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * root.s
                    horizontalAlignment: TextInput.AlignRight
                    background: null
                    padding: 0
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    placeholderText: cr.field === "pw" ? "8+ characters" : "Name"
                    placeholderTextColor: Theme.textFaint
                    selectByMouse: true
                    selectionColor: Theme.verm
                    text: cr.editing ? root.hsDraft : ""
                    onTextEdited: root.hsDraft = text
                    onAccepted: root.commitHotspotEdit()
                }
            }

            Rectangle {
                width: parent.width
                height: 36 * root.s
                radius: Theme.r.m * root.s
                color: root.hsActive ? Theme.frameBg : "transparent"

                GlyphIcon {
                    id: hsGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "hotspot"
                    color: root.hsActive ? Theme.flameGlow : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: hsGlyph.right
                    anchors.leftMargin: Theme.sp.m * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        text: "Hotspot"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.hsBusy ? (root.hsActive ? "Stopping…" : "Starting…") : (root.hsActive ? "Sharing this connection" : "Off")
                        color: root.hsActive ? Theme.flameGlow : Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                    }
                }

                LinkToggle {
                    s: root.s
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.hsActive
                    onToggled: {
                        if (root.hsActive) {
                            root.stopHotspot();
                        } else {
                            if (root.hsPw.length < 8)
                                root.hsPw = root.generatePw();
                            root.applyHotspot();
                        }
                    }
                }
            }

            CredRow {
                field: "name"
                label: "Network"
                value: root.hsName
            }

            CredRow {
                field: "pw"
                label: "Password"
                value: root.hsPw
                secret: true
            }
        }
    }
}
