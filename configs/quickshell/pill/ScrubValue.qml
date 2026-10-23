pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Numeric value: drag to scrub, click the − / + end to step, wheel to step; every path snaps to `from..to` on the `step` grid.
 */
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""
    property real s: 1
    signal edited(real value)

    /**
     * Optional value-to-text mapper; when set it owns the label and the unit steps aside.
     */
    property var fmt: null

    /**
     * Value captured when the tab opened; the undo glyph shows while the live value differs.
     */
    property var openValue: undefined
    readonly property bool dirty: openValue !== undefined && !isNaN(openValue) && root.value !== openValue

    readonly property bool hovered: hh.hovered || scrub.containsMouse || scrub.pressed || undoMA.containsMouse
    readonly property real pxPerStep: 8 * root.s

    readonly property bool overMinus: scrub.containsMouse && scrub.mouseX < width * 0.4
    readonly property bool overPlus: scrub.containsMouse && scrub.mouseX > width * 0.6

    HoverHandler { id: hh }

    implicitWidth: Math.max(64 * root.s, content.implicitWidth + Theme.sp.m * root.s)
    implicitHeight: content.implicitHeight + Theme.sp.s * root.s

    function snap(v) {
        var n = root.from + Math.round((v - root.from) / root.step) * root.step;
        n = Math.max(root.from, Math.min(root.to, n));
        var p = Math.pow(10, root.decimals);
        return Math.round(n * p) / p;
    }

    function bump(dir) {
        var n = snap(root.value + dir * root.step);
        if (n !== root.value)
            root.edited(n);
    }

    Keys.onLeftPressed: bump(-1)
    Keys.onRightPressed: bump(1)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        radius: Theme.r.s * root.s
        color: Qt.alpha(Theme.onGlow, scrub.pressed ? 0.24 : (root.hovered ? 0.14 : 0))
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: scrub
        anchors.fill: parent
        anchors.leftMargin: -Theme.sp.m * root.s
        anchors.rightMargin: -Theme.sp.m * root.s
        anchors.topMargin: -Theme.sp.xs * root.s
        anchors.bottomMargin: -Theme.sp.xs * root.s
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeHorCursor

        property real pressX: 0
        property real pressVal: 0
        property bool dragged: false

        onPressed: mouse => {
            pressX = mouse.x;
            pressVal = root.value;
            dragged = false;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            if (Math.abs(mouse.x - pressX) > 3 * root.s)
                dragged = true;
            if (!dragged)
                return;
            var steps = Math.round((mouse.x - pressX) / root.pxPerStep);
            var cand = root.snap(pressVal + steps * root.step);
            if (cand !== root.value)
                root.edited(cand);
        }
        onClicked: mouse => {
            if (dragged)
                return;
            if (mouse.x < width * 0.4)
                root.bump(-1);
            else if (mouse.x > width * 0.6)
                root.bump(1);
        }
    }

    /**
     * Button-less wheel bridge: WheelHandler is unreliable on this layer-shell, and touchpad deltas add up to whole notches.
     */
    MouseArea {
        anchors.fill: scrub
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.SizeHorCursor
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0) {
                var cand = root.snap(root.value + notches * root.step);
                if (cand !== root.value)
                    root.edited(cand);
                acc -= notches;
            }
            event.accepted = true;
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.sp.xs * root.s

        GlyphIcon {
            id: undoG
            anchors.verticalCenter: parent.verticalCenter
            name: "undo"
            height: 14 * root.s
            width: root.dirty ? 14 * root.s : 0
            opacity: root.dirty ? 1 : 0
            clip: true
            stroke: 1.9
            color: undoMA.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.55)
            Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

            MouseArea {
                id: undoMA
                anchors.fill: parent
                anchors.margins: -6 * root.s
                enabled: root.dirty
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.edited(root.openValue)
            }
        }

        Text {
            id: minusG
            anchors.verticalCenter: parent.verticalCenter
            text: "−"
            opacity: root.hovered ? 1 : 0
            color: root.overMinus ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
            font.family: Theme.font
            font.pixelSize: Theme.fs.title * root.s
            font.weight: Font.Medium
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        Item {
            id: valueWrap
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(28 * root.s, vrow.implicitWidth)
            implicitHeight: vrow.implicitHeight

            Row {
                id: vrow
                anchors.centerIn: parent
                spacing: Theme.sp.xxs * root.s

                Text {
                    id: numText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmt ? root.fmt(root.value) : root.value.toFixed(root.decimals)
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.verticalCenter: numText.verticalCenter
                    visible: !root.fmt && root.unit.length > 0
                    text: root.unit
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.Medium
                }
            }
        }

        Text {
            id: plusG
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            opacity: root.hovered ? 1 : 0
            color: root.overPlus ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
            font.family: Theme.font
            font.pixelSize: Theme.fs.title * root.s
            font.weight: Font.Medium
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }
    }
}
