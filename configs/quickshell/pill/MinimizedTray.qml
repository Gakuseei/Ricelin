pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Singletons"

/**
 * Icons for windows parked on special:minimized; a click brings one back to this monitor's workspace.
 */
Row {
    id: root

    property real s: 1
    property string screenName: ""
    spacing: 8 * s

    function restoreWorkspace() {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName && ms[i].activeWorkspace)
                return ms[i].activeWorkspace.id;
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
    }

    readonly property var items: {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            if (t && t.workspace && t.workspace.name === "special:minimized")
                out.push(t);
        }
        return out;
    }
    readonly property int count: items.length

    /** Window class to desktop-entry icon (the class often differs from the icon name), else a direct theme lookup. */
    function iconFor(t) {
        var cls = (t && t.lastIpcObject && t.lastIpcObject.class) ? t.lastIpcObject.class
            : (t && t.wayland && t.wayland.appId ? t.wayland.appId : "");
        if (!cls)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === cls.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(cls, "application-x-executable");
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: chip
            required property var modelData
            width: 18 * root.s
            height: 18 * root.s

            readonly property string iconSrc: root.iconFor(chip.modelData)

            Image {
                anchors.fill: parent
                sourceSize.width: Math.round(36 * root.s)
                sourceSize.height: Math.round(36 * root.s)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                source: chip.iconSrc
                opacity: area.containsMouse ? 1 : 0.78
                scale: area.pressed && !Motion.calm ? 0.9 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var addr = chip.modelData.address;
                    if (addr.indexOf("0x") !== 0)
                        addr = "0x" + addr;
                    Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + root.restoreWorkspace() + ', window = "address:' + addr + '" })');
                }
            }

            Tooltip {
                s: root.s
                placement: "below"
                title: chip.modelData.title
                show: area.containsMouse
            }
        }
    }
}
