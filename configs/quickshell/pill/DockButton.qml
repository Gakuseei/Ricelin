pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * A glyph button in the dock: the status cluster (network, Bluetooth, battery,
 * notifications, sound and brightness, system stats) and the app grid.
 *
 * Like DockItem it only reports hover; the dock slides one lens under the item
 * the pointer is on. `caption` is a tiny value under the glyph (a battery
 * percentage), `badge` a dot for something unread.
 */
Item {
    id: root

    property string glyph: ""
    property color tint: Theme.iconDim
    property string title: ""
    property string desc: ""
    property string caption: ""
    property bool badge: false
    property real s: 1
    property real tile: 44 * s
    property real tileHeight: 36 * s
    /** The Wi-Fi arcs have their own drawing; `level` is 0..1, `on` the radio state. */
    property bool wifi: false
    property real wifiLevel: 0
    property bool wifiOn: true

    signal clicked()
    signal rightClicked()
    signal hoverChanged(bool on)

    readonly property bool hovered: area.containsMouse

    width: tile
    height: tileHeight

    Item {
        id: face
        anchors.centerIn: parent
        width: 21 * root.s
        height: width
        scale: area.pressed ? 0.88 : (area.containsMouse ? 1.14 : 1)
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

        GlyphIcon {
            anchors.fill: parent
            visible: !root.wifi
            name: root.glyph
            color: area.containsMouse ? Theme.bright : root.tint
            stroke: 1.7
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        WifiGlyph {
            anchors.fill: parent
            visible: root.wifi
            s: root.s
            level: root.wifiLevel
            on: root.wifiOn
            stroke: 1.7
        }
    }

    Text {
        visible: root.caption.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1 * root.s
        text: root.caption
        color: area.containsMouse ? Theme.bright : root.tint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    Rectangle {
        visible: root.badge
        x: face.x + face.width - 3 * root.s
        y: face.y - 2 * root.s
        width: 9 * root.s
        height: width
        radius: width / 2
        color: Theme.flameGlow
        border.width: 1
        border.color: Qt.alpha(Theme.cardBot, 0.7)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hoverChanged(containsMouse)
        onClicked: (e) => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
