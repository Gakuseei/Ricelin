pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * What to record: Screen or Window / Region, then a monitor when there are several; shared by the recorder and quick record.
 */
Item {
    id: chooser

    property real s: 1
    property string screenName: ""
    property bool screens: false
    property real tileRadius: Theme.r.m * s

    signal wantScreens()
    signal resolved()
    signal back()

    function choose(kind) {
        if (kind === "screen" && ScreenRec.monitors.length > 1) {
            wantScreens();
            return;
        }
        if (kind === "screen")
            ScreenRec.prepareScreen(screenName);
        else
            ScreenRec.prepareWindow();
        resolved();
    }

    function pick(name) {
        resolved();
        ScreenRec.prepareScreen(name);
    }

    Row {
        id: sources
        anchors.fill: parent
        visible: !chooser.screens
        spacing: Theme.sp.xs * chooser.s

        Repeater {
            model: [
                { kind: "screen", label: "Screen", glyph: "monitor" },
                { kind: "window", label: "Window / Region", glyph: "video" }
            ]

            Rectangle {
                id: srcTile
                required property var modelData
                width: (sources.width - sources.spacing) / 2
                height: sources.height
                radius: chooser.tileRadius
                color: srcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                border.width: 1
                border.color: srcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                scale: srcArea.pressed && !Motion.calm ? 0.97 : 1
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.sp.s * chooser.s

                    GlyphIcon {
                        width: 16 * chooser.s
                        height: 16 * chooser.s
                        name: srcTile.modelData.glyph
                        color: srcArea.containsMouse ? Theme.vermLit : Theme.iconDim
                        stroke: 1.7
                    }
                    Text {
                        height: 16 * chooser.s
                        verticalAlignment: Text.AlignVCenter
                        text: srcTile.modelData.label
                        color: srcArea.containsMouse ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * chooser.s
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: srcArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chooser.choose(srcTile.modelData.kind)
                }
            }
        }
    }

    ListView {
        id: monList
        anchors.fill: parent
        anchors.rightMargin: 22 * chooser.s
        visible: chooser.screens
        orientation: ListView.Horizontal
        spacing: Theme.sp.xs * chooser.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: chooser.screens ? ScreenRec.screenTargets : []

        delegate: Rectangle {
            id: monTile
            required property var modelData
            width: 152 * chooser.s
            height: monList.height
            radius: chooser.tileRadius
            color: monArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
            border.width: 1
            border.color: monArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
            scale: monArea.pressed && !Motion.calm ? 0.97 : 1
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: Theme.sp.xxs * chooser.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: monTile.modelData.title
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * chooser.s
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: monTile.modelData.detail
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * chooser.s
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: monArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chooser.pick(monTile.modelData.name)
            }
        }
    }

    WheelScroller {
        anchors.fill: monList
        visible: chooser.screens
        flick: monList
        s: chooser.s
    }

    GlyphIcon {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.sp.xs * chooser.s
        visible: chooser.screens
        width: 12 * chooser.s
        height: 12 * chooser.s
        name: "chevron-left"
        color: backArea.containsMouse ? Theme.cream : Theme.textFaint
        stroke: 2
        scale: backArea.pressed && !Motion.calm ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        MouseArea {
            id: backArea
            anchors.fill: parent
            anchors.margins: -Theme.sp.s * chooser.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chooser.back()
        }
    }
}
