import QtQuick
import "Singletons"

/**
 * What is running beside the resting clock: a coding agent that finished or waits, else a timer.
 */
Item {
    id: act

    property real s: 1
    readonly property string kind: Agents.top ? "agent" : Countdown.active ? "timer" : ""
    readonly property bool waits: kind === "agent" && Agents.top.status === "wait"

    implicitWidth: kind.length > 0 ? row.implicitWidth : 0
    implicitHeight: 20 * s

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * act.s

        Rectangle {
            id: pulse
            anchors.verticalCenter: parent.verticalCenter
            visible: act.waits
            width: 7 * act.s
            height: width
            radius: width / 2
            color: Theme.vermLit
            SequentialAnimation on opacity {
                running: pulse.visible && !Motion.calm
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind.length > 0 && !act.waits
            width: 14 * act.s
            height: width
            name: act.kind === "timer" ? "stopwatch" : "check"
            color: Theme.vermLit
            stroke: 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: act.kind === "agent" ? Agents.project(Agents.top) : act.kind === "timer" ? Countdown.label : ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14 * act.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind === "agent"
            text: act.waits ? "needs you" : "finished"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 14 * act.s
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: act.kind === "agent"
        cursorShape: Qt.PointingHandCursor
        onClicked: Agents.focus(Agents.top)
    }
}
