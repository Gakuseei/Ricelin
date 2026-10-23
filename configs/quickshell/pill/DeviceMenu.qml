pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

/** Audio device dropdown shared by the mixer and the sound surface; the host anchors it and closes it on `pick`. */
Item {
    id: menu

    property real s: 1
    property bool open: false
    property var model: []
    property var current
    signal pick(var node)

    z: 7
    visible: opacity > 0.01
    enabled: open
    opacity: open ? 1 : 0
    scale: open || Motion.calm ? 1 : 0.97
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: menu.open ? 180 : 100; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    width: 300 * s
    height: panel.height

    /** The halo lives on a textless backing rect; a layer over the labels would rasterise and soften them. */
    Rectangle {
        anchors.fill: panel
        radius: panel.radius
        color: Theme.cardBot
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.6
            shadowVerticalOffset: 4 * menu.s
        }
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(menu.model.length * 24 * menu.s + 4 * menu.s, 150 * menu.s)
        clip: true
        radius: Theme.r.m * menu.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.frameBorder

        ListView {
            anchors.fill: parent
            anchors.margins: 2 * menu.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: menu.model

            delegate: Rectangle {
                id: devRow
                required property var modelData
                readonly property bool current: menu.current === modelData

                width: ListView.view.width
                height: 24 * menu.s
                radius: Theme.r.s * menu.s
                color: devPress.pressed ? Theme.pressBg
                    : devRowHover.hovered ? Theme.frameBg
                    : (devRow.current ? Qt.alpha(Theme.onGlow, 0.16) : "transparent")
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                HoverHandler { id: devRowHover }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.s * menu.s
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.s * menu.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sound.label(devRow.modelData)
                    elide: Text.ElideRight
                    color: devRow.current ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * menu.s
                    font.weight: devRow.current ? Font.Bold : Font.Medium
                }

                MouseArea {
                    id: devPress
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.pick(devRow.modelData)
                }
            }
        }
    }
}
