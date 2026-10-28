pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../Singletons"
import "app.js" as App

/** Bezier editor in unit curve space (y up, may overshoot by `over`): two draggable handles; `edited(x1, y1, x2, y2)` streams while dragging, `released()` ends a drag. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property real x1: 0.16
    property real y1: 1
    property real x2: 0.3
    property real y2: 1
    signal edited(real x1, real y1, real x2, real y2)
    signal released()

    readonly property real es: 160 * s
    readonly property real over: 0.25
    readonly property real pad: over * es
    readonly property real hr: 7 * s
    property int dragging: 0
    /** Time through a playing move, 0 to 1; a dot rides the curve there. -1 hides it. */
    property real clock: -1

    /** The curve's progress at time `tx`: solves x(t) = tx by bisection, then reads y(t). */
    function ease(tx) {
        const bx = (t) => 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
        let lo = 0, hi = 1, t = tx;
        for (let i = 0; i < 24; i++) {
            t = (lo + hi) / 2;
            if (bx(t) < tx)
                lo = t;
            else
                hi = t;
        }
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
    }

    implicitWidth: es + 2 * pad
    implicitHeight: es + 2 * pad

    function px(v) {
        return pad + v * es;
    }
    function py(v) {
        return pad + (1 - v) * es;
    }

    function clampX(v) {
        return Math.max(0, Math.min(1, v));
    }
    function clampY(v) {
        return Math.max(-over, Math.min(1 + over, v));
    }

    /** Moves handle `which` (1 or 2) to curve coordinates, rounded to the two places the file keeps. */
    function dragHandle(which, fx, fy) {
        const nx = Math.round(clampX(fx) * 100) / 100;
        const ny = Math.round(clampY(fy) * 100) / 100;
        if (which === 1)
            edited(nx, ny, x2, y2);
        else
            edited(x1, y1, nx, ny);
    }

    function endDrag() {
        dragging = 0;
        released();
    }

    Rectangle {
        anchors.fill: parent
        radius: 12 * root.s
        color: Theme.frameBg
        border.width: 1
        border.color: Theme.hairSoft
    }

    Repeater {
        model: 3

        Rectangle {
            required property int index
            x: root.pad + (index + 1) * root.es / 4
            y: root.pad
            width: 1
            height: root.es
            color: Theme.hairSoft
        }
    }
    Repeater {
        model: 3

        Rectangle {
            required property int index
            x: root.pad
            y: root.pad + (index + 1) * root.es / 4
            width: root.es
            height: 1
            color: Theme.hairSoft
        }
    }
    Rectangle {
        x: root.pad
        y: root.pad
        width: root.es
        height: root.es
        color: "transparent"
        border.width: 1
        border.color: Theme.hair
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Theme.cream, 0.18)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 4]
            fillColor: "transparent"
            startX: root.px(0); startY: root.py(0)
            PathLine { x: root.px(1); y: root.py(1) }
        }
        ShapePath {
            strokeColor: Qt.alpha(Theme.cream, 0.4)
            strokeWidth: 1.2 * root.s
            fillColor: "transparent"
            startX: root.px(0); startY: root.py(0)
            PathLine { x: root.px(root.x1); y: root.py(root.y1) }
        }
        ShapePath {
            strokeColor: Qt.alpha(Theme.cream, 0.4)
            strokeWidth: 1.2 * root.s
            fillColor: "transparent"
            startX: root.px(1); startY: root.py(1)
            PathLine { x: root.px(root.x2); y: root.py(root.y2) }
        }
        ShapePath {
            strokeColor: Theme.vermLit
            strokeWidth: 2.4 * root.s
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.px(0); startY: root.py(0)
            PathCubic {
                control1X: root.px(root.x1); control1Y: root.py(root.y1)
                control2X: root.px(root.x2); control2Y: root.py(root.y2)
                x: root.px(1); y: root.py(1)
            }
        }
    }

    Repeater {
        model: [[0, 0], [1, 1]]

        Rectangle {
            required property var modelData
            x: root.px(modelData[0]) - width / 2
            y: root.py(modelData[1]) - height / 2
            width: 6 * root.s
            height: width
            radius: width / 2
            color: Theme.textFaint
        }
    }

    Rectangle {
        visible: root.clock >= 0
        x: root.px(root.clock) - width / 2
        y: root.py(1 + root.over)
        width: 1
        height: root.es * (1 + 2 * root.over)
        color: Qt.alpha(Theme.vermLit, 0.35)
    }

    Rectangle {
        visible: root.clock >= 0
        x: root.px(root.clock) - width / 2
        y: root.py(root.ease(root.clock)) - height / 2
        width: 9 * root.s
        height: width
        radius: width / 2
        color: Theme.cream
        border.width: 2 * root.s
        border.color: Theme.vermLit
    }

    Handle {
        which: 1
        fx: root.x1
        fy: root.y1
    }
    Handle {
        which: 2
        fx: root.x2
        fy: root.y2
    }

    component Handle: Rectangle {
        id: h
        required property int which
        required property real fx
        required property real fy
        readonly property bool active: root.dragging === which

        x: root.px(fx) - width / 2
        y: root.py(fy) - height / 2
        z: active ? 2 : 1
        width: 2 * root.hr
        height: width
        radius: width / 2
        color: active ? Theme.bright : Theme.cream
        border.width: 2 * root.s
        border.color: Theme.vermLit
        scale: active && !Motion.calm ? 1.2 : (hArea.containsMouse ? 1.1 : 1)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        MouseArea {
            id: hArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeAllCursor
            property real offX: 0
            property real offY: 0

            onPressed: (mouse) => {
                const p = mapToItem(root, mouse.x, mouse.y);
                offX = p.x - root.px(h.fx);
                offY = p.y - root.py(h.fy);
                root.dragging = h.which;
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return;
                const p = mapToItem(root, mouse.x, mouse.y);
                root.dragHandle(h.which, (p.x - offX - root.pad) / root.es, 1 - (p.y - offY - root.pad) / root.es);
            }
            onReleased: root.endDrag()
            onCanceled: root.endDrag()
        }
    }
}
