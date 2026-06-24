pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Singletons"

PillSurface {
    id: sharingSurface

    mTop: 13
    mLeft: 12
    mRight: 12
    mBottom: 13

    property var store
    property bool draggingOut: false
    property string currentTab: "all"
    readonly property var filteredEntries: {
        if (!store) return [];
        var list = store.entries;
        if (currentTab === "files") {
            return list.filter(function(e) { return !e.isDir; });
        } else if (currentTab === "folders") {
            return list.filter(function(e) { return e.isDir; });
        }
        return list;
    }

    enabled: open || draggingOut
    visible: open || draggingOut

    implicitHeight: mainCol.implicitHeight
    clip: true

    HoverHandler {
        onHoveredChanged: {
            if (!hovered && sharingSurface.open) {
                sharingSurface.requestClose();
            }
        }
    }

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10 * sharingSurface.s

        Item {
            width: parent.width
            height: 28 * sharingSurface.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * sharingSurface.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "繋"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * sharingSurface.s
                }

                SettingsSeg {
                    s: sharingSurface.s
                    anchors.verticalCenter: parent.verticalCenter
                    options: [
                        { label: "ALL", value: "all" },
                        { label: "FILES", value: "files" },
                        { label: "FOLDERS", value: "folders" }
                    ]
                    value: sharingSurface.currentTab
                    onPicked: (val) => { sharingSurface.currentTab = val; }
                }
            }
            Item {
                id: clearBtn
                anchors.right: parent.right
                anchors.rightMargin: 12 * sharingSurface.s
                anchors.verticalCenter: parent.verticalCenter
                width: clearRow.implicitWidth
                height: clearRow.implicitHeight
                visible: sharingSurface.store && sharingSurface.store.entries.length > 0

                Row {
                    id: clearRow
                    spacing: 4 * sharingSurface.s
                    anchors.fill: parent

                    GlyphIcon {
                        width: 12 * sharingSurface.s
                        height: 12 * sharingSurface.s
                        name: "trash"
                        color: trashArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.6
                    }

                    Text {
                        text: "CLEAR"
                        color: trashArea.containsMouse ? Theme.cream : Theme.iconDim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * sharingSurface.s
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: trashArea
                    anchors.fill: parent
                    anchors.margins: -4 * sharingSurface.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sharingSurface.store) {
                            sharingSurface.store.clear();
                        }
                    }
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "close"
                color: closeArea.containsMouse ? Theme.cream : Theme.iconDim
                stroke: 1.8

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -6 * sharingSurface.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sharingSurface.requestClose()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Controls.ScrollView {
            id: scrollView
            width: parent.width
            height: Math.min(flowLayout.implicitHeight, 220 * sharingSurface.s)
            clip: true
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

            Flow {
                id: flowLayout
                anchors.horizontalCenter: parent.horizontalCenter
                width: {
                    var count = sharingSurface.filteredEntries.length;
                    var cols = Math.min(count, 3);
                    return cols > 0 ? (cols * 106 + (cols - 1) * 8) * sharingSurface.s : 0;
                }
                spacing: 8 * sharingSurface.s
                visible: sharingSurface.store && sharingSurface.filteredEntries.length > 0

                Repeater {
                    model: sharingSurface.filteredEntries

                    delegate: Item {
                        id: delegateItem
                        required property var modelData
                        width: 106 * sharingSurface.s
                        height: 66 * sharingSurface.s

                        property bool dragActive: false
                        Drag.active: dragActive
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: {
                            "text/uri-list": delegateItem.modelData ? [Qt.url(delegateItem.modelData.url)] : []
                        }
                        Drag.onDragFinished: {
                            delegateItem.dragActive = false;
                            sharingSurface.draggingOut = false;
                            sharingSurface.requestClose();
                        }

                        readonly property real hold: trashHeat.hold
                        readonly property bool committing: trashHeat.hold >= trashHeat.tapThreshold
                        readonly property real commitProgress: Math.max(0, (trashHeat.hold - trashHeat.tapThreshold) / (1 - trashHeat.tapThreshold))

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 10 * sharingSurface.s
                            color: Theme.tileBg

                            Image {
                                anchors.fill: parent
                                visible: !!(delegateItem.modelData && delegateItem.modelData.isImage)
                                source: (delegateItem.modelData && delegateItem.modelData.isImage) ? delegateItem.modelData.url : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 8 * sharingSurface.s
                                spacing: 4 * sharingSurface.s
                                visible: !delegateItem.modelData || !delegateItem.modelData.isImage

                                GlyphIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 20 * sharingSurface.s
                                    height: 20 * sharingSurface.s
                                    name: {
                                        if (!delegateItem.modelData) return "file";
                                        if (delegateItem.modelData.isDir) return "folder";
                                        if (delegateItem.modelData.isVideo) return "video";
                                        if (delegateItem.modelData.isMusic) return "music";
                                        return "file";
                                    }
                                    color: Theme.iconDim
                                    stroke: 1.6
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    text: delegateItem.modelData ? delegateItem.modelData.name : ""
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: 8.5 * sharingSurface.s
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Rectangle {
                                id: consume
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * delegateItem.commitProgress
                                visible: delegateItem.committing
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.alpha(Theme.vermBurn, 0.66) }
                                    GradientStop { position: 0.74; color: Qt.alpha(Theme.vermLit, 0.30) }
                                    GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 2 * sharingSurface.s
                                    opacity: Math.min(1, delegateItem.commitProgress * 3)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                                        GradientStop { position: 0.5; color: Theme.flameGlow }
                                        GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10 * sharingSurface.s
                            color: "transparent"
                            border.width: 1
                            border.color: delegateItem.committing ? Theme.vermLit : (hoverArea.containsMouse ? Theme.vermLit : Theme.border)
                            Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                            scale: hoverArea.containsMouse ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad } }
                        }

                        HeatHold {
                            id: trashHeat
                            tapThreshold: 0.25

                            onConfirmed: {
                                if (sharingSurface.store && delegateItem.modelData) {
                                    sharingSurface.store.deleteFile(delegateItem.modelData.path);
                                }
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            property point pressPos

                            onPressed: (mouse) => {
                                pressPos = Qt.point(mouse.x, mouse.y);
                                trashHeat.press();
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    var threshold = 10 * sharingSurface.s;
                                    if (Math.abs(mouse.x - pressPos.x) > threshold || Math.abs(mouse.y - pressPos.y) > threshold) {
                                        if (!delegateItem.dragActive) {
                                            trashHeat.cancel();
                                            sharingSurface.draggingOut = true;
                                            delegateItem.dragActive = true;
                                            delegateItem.Drag.startDrag();
                                        }
                                    }
                                }
                            }
                            onReleased: trashHeat.release()
                            onExited: trashHeat.cancel()
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !sharingSurface.store || sharingSurface.filteredEntries.length === 0
            text: "No files"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11 * sharingSurface.s
        }
    }
}
