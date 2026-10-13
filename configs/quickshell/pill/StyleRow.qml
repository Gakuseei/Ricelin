pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * One line in the Styles surface: a name, a faint line under it, and on the right
 * either a lit dot (this is the active one) or a chevron (it opens something).
 * Same row shape and hover treatment as AppTile, so the surface reads as another
 * Ricelin list.
 */
Item {
    id: root

    property real s: 1
    property string name: ""
    property string sub: ""
    property string glyph: ""
    /** True for the style that is running now. */
    property bool active: false
    /** True when the row opens another surface instead of choosing a style. */
    property bool opens: false
    property bool selected: false
    property bool last: false

    signal activated()

    width: parent ? parent.width : 0
    height: 48 * root.s

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3 * root.s
        anchors.bottomMargin: 3 * root.s
        radius: 10 * root.s
        color: root.selected ? Theme.threadBg : (hover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: root.selected ? Theme.hair : (hover.hovered ? Theme.frameBorder : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Rectangle {
        id: tile
        anchors.left: parent.left
        anchors.leftMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 30 * root.s
        height: 30 * root.s
        radius: Motion.rSmall * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: root.active ? Theme.onGlow : Theme.hairSoft
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: root.glyph
            color: root.active ? Theme.onGlow : Theme.iconDim
            stroke: 1.7
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12 * root.s
        anchors.right: marker.left
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * root.s

        Text {
            width: parent.width
            text: root.name
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.sub
            color: root.active ? Theme.flameGlow : Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Item {
        id: marker
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 13 * root.s
        height: 13 * root.s

        Rectangle {
            anchors.centerIn: parent
            visible: root.active
            width: 9 * root.s
            height: width
            radius: width / 2
            color: Theme.onGlow
        }

        GlyphIcon {
            anchors.fill: parent
            visible: root.opens
            name: "chevron-right"
            color: Theme.iconDim
            stroke: 2
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hairSoft
        visible: !root.last
    }
}
