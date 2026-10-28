import QtQuick
import "../Singletons"
import ".."
import "app.js" as App

/** Button of `kind` "primary", "secondary", "ghost" or "danger" with an optional Tabler `icon` and `small` size; `clicked()` on click, Space or Enter. */
Rectangle {
    id: btn

    property real s: App.shell ? App.shell.s : 1
    property string text: ""
    property string icon: ""
    property string kind: "secondary"
    property bool small: false
    signal clicked()

    readonly property bool primary: kind === "primary"
    readonly property bool danger: kind === "danger"
    readonly property bool hot: area.containsMouse && enabled
    readonly property color ink: primary ? Theme.onAccent : (danger ? Theme.danger : Theme.cream)

    implicitWidth: content.implicitWidth + 2 * (small ? 10 : 12) * s
    implicitHeight: (small ? 26 : 30) * s
    radius: (small ? 7 : 8) * s
    opacity: enabled ? 1 : 0.38
    activeFocusOnTab: enabled
    scale: area.pressed && !Motion.calm ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    color: primary ? (hot ? Qt.lighter(Theme.accentFill, 1.12) : Theme.accentFill)
        : danger ? Qt.alpha(Theme.danger, hot ? 0.14 : 0.06)
        : kind === "ghost" ? (hot ? Theme.frameBg : "transparent")
        : (hot ? Theme.pressBg : Theme.frameBg)
    Behavior on color { ColorAnimation { duration: 120 } }
    border.width: btn.activeFocus ? 2 * s : (primary || kind === "ghost" ? 0 : 1)
    border.color: btn.activeFocus ? Qt.alpha(Theme.vermLit, 0.6) : (danger ? Qt.alpha(Theme.danger, 0.35) : Theme.frameBorder)

    Keys.onSpacePressed: btn.clicked()
    Keys.onReturnPressed: btn.clicked()
    Keys.onEnterPressed: btn.clicked()

    Row {
        id: content
        anchors.centerIn: parent
        spacing: (btn.small ? 6 : 7) * btn.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon.length > 0
            width: (btn.small ? 13 : 14) * btn.s
            height: width
            name: btn.icon
            color: btn.primary || btn.danger ? btn.ink : (btn.hot ? Theme.cream : Theme.iconDim)
            stroke: 1.9
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text.length > 0
            text: btn.text
            color: btn.ink
            font.family: Theme.font
            font.pixelSize: (btn.small ? 12 : 12.5) * btn.s
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
    }
}
