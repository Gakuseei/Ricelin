pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import ".."
import "../Singletons"
import "pages.js" as Pages

/** Left page list in its four sections; `picked(id)` on click, `current` is lit. */
Item {
    id: root

    property real s: 1
    property string current: ""
    signal picked(string id)

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.hairSoft
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: 1
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        QQC.ScrollBar.vertical: AppScrollBar {
            s: root.s
        }

        Column {
            id: col
            x: 10 * root.s
            width: flick.width - 20 * root.s
            topPadding: 8 * root.s
            bottomPadding: 12 * root.s
            spacing: 1 * root.s

            Repeater {
                model: Pages.sections

                Column {
                    id: section
                    required property var modelData
                    required property int index
                    width: col.width
                    spacing: 1 * root.s

                    Text {
                        width: parent.width
                        topPadding: (section.index === 0 ? 6 : 14) * root.s
                        bottomPadding: 5 * root.s
                        leftPadding: 13 * root.s
                        text: section.modelData.title
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: section.modelData.pages

                        Rectangle {
                            id: item
                            required property string modelData
                            readonly property var meta: Pages.pages[modelData]
                            readonly property bool on: root.current === modelData
                            width: section.width
                            height: 32 * root.s
                            radius: 9 * root.s
                            color: item.on ? Theme.frameBg : (itemArea.containsMouse ? Qt.alpha(Theme.cream, 0.035) : "transparent")
                            border.width: item.activeFocus ? 2 * root.s : 0
                            border.color: Qt.alpha(Theme.vermLit, 0.6)
                            activeFocusOnTab: true
                            Keys.onSpacePressed: root.picked(item.modelData)
                            Keys.onReturnPressed: root.picked(item.modelData)

                            Rectangle {
                                visible: item.on
                                x: 0
                                y: 9 * root.s
                                width: 3 * root.s
                                height: parent.height - 18 * root.s
                                radius: width / 2
                                color: Theme.vermLit
                            }

                            GlyphIcon {
                                id: ic
                                x: 13 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16 * root.s
                                height: width
                                name: item.meta.icon
                                color: item.on ? Theme.cream : (itemArea.containsMouse ? Theme.iconDim : Theme.textFaint)
                            }

                            Text {
                                anchors.left: ic.right
                                anchors.leftMargin: 11 * root.s
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: item.meta.name
                                elide: Text.ElideRight
                                color: item.on || itemArea.containsMouse ? Theme.cream : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 13 * root.s
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.picked(item.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
