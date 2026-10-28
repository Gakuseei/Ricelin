pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "app.js" as App

/** Underlined tabs over `tabs` (labels); `current` is the shown one, `picked(label)` on click or Left/Right. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property var tabs: []
    property string current: ""
    signal picked(string label)

    readonly property int currentIndex: (tabs || []).indexOf(current)
    readonly property Item curItem: {
        void row.implicitWidth;
        return currentIndex >= 0 ? rep.itemAt(currentIndex) : null;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 40 * s
    activeFocusOnTab: true

    Keys.onLeftPressed: if (currentIndex > 0) picked(tabs[currentIndex - 1])
    Keys.onRightPressed: if (currentIndex >= 0 && currentIndex < tabs.length - 1) picked(tabs[currentIndex + 1])

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.hairSoft
    }

    Row {
        id: row
        x: 4 * root.s
        height: parent.height
        spacing: 2 * root.s

        Repeater {
            id: rep
            model: root.tabs

            Item {
                id: tab
                required property string modelData
                required property int index
                readonly property bool on: root.currentIndex === index
                width: tabText.implicitWidth + 24 * root.s
                height: row.height

                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 4 * root.s
                    anchors.topMargin: 2 * root.s
                    radius: 7 * root.s
                    color: "transparent"
                    border.width: root.activeFocus && tab.on ? 2 * root.s : 0
                    border.color: Qt.alpha(Theme.vermLit, 0.6)
                }

                Text {
                    id: tabText
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1 * root.s
                    text: tab.modelData
                    color: tab.on || tabArea.containsMouse ? Theme.cream : Theme.subtle
                    Behavior on color { ColorAnimation { duration: 120 } }
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!tab.on) root.picked(tab.modelData)
                }
            }
        }
    }

    Rectangle {
        visible: root.curItem !== null
        x: row.x + lineX.value + 12 * root.s
        width: Math.max(0, lineW.value - 24 * root.s)
        height: 2 * root.s
        radius: height / 2
        anchors.bottom: parent.bottom
        color: Theme.vermLit
    }
    Spring {
        id: lineX
        target: root.curItem ? root.curItem.x : 0
        response: 0.3
    }
    Spring {
        id: lineW
        target: root.curItem ? root.curItem.width : 0
        response: 0.3
    }
    Component.onCompleted: Qt.callLater(() => {
        lineX.snap(lineX.target);
        lineW.snap(lineW.target);
    })
}
