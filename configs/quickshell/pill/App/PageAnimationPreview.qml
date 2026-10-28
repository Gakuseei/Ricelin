pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "app.js" as App

/** A tiny desktop that replays a window opening, another closing and a workspace sliding on the given `curve` and `duration`; `play()` restarts it, it never loops. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property var curve: [0.16, 1, 0.3, 1]
    property int duration: 420
    property bool animate: true
    /** Plays every move four times slower, for watching the curve; the real duration is unchanged. */
    property bool slow: false
    readonly property bool calm: Motion.calm

    readonly property int dur: animate ? Math.max(1, duration) * (slow ? 4 : 1) : 1
    /** Linear time through the move that is playing, 0 to 1; -1 between moves. */
    property real clock: -1
    readonly property var spline: [curve[0], curve[1], curve[2], curve[3], 1, 1]
    readonly property var fadeSpline: [0.5, 0.5, 0.75, 1, 1, 1]

    property real split: 0
    property real grow: 0
    property real ws: 0
    property string step: ""

    readonly property real g: 7 * s
    readonly property real areaY: pill.y + pill.height + g
    readonly property real aw: width - 2 * g
    readonly property real ah: height - areaY - g
    readonly property real half: (aw - g) / 2

    implicitWidth: 300 * s
    implicitHeight: 188 * s

    function play() {
        seq.stop();
        reset();
        seq.start();
    }

    function reset() {
        split = 0;
        grow = 0;
        ws = 0;
        w1.pop = 1;
        w1.opacity = 1;
        w2.pop = 0;
        w2.opacity = 0;
        step = "";
        clock = -1;
    }

    Component.onCompleted: reset()

    Rectangle {
        id: desk
        anchors.fill: parent
        radius: 12 * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.hairSoft
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.alpha(Theme.vermDeep, 0.14) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Item {
            id: wsOne
            width: parent.width
            height: parent.height
            x: root.calm ? 0 : -root.ws * root.width
            opacity: root.calm ? 1 - root.ws : 1
            visible: opacity > 0 && x > -width

            MiniWindow {
                id: w1
                x: root.g
                y: root.areaY
                width: root.aw - root.split * (root.aw - root.half)
                height: root.ah
                focused: root.split < 0.5
            }
            MiniWindow {
                id: w2
                x: root.g + (root.half + root.g) * (1 - root.grow)
                y: root.areaY
                width: root.half + root.grow * (root.aw - root.half)
                height: root.ah
                focused: true
                lines: 2
            }
        }

        Item {
            id: wsTwo
            width: parent.width
            height: parent.height
            x: root.calm ? 0 : (1 - root.ws) * root.width
            opacity: root.calm ? root.ws : 1
            visible: opacity > 0 && x < width

            MiniWindow {
                x: root.g
                y: root.areaY
                width: root.aw
                height: root.ah
                focused: true
                dark: true
                lines: 4
            }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6 * root.s
            width: 64 * root.s
            height: 14 * root.s
            radius: height / 2
            color: Theme.cardBot
            border.width: 1
            border.color: Theme.hair

            Row {
                anchors.centerIn: parent
                spacing: 3 * root.s

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        readonly property real lit: index === 0 ? 1 - root.ws : (index === 1 ? root.ws : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        width: (4 + 7 * lit) * root.s
                        height: 4 * root.s
                        radius: height / 2
                        color: lit > 0.5 ? Theme.vermLit : Qt.alpha(Theme.cream, 0.35)
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: seq

        PauseAnimation { duration: 260 }
        ScriptAction { script: root.step = "A window opens" }
        ParallelAnimation {
            NumberAnimation { target: w2; property: "pop"; from: 0; to: 1; duration: root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spline }
            NumberAnimation { target: w2; property: "opacity"; from: 0; to: 1; duration: root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.fadeSpline }
            NumberAnimation { target: root; property: "split"; from: 0; to: 1; duration: root.calm ? 1 : root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spline }
            NumberAnimation { target: root; property: "clock"; from: 0; to: 1; duration: root.dur }
        }
        ScriptAction { script: root.clock = -1 }
        PauseAnimation { duration: 520 }
        ScriptAction { script: root.step = "Another one closes" }
        ParallelAnimation {
            NumberAnimation { target: w1; property: "pop"; from: 1; to: 0; duration: root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spline }
            NumberAnimation { target: w1; property: "opacity"; from: 1; to: 0; duration: root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.fadeSpline }
            NumberAnimation { target: root; property: "grow"; from: 0; to: 1; duration: root.calm ? 1 : root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spline }
            NumberAnimation { target: root; property: "clock"; from: 0; to: 1; duration: root.dur }
        }
        ScriptAction { script: root.clock = -1 }
        PauseAnimation { duration: 520 }
        ScriptAction { script: root.step = root.calm ? "The next workspace fades in" : "The next workspace slides in" }
        ParallelAnimation {
            NumberAnimation { target: root; property: "ws"; from: 0; to: 1; duration: root.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spline }
            NumberAnimation { target: root; property: "clock"; from: 0; to: 1; duration: root.dur }
        }
        ScriptAction { script: root.clock = -1 }
        PauseAnimation { duration: 700 }
        ScriptAction { script: root.step = "" }
    }

    component MiniWindow: Rectangle {
        id: mw
        property real pop: 1
        property bool focused: false
        property bool dark: false
        property int lines: 3

        radius: 5 * root.s
        color: dark ? Theme.cardBot : Theme.cardTop
        border.width: Math.max(1, 1.5 * root.s)
        border.color: focused ? Theme.vermLit : Theme.border
        scale: root.calm ? 1 : 0.92 + 0.08 * pop
        antialiasing: true

        Row {
            x: 6 * root.s
            y: 6 * root.s
            spacing: 3 * root.s

            Repeater {
                model: 3

                Rectangle {
                    width: 4 * root.s
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Theme.cream, 0.28)
                }
            }
        }

        Column {
            x: 8 * root.s
            y: 18 * root.s
            width: parent.width - 16 * root.s
            spacing: 5 * root.s

            Repeater {
                model: mw.lines

                Rectangle {
                    required property int index
                    width: parent.width * (index === 0 ? 0.55 : (index % 2 ? 0.8 : 0.66))
                    height: 4 * root.s
                    radius: height / 2
                    color: mw.dark && index === 0 ? Qt.alpha(Theme.vermLit, 0.55) : Qt.alpha(Theme.cream, index === 0 ? 0.3 : 0.14)
                }
            }
        }
    }
}
