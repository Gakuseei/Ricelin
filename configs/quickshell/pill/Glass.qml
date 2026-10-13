import QtQuick
import "Singletons"

/**
 * The translucent glass panel the dock and the blade fan are built from.
 *
 * It paints no blur itself: the blur behind it comes from the compositor (the
 * `ricelin-glass` layer rule in hypr/modules/window_rules.lua blurs every layer
 * surface whose namespace starts with ricelin-). What this adds on top is the
 * glass look: a see-through body tinted from the theme, a soft sheen across the
 * top, a bright hairline rim and a faint specular line along the upper edge.
 * Everything is derived from Theme, so a palette change recolors it.
 *
 * Children go inside the panel and are laid out against its full area.
 */
Item {
    id: root

    property real radius: 18
    /** Body opacity. Lower lets more of the blurred wallpaper through. */
    property real clarity: 0.4
    /** Hover or active: brighter rim and sheen. */
    property bool lit: false

    default property alias content: slot.data

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Qt.lighter(Theme.cardTop, 1.25), Math.min(1, root.clarity + 0.05)) }
            GradientStop { position: 1; color: Qt.alpha(Theme.cardBot, Math.max(0, root.clarity - 0.09)) }
        }
    }

    // Sheen: light pooled along the top, fading out by the middle.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.bright, root.lit ? 0.20 : 0.12) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.bright, 0.025) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // Inner edge: a faint dark line just inside the rim gives the pane thickness.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.16)
    }

    // Rim.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.bright, root.lit ? 0.42 : 0.28)
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
    }

    // Specular line just under the top edge, brightest in the middle.
    Rectangle {
        height: 1
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.radius * 0.9
        anchors.rightMargin: root.radius * 0.9
        visible: width > 8
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.bright, root.lit ? 0.55 : 0.38) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Item {
        id: slot
        anchors.fill: parent
    }
}
