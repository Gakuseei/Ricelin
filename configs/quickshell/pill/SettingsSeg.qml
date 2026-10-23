pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Segmented choice over `{ label, value }` options; selection keys off `value`, never a child's visibility.
 */
Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    readonly property real pad: 1

    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: Theme.r.m * seg.s
    color: "transparent"

    readonly property Item curItem: {
        void pills.implicitWidth;
        const i = options.findIndex(o => o.value === seg.value);
        return i >= 0 ? rep.itemAt(i) : null;
    }

    /**
     * One lit thumb that glides to the picked option instead of each option lighting up on its own.
     */
    Rectangle {
        visible: seg.curItem !== null
        x: pills.x + thumbX.value
        y: pills.y
        width: thumbW.value
        height: pills.height
        radius: Theme.r.s * seg.s
        color: Qt.alpha(Theme.onGlow, 0.16)
    }
    Spring {
        id: thumbX
        target: seg.curItem ? seg.curItem.x : 0
        response: 0.25
    }
    Spring {
        id: thumbW
        target: seg.curItem ? seg.curItem.width : 0
        response: 0.25
    }
    Component.onCompleted: Qt.callLater(() => {
        thumbX.snap(thumbX.target);
        thumbW.snap(thumbW.target);
    })

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: Theme.sp.xxs * seg.s

        Repeater {
            id: rep
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value

                width: optLabel.implicitWidth + 2 * Theme.sp.s * seg.s
                height: optLabel.implicitHeight + Theme.sp.m * seg.s
                radius: Theme.r.s * seg.s
                color: optArea.pressed ? Theme.pressBg
                    : (!opt.current && optArea.containsMouse ? Theme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.current ? Theme.cream : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * seg.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.3 * seg.s
                }

                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
