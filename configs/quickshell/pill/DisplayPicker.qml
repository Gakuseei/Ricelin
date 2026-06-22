pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * Labelled dropdown for the display surface: a left caption, a value chip styled
 * like the segmented control's pill, and an inset panel that grows below when open.
 * The panel snaps to its open size and contributes that to implicitHeight at once,
 * so the pill body's height Behavior is the only animator: the body morph alone
 * reveals the panel, and the surface clips anything past the body's current bottom,
 * so an opaque panel rectangle can never paint outside the still-growing body.
 * Picking emits picked(value) and the parent closes it; tapping the chip emits
 * requestToggle so the surface keeps only one dropdown open at a time. Resolution
 * labels carry a "×" the picker renders as a smaller, dimmer separator in the shell
 * font, so the digits never shift to a fallback face.
 */
Item {
    id: pick

    property real s: 1
    property string label: ""
    property var options: []
    property var value
    property bool open: false
    signal picked(var value)
    signal requestToggle()

    readonly property string currentLabel: {
        for (var i = 0; i < options.length; i++)
            if (options[i].value === value)
                return options[i].label;
        return options.length ? options[0].label : "";
    }

    readonly property real rowH: 26 * pick.s
    readonly property real gap: 4 * pick.s
    readonly property real listH: pick.open ? Math.min(options.length * 24 * pick.s + 4 * pick.s, 150 * pick.s) : 0

    width: parent ? parent.width : 0
    implicitHeight: pick.rowH + (pick.open ? pick.gap + pick.listH : 0)

    Row {
        id: head
        width: parent.width
        height: pick.rowH
        spacing: 8 * pick.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 64 * pick.s
            text: pick.label
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * pick.s
            font.weight: Font.Medium
        }

        Rectangle {
            id: field
            property bool hovered: false
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 72 * pick.s
            height: 24 * pick.s
            radius: 9 * pick.s
            color: pick.open ? Qt.alpha(Theme.onGlow, 0.14) : (field.hovered ? Theme.frameBg : "transparent")
            border.width: 1
            border.color: pick.open ? Qt.alpha(Theme.onGlow, 0.5) : Theme.hairSoft
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            DisplayLabel {
                anchors.left: parent.left
                anchors.leftMargin: 10 * pick.s
                anchors.verticalCenter: parent.verticalCenter
                s: pick.s
                text: pick.currentLabel
                color: Theme.cream
                weight: Font.DemiBold
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.rightMargin: 8 * pick.s
                anchors.verticalCenter: parent.verticalCenter
                width: 13 * pick.s
                height: 13 * pick.s
                name: pick.open ? "chevron-up" : "chevron-down"
                color: Theme.iconDim
                stroke: 2
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: field.hovered = true
                onExited: field.hovered = false
                onClicked: pick.requestToggle()
            }
        }
    }

    Rectangle {
        anchors.top: head.bottom
        anchors.topMargin: pick.open ? pick.gap : 0
        anchors.left: parent.left
        anchors.leftMargin: 72 * pick.s
        anchors.right: parent.right
        height: pick.listH
        visible: pick.open
        clip: true
        radius: 9 * pick.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.frameBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.6
            shadowVerticalOffset: 4 * pick.s
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 2 * pick.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: pick.options

            delegate: Rectangle {
                id: optRow
                required property var modelData
                readonly property bool current: pick.value === modelData.value

                width: ListView.view.width
                height: 24 * pick.s
                radius: 7 * pick.s
                color: optHover.hovered ? Theme.frameBg
                    : (optRow.current ? Qt.alpha(Theme.onGlow, 0.16) : "transparent")

                HoverHandler { id: optHover }

                DisplayLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: 9 * pick.s
                    anchors.verticalCenter: parent.verticalCenter
                    s: pick.s
                    text: optRow.modelData.label
                    color: optRow.current ? Theme.cream : Theme.subtle
                    weight: optRow.current ? Font.Bold : Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pick.picked(optRow.modelData.value)
                }
            }
        }
    }
}
