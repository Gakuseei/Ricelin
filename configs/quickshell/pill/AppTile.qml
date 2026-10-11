pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * One row in the apps list: icon tile, name + category/launch-count subline,
 * a running dot, a favorite toggle and a chevron into AppDetailView. Same
 * 46-ish px row shape as SpaceApps' entries so the surface reads as one more
 * Ricelin list, not an imported widget.
 *
 * The icon tile's hover/press pop is the one deliberate borrow from Persona's
 * AppDrawer blades: everywhere else on the pill a hover just eases a color
 * (Motion.fast, OutCubic), but Persona's blades physically spring towards the
 * cursor (`SpringAnimation { spring: 3.5; damping: 0.3 }`). Games are the one
 * surface in Ricelin that's explicitly about play, so this tile borrows that
 * exact spring tuning for its icon — everything else on the row (the hover
 * backing, the hairline, the running dot) still eases on Motion's terms.
 */
Item {
    id: root

    required property var app
    property real s: 1
    property bool last: false
    property bool running: false
    property bool selected: false
    /** Set by the host Repeater's index to stagger this tile's entrance; 0 = no delay, appears immediately. */
    property int revealIndex: 0

    signal activated()
    signal favoriteToggled()

    width: parent ? parent.width : 0
    height: 50 * root.s
    opacity: 0
    transform: Translate { id: slideT; y: 6 }

    Component.onCompleted: revealAnim.start()
    SequentialAnimation {
        id: revealAnim
        PauseAnimation { duration: Math.min(root.revealIndex * 22, 260) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: slideT; property: "y"; from: 6; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    readonly property string initial: root.app.name.length > 0 ? root.app.name.charAt(0).toUpperCase() : "?"

    HoverHandler { id: rowHover }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3 * root.s
        anchors.bottomMargin: 3 * root.s
        radius: 10 * root.s
        color: root.selected ? Theme.threadBg : (rowHover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: root.selected ? Theme.hair : (rowHover.hovered ? Theme.frameBorder : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 34 * root.s
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
        border.color: Theme.hairSoft
        scale: tileArea.pressed ? 0.92 : (rowHover.hovered ? 1.08 : 1)
        Behavior on scale {
            SpringAnimation { spring: 3.5; damping: 0.3 }
        }

        Text {
            anchors.centerIn: parent
            visible: !(icon.status === Image.Ready && icon.source != "")
            text: root.initial
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            font.weight: Font.DemiBold
        }

        Image {
            id: icon
            anchors.fill: parent
            anchors.margins: 4 * root.s
            sourceSize.width: Math.round(40 * root.s)
            sourceSize.height: Math.round(40 * root.s)
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            smooth: true
            visible: status === Image.Ready && source != ""
            source: root.app.iconImage && root.app.iconImage.length > 0 ? "file://" + root.app.iconImage : ""
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }

        Rectangle {
            visible: root.running
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -1 * root.s
            width: 9 * root.s
            height: 9 * root.s
            radius: width / 2
            color: Theme.onGlow
            border.width: 1.5 * root.s
            border.color: Theme.cardBot
            SequentialAnimation on opacity {
                running: root.running
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: Motion.pulse; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
            }
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12 * root.s
        anchors.right: favBtn.left
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * root.s

        Text {
            width: parent.width
            text: root.app.name
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            readonly property string statusWord: root.running ? "Running" : (root.app.lastLaunched > 0 ? "Played" : "Never launched")
            width: parent.width
            text: AppRegistry.categoryLabel(root.app.category) + "  ·  " + statusWord
            color: root.running ? Theme.flameGlow : Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: favBtn
        anchors.right: chevron.left
        anchors.rightMargin: 2 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 26 * root.s
        height: 26 * root.s
        radius: 7 * root.s
        color: favArea.containsMouse ? Theme.frameBg : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            anchors.centerIn: parent
            width: 14 * root.s
            height: 14 * root.s
            name: "sparkles"
            color: root.app.favorite ? Theme.flameGlow : Theme.iconDim
            stroke: 1.8
        }

        MouseArea {
            id: favArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.favoriteToggled()
        }
    }

    GlyphIcon {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 13 * root.s
        height: 13 * root.s
        name: "chevron-right"
        color: Theme.iconDim
        stroke: 2
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
