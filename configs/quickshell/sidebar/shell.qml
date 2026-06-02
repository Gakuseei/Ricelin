import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    property bool shown: false
    property string targetMonitor: ""

    IpcHandler {
        target: "sidebar"
        function show(mon: string): void {
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
        function hide(): void { root.shown = false; }
        function toggle(mon: string): void {
            if (root.shown) { root.shown = false; return; }
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: modelData ? modelData.height / 1080 : 1

            screen: modelData
            visible: root.shown && (root.targetMonitor === "" || root.targetMonitor === modelData.name)
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            WlrLayershell.namespace: "sidebar"

            anchors { top: true; right: true; bottom: true; left: true }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            Sidebar {
                id: panel
                s: win.s
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10 * win.s
                opened: win.visible
                onRequestClose: root.shown = false
            }
        }
    }
}
