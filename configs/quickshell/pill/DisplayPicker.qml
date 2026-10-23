pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Dropdown settings line: a SettingsRow with a value chip, and an option list that snaps open under the chip so the pill body's morph reveals it.
 */
Column {
    id: pick

    property var surface: null
    property string icon: ""
    property string name: ""
    property string sub: ""
    property bool last: false
    property var options: []
    property var value
    property bool open: false
    property real chipWidth: 112
    signal picked(var value)
    signal requestToggle()

    readonly property alias row: row
    readonly property real s: surface ? surface.s : 1
    readonly property real chipW: chipWidth * s
    readonly property real optH: 24 * s
    readonly property real listH: Math.min(options.length * optH + 2 * Theme.sp.xxs * s, 150 * s)

    readonly property int currentIndex: {
        for (var i = 0; i < options.length; i++)
            if (options[i].value === value)
                return i;
        return -1;
    }
    readonly property string currentLabel: currentIndex >= 0 ? options[currentIndex].label : (options.length ? options[0].label : "")

    width: parent ? parent.width : 0

    onOpenChanged: if (open && currentIndex >= 0) Qt.callLater(() => list.positionViewAtIndex(pick.currentIndex, ListView.Center))

    SettingsRow {
        id: row
        surface: pick.surface
        icon: pick.icon
        name: pick.name
        sub: pick.sub
        last: pick.last && !pick.open

        Rectangle {
            id: chip
            width: pick.chipW
            height: 26 * pick.s
            radius: Theme.r.m * pick.s
            color: pick.open ? Qt.alpha(Theme.onGlow, 0.14)
                : (chipArea.pressed ? Theme.pressBg : (chipArea.containsMouse ? Theme.frameBg : "transparent"))
            border.width: 1
            border.color: pick.open ? Qt.alpha(Theme.onGlow, 0.5) : (chipArea.containsMouse ? Theme.frameBorder : Theme.hairSoft)
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

            DisplayLabel {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp.s * pick.s
                anchors.verticalCenter: parent.verticalCenter
                s: pick.s
                text: pick.currentLabel
                color: Theme.cream
                weight: Font.DemiBold
                maxWidth: chip.width - (2 * Theme.sp.s + Theme.sp.xs + 13) * pick.s
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp.s * pick.s
                anchors.verticalCenter: parent.verticalCenter
                width: 13 * pick.s
                height: 13 * pick.s
                name: "chevron-down"
                rotation: pick.open ? 180 : 0
                color: pick.open || chipArea.containsMouse ? Theme.cream : Theme.iconDim
                stroke: 2
                Behavior on rotation { enabled: !Motion.calm; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pick.requestToggle()
            }
        }
    }

    Item {
        width: parent.width
        height: pick.open ? pick.listH + Theme.sp.s * pick.s : 0
        visible: pick.open

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp.m * pick.s
            width: pick.chipW
            height: pick.listH
            radius: Theme.r.m * pick.s
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.frameBorder

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Theme.sp.xxs * pick.s
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: pick.options

                delegate: Rectangle {
                    id: optRow
                    required property var modelData
                    readonly property bool current: pick.value === modelData.value

                    width: ListView.view.width
                    height: pick.optH
                    radius: Theme.r.s * pick.s
                    color: optArea.pressed ? Theme.pressBg
                        : (optArea.containsMouse ? Theme.frameBg : (optRow.current ? Qt.alpha(Theme.onGlow, 0.16) : "transparent"))

                    DisplayLabel {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp.s * pick.s
                        anchors.verticalCenter: parent.verticalCenter
                        s: pick.s
                        text: optRow.modelData.label
                        color: optRow.current ? Theme.cream : Theme.subtle
                        weight: optRow.current ? Font.Bold : Font.Medium
                        maxWidth: optRow.width - 2 * Theme.sp.s * pick.s
                    }

                    MouseArea {
                        id: optArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pick.picked(optRow.modelData.value)
                    }
                }
            }

            WheelScroller {
                anchors.fill: list
                s: pick.s
                flick: list
            }
        }
    }
}
