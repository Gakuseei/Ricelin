pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "Singletons"

/**
 * Workspace dots for one monitor: this monitor's ruled workspaces plus any live ones outside the rules; the active one is a stick.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    readonly property var range: {
        var out = [];
        var seen = ({});
        var ruled = Workspacerules.byMonitor[screenName];
        if (ruled && ruled.length) {
            for (var r = 0; r < ruled.length; r++) {
                if (!seen[ruled[r]]) {
                    seen[ruled[r]] = true;
                    out.push(ruled[r]);
                }
            }
        }

        var wss = Hyprland.workspaces.values;
        for (var i = 0; i < wss.length; i++) {
            var w = wss[i];
            if (w.id >= 1 && w.monitor && w.monitor.name === screenName && !seen[w.id]) {
                seen[w.id] = true;
                out.push(w.id);
            }
        }
        var a = parseInt(activeName);
        if (a >= 1 && !seen[a])
            out.push(a);
        out.sort(function (x, y) { return x - y; });
        return out;
    }

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || null
    readonly property string activeName: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""

    property int hoverIndex: -1

    readonly property int activeIndex: range.indexOf(parseInt(activeName))

    /** Centre x of a slot from end-state widths, so a marker aimed here lands where the dot settles. */
    function slotCenterX(idx) {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += (i === activeIndex ? stickW : dotW) + gap;
        return x + (idx === activeIndex ? stickW : dotW) / 2;
    }

    readonly property point activeDotPoint: {
        void workspaces.activeName;
        void workspaces.width;
        return Qt.point(slotCenterX(Math.max(0, activeIndex)), height / 2);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData
                required property int index

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName

                Layout.preferredWidth: slot.isActive ? workspaces.stickW : workspaces.dotW
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.pressed ? 0.9 : (area.containsMouse ? 0.7 : 0.3))
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace="' + slot.wsName + '"})')
                    onContainsMouseChanged: {
                        if (containsMouse)
                            workspaces.hoverIndex = slot.index;
                        else if (workspaces.hoverIndex === slot.index)
                            workspaces.hoverIndex = -1;
                    }
                }
            }
        }
    }
}
