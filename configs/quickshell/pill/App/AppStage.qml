import QtQuick
import "../Singletons"
import "app.js" as App

/** Preview stage at the top of pill pages: the resting pill above the hover pill at their real size, no panel behind them. */
Item {
    id: stage

    property real s: App.shell ? App.shell.s : 1
    /** "idle" or "hover" brings that pill forward and dims the other; empty shows both alike. */
    property string emphasis: ""

    implicitHeight: col.implicitHeight + 12 * s

    Column {
        id: col
        y: 10 * stage.s
        width: parent.width
        spacing: -10 * stage.s

        Item {
            width: parent.width
            height: restFade.height
            z: 2
            opacity: stage.emphasis === "hover" ? 0.55 : 1

            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            AppEdgeFade {
                id: restFade
                width: parent.width
                height: implicitHeight
                s: stage.s

                StagePill {
                    mode: "rest"
                    s: stage.s
                    interactive: false
                }
            }

            StageLabel {
                text: "Idle"
                s: stage.s
                lit: stage.emphasis === "idle"
            }
        }

        Item {
            width: parent.width
            height: hoverFade.height
            opacity: stage.emphasis === "idle" ? 0.55 : 1

            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            AppEdgeFade {
                id: hoverFade
                width: parent.width
                height: implicitHeight
                s: stage.s

                StagePill {
                    mode: "hover"
                    s: stage.s
                    interactive: true
                }
            }

            StageLabel {
                text: "Hover"
                s: stage.s
                lit: stage.emphasis === "hover"
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12 * stage.s
        anchors.rightMargin: 12 * stage.s
        height: 1
        color: Theme.hairSoft
    }

    component StageLabel: Rectangle {
        id: chip
        property real s: 1
        property bool lit: false
        property alias text: chipText.text
        anchors.left: parent.left
        anchors.leftMargin: 12 * s
        anchors.verticalCenter: parent.verticalCenter
        width: chipText.implicitWidth + 16 * s
        height: chipText.implicitHeight + 8 * s
        radius: 6 * s
        color: Theme.frameBg

        Text {
            id: chipText
            anchors.centerIn: parent
            color: chip.lit ? Theme.cream : Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11 * chip.s
            font.weight: Font.Medium
        }
    }
}
