import QtQuick
import "Singletons"

Item {
    id: sidebar
    required property real s
    property bool opened: false
    signal requestClose()

    readonly property real panelWidth: 372 * s
    implicitWidth: panelWidth

    focus: opened
    Keys.onEscapePressed: sidebar.requestClose()

    Rectangle {
        id: card
        width: sidebar.panelWidth
        height: parent.height
        radius: 22 * s
        color: "transparent"
        border.width: 1
        border.color: Theme.border

        x: sidebar.opened ? 0 : sidebar.panelWidth + 16 * s
        opacity: sidebar.opened ? 1 : 0
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: stack
            anchors.fill: parent
            anchors.margins: 14 * sidebar.s
            spacing: 12 * sidebar.s
        }
    }
}
