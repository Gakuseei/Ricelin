import QtQuick
import QtQuick.Effects
import "../Singletons"
import "app.js" as App

/** Slider over `from`..`to` on `step` with a `unit` readout (or `fmt(v)`); `moved(v)` streams while dragging, `committed(v)` fires on release, wheel and arrow keys. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property string unit: ""
    property int decimals: -1
    property var fmt: null
    property real trackWidth: 170
    property bool showValue: true
    signal moved(real value)
    signal committed(real value)

    readonly property int places: decimals >= 0 ? decimals : (String(step).indexOf(".") >= 0 ? String(step).split(".")[1].length : 0)
    property bool dragging: false
    property real live: value
    readonly property real shown: dragging || nudging.running ? live : value
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    implicitWidth: track.width + (showValue ? 12 * s + readout.width : 0)
    implicitHeight: 20 * s
    activeFocusOnTab: true

    function snap(v) {
        let n = from + Math.round((v - from) / step) * step;
        n = Math.max(Math.min(from, to), Math.min(Math.max(from, to), n));
        const p = Math.pow(10, places);
        return Math.round(n * p) / p;
    }

    function label(v) {
        if (fmt)
            return fmt(v);
        const t = v.toFixed(places);
        if (unit.length === 0)
            return t;
        return (unit === "%" || unit === "×" || unit === "°") ? t + unit : t + " " + unit;
    }

    /** Wheel and keys step at once but write once things settle. */
    function nudge(steps) {
        const base = nudging.running ? live : value;
        const n = snap(base + steps * step);
        if (n === base)
            return;
        live = n;
        moved(n);
        nudging.restart();
    }

    Timer {
        id: nudging
        interval: 350
        onTriggered: root.committed(root.live)
    }

    Keys.onLeftPressed: nudge(-1)
    Keys.onDownPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)
    Keys.onUpPressed: nudge(1)
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_PageUp || e.key === Qt.Key_PageDown) {
            nudge(e.key === Qt.Key_PageUp ? 10 : -10);
            e.accepted = true;
        } else if (e.key === Qt.Key_Home || e.key === Qt.Key_End) {
            nudge(Math.round(((e.key === Qt.Key_Home ? from : to) - value) / step));
            e.accepted = true;
        }
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.trackWidth * root.s
        height: 20 * root.s

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4 * root.s
            radius: height / 2
            color: Qt.alpha(Theme.cream, 0.14)

            Rectangle {
                width: parent.width * root.frac
                height: parent.height
                radius: height / 2
                color: Theme.verm
            }
        }

        RectangularShadow {
            anchors.fill: thumb
            radius: thumb.radius
            blur: 6 * root.s
            offset.y: 1 * root.s
            color: Qt.rgba(0, 0, 0, 0.45)
            scale: thumb.scale
        }
        Rectangle {
            id: thumb
            anchors.verticalCenter: parent.verticalCenter
            x: root.frac * (parent.width - width)
            width: 14 * root.s
            height: width
            radius: width / 2
            color: Theme.cream
            border.width: root.activeFocus ? 3 * root.s : 0
            border.color: Qt.alpha(Theme.vermLit, 0.6)
            scale: area.containsMouse || root.dragging ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.leftMargin: -7 * root.s
            anchors.rightMargin: -7 * root.s
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function at(x) {
                const f = Math.max(0, Math.min(1, (x - 7 * root.s) / track.width));
                return root.snap(root.from + f * (root.to - root.from));
            }
            onPressed: (mouse) => {
                nudging.stop();
                root.dragging = true;
                root.live = at(mouse.x);
                root.moved(root.live);
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return;
                const v = at(mouse.x);
                if (v !== root.live) {
                    root.live = v;
                    root.moved(v);
                }
            }
            onReleased: {
                root.dragging = false;
                root.committed(root.live);
            }
            onCanceled: {
                root.dragging = false;
                root.committed(root.live);
            }

            property real acc: 0
            onWheel: (event) => {
                acc += (event.angleDelta.y || event.angleDelta.x) / 120;
                const n = Math.trunc(acc);
                if (n !== 0) {
                    root.nudge(n);
                    acc -= n;
                }
                event.accepted = true;
            }
        }
    }

    Text {
        id: readout
        visible: root.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(56 * root.s, implicitWidth)
        horizontalAlignment: Text.AlignRight
        text: root.label(root.shown)
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 12.5 * root.s
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
}
