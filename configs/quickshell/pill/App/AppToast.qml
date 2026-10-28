import QtQuick
import QtQuick.Effects
import ".."
import "../Singletons"
import "app.js" as App

/** Bottom-centre toast; `show(message, kind)` slides it in for 2.4 s, kind "error" drops the check and tints the edge; App.toast(message, kind) reaches it from anywhere. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property string message: ""
    property bool error: false
    property bool shown: false

    function show(msg, kind) {
        message = msg;
        error = kind === "error";
        shown = true;
        hideTimer.restart();
    }

    width: pillBox.width
    height: pillBox.height
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate {
        y: root.shown || Motion.calm ? 0 : 12 * root.s
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
    }

    Timer {
        id: hideTimer
        interval: 2400
        onTriggered: root.shown = false
    }

    RectangularShadow {
        anchors.fill: pillBox
        radius: pillBox.radius
        blur: 26 * root.s
        offset.y: 8 * root.s
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        id: pillBox
        width: row.implicitWidth + 28 * root.s
        height: 36 * root.s
        radius: height / 2
        color: Theme.cardTop
        border.width: 1
        border.color: root.error ? Qt.alpha(Theme.danger, 0.55) : Theme.border

        Row {
            id: row
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.error ? 0 : -2 * root.s
            spacing: 8 * root.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.error
                width: 14 * root.s
                height: width
                name: "check"
                stroke: 2.2
                color: Theme.vermLit
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.message
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
            }
        }
    }

    MouseArea {
        anchors.fill: pillBox
        enabled: root.shown
        onClicked: root.shown = false
    }
}
