import QtQuick
import "Singletons"

/**
 * The one button: primary, secondary, ghost or danger; 28 tall, presses in, dims when disabled.
 */
Rectangle {
    id: btn

    property real s: 1
    property string text: ""
    property string kind: "secondary"
    property bool lit: false

    signal clicked()

    readonly property bool hot: area.containsMouse || lit
    readonly property bool primary: kind === "primary"
    readonly property bool danger: kind === "danger"

    implicitWidth: label.implicitWidth + 24 * s
    implicitHeight: 28 * s
    width: implicitWidth
    height: implicitHeight
    radius: Theme.r.m * s
    opacity: enabled ? 1 : 0.45
    scale: area.pressed && !Motion.calm ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    color: primary ? (hot ? Qt.lighter(Theme.accentFill, 1.12) : Theme.accentFill)
        : danger ? Qt.alpha(Theme.danger, hot ? 0.22 : 0.12)
        : kind === "ghost" ? (hot ? Theme.frameBg : "transparent")
        : (hot ? Theme.tileBg : "transparent")
    Behavior on color { ColorAnimation { duration: 100 } }
    border.width: primary || kind === "ghost" ? 0 : 1
    border.color: danger ? Qt.alpha(Theme.danger, 0.45) : (hot ? Theme.vermDim : Theme.border)

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? Theme.onAccent : (btn.danger ? Theme.danger : Theme.cream)
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * btn.s
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: Math.min(0, (parent.height - 24 * btn.s) / 2)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
