pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "app.js" as App

/** Segmented choice over `options` (strings or { label, value }); `value` is the current one, `picked(value)` fires on click or Left/Right; `small` is the compact size. */
Rectangle {
    id: seg

    property real s: App.shell ? App.shell.s : 1
    property var options: []
    property var value
    property bool small: false
    signal picked(var value)

    readonly property var opts: (options || []).map(o => (o !== null && typeof o === "object") ? o : ({ label: String(o), value: o }))
    readonly property int currentIndex: opts.findIndex(o => o.value === seg.value)
    readonly property real inset: 2 * s
    readonly property real innerR: Math.max(2, radius - inset - border.width)

    implicitWidth: pills.implicitWidth + 2 * (inset + border.width)
    implicitHeight: pills.implicitHeight + 2 * (inset + border.width)
    radius: (small ? 8 : 9) * s
    color: Theme.frameBg
    border.width: 1
    border.color: seg.activeFocus ? Qt.alpha(Theme.vermLit, 0.6) : Theme.frameBorder
    activeFocusOnTab: true

    function step(dir) {
        if (opts.length === 0)
            return;
        const i = currentIndex < 0 ? 0 : currentIndex;
        const n = Math.max(0, Math.min(opts.length - 1, i + dir));
        if (n !== currentIndex)
            seg.picked(opts[n].value);
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)

    readonly property Item curItem: {
        void pills.implicitWidth;
        return currentIndex >= 0 ? rep.itemAt(currentIndex) : null;
    }

    /** One thumb glides to the picked option; its corners sit inside the outer ones by the inset. */
    Rectangle {
        visible: seg.curItem !== null
        x: pills.x + thumbX.value
        y: pills.y
        width: thumbW.value
        height: pills.height
        radius: seg.innerR
        color: Qt.alpha(Theme.onGlow, 0.16)
        border.width: 1
        border.color: Qt.alpha(Theme.onGlow, 0.12)
    }
    Spring {
        id: thumbX
        target: seg.curItem ? seg.curItem.x : 0
        response: 0.3
        damping: 0.82
    }
    Spring {
        id: thumbW
        target: seg.curItem ? seg.curItem.width : 0
        response: 0.3
        damping: 0.82
    }
    Component.onCompleted: Qt.callLater(() => {
        thumbX.snap(thumbX.target);
        thumbW.snap(thumbW.target);
    })

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 2 * seg.s

        Repeater {
            id: rep
            model: seg.opts

            Rectangle {
                id: opt
                required property var modelData
                required property int index
                readonly property bool current: seg.currentIndex === index

                width: optLabel.implicitWidth + 2 * (seg.small ? 9 : 10) * seg.s
                height: (seg.small ? 22 : 26) * seg.s
                radius: seg.innerR
                color: optArea.pressed && !opt.current ? Theme.pressBg
                    : (!opt.current && optArea.containsMouse ? Theme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.current || optArea.containsMouse ? Theme.cream : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    font.family: Theme.font
                    font.pixelSize: (seg.small ? 11.5 : 12) * seg.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!opt.current) seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
