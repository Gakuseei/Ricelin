import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * The drawn pill body, shared with the settings preview: shadow, card gradient at the pill opacity, hairline border and top sheen, each behind its flag.
 */
Item {
    id: root

    property real s: 1
    property real radius: 0

    /**
     * 0 keeps the corners round, 1 squares them for docking into the game bar.
     */
    property real flat: 0
    readonly property real corner: radius * (1 - flat)

    /**
     * One shader draws the shadow with no offscreen buffer, so it stays on through every morph.
     */
    RectangularShadow {
        anchors.fill: fill
        visible: Flags.pillShadow
        topLeftRadius: root.corner
        topRightRadius: root.corner
        bottomLeftRadius: root.corner
        bottomRightRadius: root.corner
        blur: 22 * root.s
        offset.y: 3 * root.s
        color: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
    }

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.corner
        topRightRadius: root.corner
        bottomLeftRadius: root.corner
        bottomRightRadius: root.corner
        border.width: Flags.pillBorder ? 1 : 0
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }

        Rectangle {
            visible: Flags.pillSheen
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: fill.radius * 0.6
            anchors.rightMargin: fill.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }
}
