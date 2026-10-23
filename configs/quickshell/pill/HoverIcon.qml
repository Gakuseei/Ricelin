import QtQuick
import "Singletons"

/**
 * A status icon in the hover row: opens its surface on click and parks Ame under itself on hover.
 */
Item {
    id: root

    required property Item host
    property string surface
    property string glyph
    property color tint: Theme.iconDim
    property real stroke: 1.7
    readonly property bool hovered: area.containsMouse
    default property alias content: extra.data

    signal rightClicked()
    signal doubleClicked()

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    implicitWidth: 17 * host.s
    implicitHeight: 17 * host.s

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
        anchors.margins: -6 * root.host.s
        hoverEnabled: true
        enabled: root.host.mode === "hover"
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.RightButton)
                root.rightClicked();
            else
                root.host.requestSurface(root.surface);
        }
        onDoubleClicked: (e) => {
            if (e.button === Qt.LeftButton)
                root.doubleClicked();
        }
        onContainsMouseChanged: if (containsMouse) root.host.soulItem = root
    }
}
