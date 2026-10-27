import QtQuick
import "Singletons"

/**
 * A status icon in a module row: each button runs its `Flags.hoverActions` entry or the built-in, and hovering parks Ame under it.
 */
Item {
    id: root

    required property Item row
    property string iconId
    property string surface
    property string glyph
    property color tint: Theme.iconDim
    property real stroke: 1.7
    property bool shown: true
    readonly property bool hovered: area.containsMouse
    default property alias content: extra.data

    signal rightClicked()
    signal doubleClicked()

    implicitWidth: 17 * row.s
    implicitHeight: 17 * row.s

    GlyphIcon {
        anchors.fill: parent
        visible: root.glyph.length > 0
        name: root.glyph
        color: area.containsMouse ? Theme.cream : root.tint
        stroke: root.stroke
    }

    Item {
        id: extra
        anchors.fill: parent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.row.s
        hoverEnabled: true
        enabled: root.row.live
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.RightButton)
                root.row.press(root.iconId, "right", root.surface, () => root.rightClicked());
            else
                root.row.press(root.iconId, "left", root.surface, () => root.row.open(root.surface));
        }
        onDoubleClicked: (e) => {
            if (e.button === Qt.LeftButton && root.row.actions)
                root.doubleClicked();
        }
        onContainsMouseChanged: if (containsMouse) root.row.soul(root)
    }
}
