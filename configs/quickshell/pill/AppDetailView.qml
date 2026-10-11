pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Per-app RUN / ACTIONS / TELEMETRY readout — the surface the user lands on
 * after tapping a tile. GPU load, temperature and VRAM come straight from the
 * existing Sysmon singleton (the host surface flips `Sysmon.open` on while
 * this view is showing, same contract SysmonSurface itself uses) rather than
 * a second nvidia-smi poller; FPS / 1% low stay "—" until something tails a
 * MangoHud log, which is a deliberate scope cut, not an oversight — see the
 * module README for the extension point.
 */
Item {
    id: root

    required property var app
    property real s: 1
    property bool running: false
    property int pid: 0
    property real startedAt: 0

    signal back()
    signal launch()
    signal stop()
    signal forceStop()
    signal restart()
    signal toggleFullscreen()
    signal editRequested()

    implicitHeight: col.implicitHeight

    readonly property var runtimeLine: {
        if (root.app.runner === "umu")
            return (root.app.protonBuild || "Proton") + " · VKD3D-Proton";
        if (root.app.runner === "wine-staging")
            return "Wine-Staging · DXVK";
        if (root.app.runner === "wine")
            return "Wine · DXVK";
        return "Native";
    }

    readonly property string elapsedLabel: {
        void elapsedTicker.tickCount;
        if (!root.running || root.startedAt <= 0)
            return "";
        var secs = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000));
        var h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60), s2 = secs % 60;
        return (h > 0 ? h + "h " : "") + m + "m " + s2 + "s";
    }

    Timer { id: elapsedTicker; property int tickCount: 0; interval: 1000; running: root.running; repeat: true; onTriggered: tickCount = tickCount + 1 }

    component SectionLabel: Item {
        id: sec
        property string text: ""
        width: parent ? parent.width : 0
        height: lbl.implicitHeight + 9 * root.s

        Text {
            id: lbl
            text: sec.text
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
        }
    }

    component FactRow: Item {
        id: fr
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: 22 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: fr.label
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.Medium
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: fr.value
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    component ActionButton: Rectangle {
        id: btn
        property string label: ""
        property bool primary: false
        property bool danger: false
        property bool enabled_: true
        signal clicked()

        implicitHeight: 34 * root.s
        radius: 9 * root.s
        opacity: enabled_ ? 1 : 0.4
        color: primary ? Theme.vermDeep : (area.containsMouse ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: primary ? "transparent" : (danger ? Qt.alpha(Theme.verm, 0.5) : Theme.frameBorder)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        scale: area.pressed ? 0.97 : 1
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? Theme.bright : (btn.danger ? Theme.vermLit : Theme.cream)
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.Bold
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: btn.enabled_
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "chevron-left"
                    color: backArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 2.2
                    MouseArea { id: backArea; anchors.fill: parent; anchors.margins: -6 * root.s; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.app.name
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: "cog"
                color: editArea.containsMouse ? Theme.cream : Theme.iconDim
                stroke: 1.7
                MouseArea { id: editArea; anchors.fill: parent; anchors.margins: -6 * root.s; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editRequested() }
            }
        }

        Item { width: 1; height: 12 * root.s }

        SectionLabel { text: root.running ? "Run · " + root.elapsedLabel : "Run" }
        Item { width: 1; height: 8 * root.s }
        FactRow { label: "Runtime"; value: root.runtimeLine }
        FactRow { label: "Prefix"; value: root.app.prefix.length > 0 ? "…/" + root.app.prefix.split("/").slice(-1)[0] : "—" }
        FactRow { label: "Window"; value: (root.app.window.mode === "fullscreen" ? "Fullscreen" : root.app.window.mode === "borderless" ? "Borderless" : "Windowed") + " · " + (root.app.window.resolution || "Native") }
        FactRow { visible: root.running; height: visible ? 22 * root.s : 0; label: "PID"; value: root.pid > 0 ? String(root.pid) : "—" }

        Item { width: 1; height: 16 * root.s }

        SectionLabel { text: "Actions" }
        Item { width: 1; height: 10 * root.s }

        Row {
            width: parent.width
            spacing: 8 * root.s
            ActionButton {
                width: (parent.width - 8 * root.s) / 2
                primary: !root.running
                label: root.running ? "Stop" : "Launch"
                onClicked: root.running ? root.stop() : root.launch()
            }
            ActionButton {
                width: (parent.width - 8 * root.s) / 2
                enabled_: root.running
                label: "Restart"
                onClicked: root.restart()
            }
        }
        Item { width: 1; height: 8 * root.s }
        Row {
            width: parent.width
            spacing: 8 * root.s
            ActionButton {
                width: (parent.width - 8 * root.s) / 2
                label: root.app.window.mode === "fullscreen" ? "Windowed" : "Fullscreen"
                onClicked: root.toggleFullscreen()
            }
            ActionButton {
                width: (parent.width - 8 * root.s) / 2
                enabled_: root.running
                danger: true
                label: "Force Stop"
                onClicked: root.forceStop()
            }
        }

        Item { width: 1; height: 16 * root.s }

        SectionLabel { text: "Telemetry" }
        Item { width: 1; height: 8 * root.s }
        FactRow { label: "GPU"; value: Sysmon.hasGpu ? Sysmon.gpu + "%" + (Sysmon.gpuTemp >= 0 ? "  ·  " + Sysmon.gpuTemp + "°" : "") : "—" }
        FactRow { label: "VRAM"; value: Sysmon.hasVram ? Sysmon.vramUsedGb.toFixed(1) + " / " + Sysmon.vramTotalGb.toFixed(0) + " GB" : "—" }
        FactRow { label: "FPS"; value: "—" }
        FactRow { label: "1% Low"; value: "—" }

        Item { width: 1; height: 6 * root.s }
    }
}
