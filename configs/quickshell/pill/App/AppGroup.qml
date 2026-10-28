import QtQuick
import ".."
import "../Singletons"
import "app.js" as App

/** Rows under a small `title` and `hint`; rows listed in `advanced` wait behind a quiet "More options", `tab` shows the group only on that page tab. */
Item {
    id: group

    property real s: App.shell ? App.shell.s : 1
    property string title: ""
    property string hint: ""
    property string tab: ""
    property bool showMore: false
    default property alias rows: main.data
    property alias advanced: more.data

    readonly property bool isAppGroup: true
    property Item page: null
    readonly property bool hasMore: more.children.length > 0
    property bool instant: false

    function expandNow() {
        instant = true;
        showMore = true;
        Qt.callLater(() => group.instant = false);
    }

    function attach() {
        let p = group.parent;
        while (p && p.isAppPage !== true)
            p = p.parent;
        page = p;
    }
    Component.onCompleted: attach()
    onParentChanged: if (parent) attach()

    visible: tab.length === 0 || !page || page.currentTab === tab
    width: parent ? parent.width : implicitWidth
    implicitWidth: 400 * s
    implicitHeight: visible ? col.implicitHeight : 0

    Column {
        id: col
        width: parent.width
        topPadding: 24 * group.s

        Item {
            width: parent.width
            height: group.title.length > 0 || group.hint.length > 0 ? head.implicitHeight + 6 * group.s : 0
            visible: height > 0

            Row {
                id: head
                x: 12 * group.s
                width: parent.width - 24 * group.s
                spacing: 10 * group.s

                Text {
                    id: titleText
                    visible: text.length > 0
                    text: group.title
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12 * group.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: titleText.visible ? titleText.baseline : undefined
                    width: Math.max(0, head.width - (titleText.visible ? titleText.width + head.spacing : 0))
                    visible: text.length > 0
                    text: group.hint
                    color: Theme.textFaint
                    opacity: 0.85
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11.5 * group.s
                }
            }
        }

        Column {
            id: main
            width: parent.width
        }

        Item {
            id: moreWrap
            width: parent.width
            height: group.showMore ? more.implicitHeight : 0
            clip: heightAnim.running
            visible: height > 0
            Behavior on height {
                enabled: !group.instant && !Motion.calm
                NumberAnimation { id: heightAnim; duration: 240; easing.type: Easing.OutCubic }
            }

            Column {
                id: more
                property bool isAdvancedColumn: true
                width: parent.width
                opacity: group.showMore ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * group.s
                anchors.rightMargin: 12 * group.s
                height: 1
                color: Theme.hairSoft
                visible: main.children.length > 0
            }
        }

        Item {
            width: parent.width
            height: group.hasMore ? moreBtn.height + 8 * group.s : 0
            visible: group.hasMore

            Rectangle {
                id: moreBtn
                x: 12 * group.s
                y: 6 * group.s
                width: moreRow.implicitWidth + 14 * group.s
                height: 26 * group.s
                radius: 7 * group.s
                color: moreArea.containsMouse ? Theme.frameBg : "transparent"
                border.width: moreBtn.activeFocus ? 2 * group.s : 0
                border.color: Qt.alpha(Theme.vermLit, 0.6)
                activeFocusOnTab: true
                Keys.onSpacePressed: group.showMore = !group.showMore
                Keys.onReturnPressed: group.showMore = !group.showMore

                Row {
                    id: moreRow
                    anchors.centerIn: parent
                    spacing: 6 * group.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * group.s
                        height: width
                        name: "chevron-down"
                        stroke: 2
                        color: moreArea.containsMouse ? Theme.cream : Theme.textFaint
                        rotation: group.showMore ? 180 : 0
                        Behavior on rotation { enabled: !Motion.calm; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.showMore ? "Fewer options" : "More options"
                        color: moreArea.containsMouse ? Theme.cream : Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 12 * group.s
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: group.showMore = !group.showMore
                }
            }
        }
    }
}
