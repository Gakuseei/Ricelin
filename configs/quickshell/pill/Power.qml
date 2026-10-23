pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "Singletons"

/**
 * Power surface: click actions (lock, sleep) left of the hairline, hold actions (log out, restart, shut down) right of it.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    property string hovered: ""
    property int focusIndex: -1
    property bool keyHeld: false

    property int holdingIndex: -1
    property real holdProgress: 0

    readonly property real anchorX: tiles.x + tiles.width / 2
    readonly property real anchorY: tiles.y - 10 * root.s
    property real tileHeatX: 0
    property real tileHeatY: 0
    property string soulKey: ""
    property real hoverX: 0
    property real hoverY: 0
    readonly property real heatX: holdingIndex >= 0 ? tileHeatX : (soulKey.length ? hoverX : anchorX)
    readonly property real heatY: holdingIndex >= 0 ? tileHeatY : (soulKey.length ? hoverY : anchorY)

    ameForm: holdingIndex >= 0 ? "dock" : (soulKey.length ? "soul" : "off")
    amePoint: Qt.point(heatX, heatY)

    readonly property var actions: [
        { key: "lock",     glyph: "lock",     label: "Lock",      confirm: false, dispatch: "",             argv: [Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"] },
        { key: "suspend",  glyph: "suspend",  label: "Sleep",     confirm: false, dispatch: "",             argv: ["systemctl", "suspend"] },
        { key: "logout",   glyph: "logout",   label: "log out",   confirm: true,  dispatch: "hl.dsp.exit()", argv: [] },
        { key: "reboot",   glyph: "reboot",   label: "restart",   confirm: true,  dispatch: "",             argv: ["systemctl", "reboot"] },
        { key: "shutdown", glyph: "shutdown", label: "shut down", confirm: true,  dispatch: "",             argv: ["systemctl", "poweroff"] }
    ]

    readonly property int splitAfter: 2
    readonly property real tileSize: 50 * s

    function run(a) {
        if (a.dispatch && a.dispatch.length)
            Hyprland.dispatch(a.dispatch);
        else
            Quickshell.execDetached(a.argv);
        root.requestClose();
    }

    /** Arrows move focus across the tiles; Enter fires a click tile and drives the heat fill on a hold tile. */
    function handleKey(e) {
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Right)
            move(e.key === Qt.Key_Left ? -1 : 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (!e.isAutoRepeat)
                pressFocused();
        } else
            return false;
        return true;
    }

    function handleRelease(e) {
        if (e.isAutoRepeat || (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space))
            return false;
        releaseFocused();
        return true;
    }

    function move(dir) {
        keyHeld = false;
        if (focusIndex < 0)
            focusIndex = dir > 0 ? 0 : actions.length - 1;
        else
            focusIndex = Math.max(0, Math.min(actions.length - 1, focusIndex + dir));
    }

    function pressFocused() {
        if (focusIndex < 0 || focusIndex >= actions.length)
            return false;
        if (actions[focusIndex].confirm) {
            keyHeld = true;
            return true;
        }
        run(actions[focusIndex]);
        return true;
    }

    function releaseFocused() {
        keyHeld = false;
    }

    onActiveChanged: if (!active) {
        hovered = "";
        soulKey = "";
        focusIndex = -1;
        keyHeld = false;
        holdingIndex = -1;
        holdProgress = 0;
    }

    SurfaceHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        glyph: "電"
        title: "POWER"
    }

    Row {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: header.bottom
        anchors.topMargin: Theme.sp.m * root.s
        spacing: Theme.sp.m * root.s

        Repeater {
            model: root.actions

            delegate: Row {
                id: cell
                required property int index
                required property var modelData
                spacing: Theme.sp.m * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cell.index === root.splitAfter
                    width: 1
                    height: 26 * root.s
                    color: Theme.hair
                }

                Item {
                    id: tile
                    width: root.tileSize
                    height: root.tileSize

                    readonly property real hold: heat.hold
                    readonly property bool kbFocus: root.focusIndex === cell.index
                    readonly property bool isHover: root.hovered === cell.modelData.key || tile.kbFocus
                    readonly property bool holding: heat.holding
                    readonly property bool lit: isHover || tile.holding
                    readonly property color accent: cell.modelData.confirm ? Theme.vermLit : Theme.cream

                    scale: tileArea.pressed && !Motion.calm ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    onKbFocusChanged: {
                        if (!tile.kbFocus)
                            return;
                        root.hovered = cell.modelData.key;
                        root.soulKey = cell.modelData.key;
                        const c = tile.mapToItem(root, tile.width / 2, 0);
                        root.hoverX = c.x;
                        root.hoverY = c.y - 9 * root.s;
                    }

                    /** A held Enter drives the same heat fill as a pointer hold; dropping the key drains it. */
                    readonly property bool keyDriving: tile.kbFocus && root.keyHeld && cell.modelData.confirm
                    onKeyDrivingChanged: {
                        if (tile.keyDriving)
                            heat.press();
                        else
                            heat.release();
                    }

                    onHoldChanged: {
                        if (cell.modelData.confirm && tile.hold > 0.001) {
                            root.holdingIndex = cell.index;
                            root.holdProgress = tile.hold;
                            const c = tile.mapToItem(root, tile.width / 2, tile.height / 2);
                            root.tileHeatX = c.x;
                            root.tileHeatY = c.y;
                        } else if (root.holdingIndex === cell.index) {
                            root.holdingIndex = -1;
                            root.holdProgress = 0;
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r.l * root.s
                        color: tileArea.pressed ? Theme.pressBg : (tile.isHover ? Theme.frameBg : "transparent")
                        border.width: 1
                        border.color: tile.isHover ? Theme.frameBorder : Theme.border
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    /** A plain Rectangle clamps its radius while the fill is flat, so the clip carries the corners. */
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: (Theme.r.l - 1) * root.s
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: tile.height * tile.hold
                            visible: tile.holding
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha(Theme.verm, 0.7)}
                                GradientStop { position: 1.0; color: Qt.alpha(Theme.vermLit, 0.15)}
                            }
                        }
                    }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 22 * root.s
                        height: width
                        name: cell.modelData.glyph
                        color: tile.holding ? Theme.flameCore : (tile.lit ? tile.accent : Theme.iconDim)
                        stroke: 1.9
                    }

                    HeatHold {
                        id: heat
                        onConfirmed: root.run(cell.modelData)
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.hovered = cell.modelData.key;
                            root.soulKey = cell.modelData.key;
                            const c = tile.mapToItem(root, tile.width / 2, 0);
                            root.hoverX = c.x;
                            root.hoverY = c.y - 9 * root.s;
                        }
                        onExited: {
                            if (root.hovered === cell.modelData.key)
                                root.hovered = "";
                            if (cell.modelData.confirm)
                                heat.cancel();
                        }
                        onPressed: if (cell.modelData.confirm) heat.press()
                        onReleased: if (cell.modelData.confirm) heat.release()
                        onClicked: {
                            if (!cell.modelData.confirm)
                                root.run(cell.modelData);
                        }
                    }
                }
            }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: tiles.bottom
        anchors.topMargin: Theme.sp.m * root.s
        readonly property string focusKey: root.holdingIndex >= 0
            ? root.actions[root.holdingIndex].key : root.hovered
        readonly property var act: {
            for (var i = 0; i < root.actions.length; i++)
                if (root.actions[i].key === label.focusKey)
                    return root.actions[i];
            return null;
        }
        text: !act ? "Hold to log out, restart or shut down"
            : act.confirm ? "Hold to " + act.label : act.label
        color: !act ? Theme.textFaint : act.confirm ? Theme.vermLit : Theme.cream
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
    }
}
