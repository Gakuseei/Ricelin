pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "Singletons"

/**
 * Workspaces for one monitor as dots (the active one a stick), numbers or names: this monitor's ruled workspaces plus any live ones outside the rules.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s
    property real fontPx: 11 * s

    /** "dots", "numbers" or "names". */
    property string style: "dots"
    /** "occupied" shows the ruled and live ones; "all" also fills the gaps up to the highest. */
    property string show: "occupied"
    property bool scroll: false
    /** False keeps the hover feedback but never switches, as in the settings preview. */
    property bool actions: true

    readonly property bool dots: style !== "numbers" && style !== "names"

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
        var a = activeId;
        if (a >= 1 && !seen[a])
            out.push(a);
        out.sort(function (x, y) { return x - y; });
        if (show === "all" && out.length > 0) {
            var full = [];
            for (var n = (ruled && ruled.length) ? out[0] : 1; n <= out[out.length - 1]; n++)
                full.push(n);
            return full;
        }
        return out;
    }

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || null
    readonly property var activeWs: monitor ? monitor.activeWorkspace : null
    readonly property int activeId: activeWs ? activeWs.id : -1
    readonly property string activeName: activeWs ? activeWs.name : ""

    readonly property var names: {
        var m = ({});
        var wss = Hyprland.workspaces.values;
        for (var i = 0; i < wss.length; i++)
            if (wss[i].id >= 1)
                m[wss[i].id] = wss[i].name;
        return m;
    }

    function label(id) {
        var n = style === "names" ? names[id] : undefined;
        return (n && !/^\d+$/.test(n)) ? n : String(id);
    }

    property int hoverIndex: -1

    readonly property int activeIndex: range.indexOf(activeId)

    /** Centre x of a slot from end-state widths, so a marker aimed here lands where the dot settles. */
    function slotCenterX(idx) {
        if (!dots) {
            const it = slots.itemAt(idx);
            return it ? it.x + it.width / 2 : 0;
        }
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

    function go(id) {
        if (actions)
            Hyprland.dispatch('hl.dsp.focus({workspace="' + id + '"})');
    }

    function step(dir) {
        if (range.length === 0)
            return;
        const from = activeIndex >= 0 ? activeIndex : (dir > 0 ? -1 : range.length);
        const to = range[Math.max(0, Math.min(range.length - 1, from + dir))];
        if (to !== activeId)
            go(to);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    /**
     * Wheel notches add up to 120 per step, touchpad pixels included, and a short gap after each switch keeps one fling from racing across.
     */
    MouseArea {
        id: wheel

        property real acc: 0
        property real lastWheel: 0
        property real lastStep: 0

        anchors.fill: parent
        anchors.topMargin: -8 * workspaces.s
        anchors.bottomMargin: -8 * workspaces.s
        enabled: workspaces.scroll && workspaces.actions
        acceptedButtons: Qt.NoButton
        onWheel: (e) => {
            const now = Date.now();
            if (now - wheel.lastWheel > 400)
                wheel.acc = 0;
            wheel.lastWheel = now;
            wheel.acc += e.angleDelta.y !== 0 ? e.angleDelta.y : -e.angleDelta.x;
            if (Math.abs(wheel.acc) < 120)
                return;
            const dir = wheel.acc > 0 ? -1 : 1;
            wheel.acc = 0;
            if (now - wheel.lastStep < 100)
                return;
            wheel.lastStep = now;
            workspaces.step(dir);
        }
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            id: slots
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData
                required property int index

                readonly property int wsId: modelData
                readonly property bool isActive: workspaces.activeId === wsId

                Layout.preferredWidth: workspaces.dots ? (slot.isActive ? workspaces.stickW : workspaces.dotW)
                    : Math.max(label.implicitWidth, 2 * workspaces.dotW)
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth {
                    enabled: workspaces.dots
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }

                Rectangle {
                    visible: workspaces.dots
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.pressed ? 0.9 : (area.containsMouse ? 0.7 : 0.3))
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                }

                Text {
                    id: label
                    visible: !workspaces.dots
                    anchors.centerIn: parent
                    text: workspaces.dots ? "" : workspaces.label(slot.wsId)
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.pressed ? 0.9 : (area.containsMouse ? 0.75 : 0.45))
                    font.family: Theme.font
                    font.pixelSize: workspaces.fontPx
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
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
                    onClicked: workspaces.go(slot.wsId)
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
