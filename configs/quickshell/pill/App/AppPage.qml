import QtQuick
import ".."
import "../Singletons"
import "pages.js" as Pages
import "app.js" as App

/** Base of every page: `pageId` fills title, kanji, icon, desc and wantsPreview from pages.js; optional `tabs` and `currentTab`; override `reset()`, and `reveal(key)` scrolls to, opens and flashes the AppRow with that key. */
Item {
    id: page

    property real s: App.shell ? App.shell.s : 1
    property string pageId: ""
    readonly property var meta: Pages.pages[pageId] || ({})
    property string title: meta.name || ""
    property string kanji: meta.kanji || ""
    property string icon: meta.icon || "cog"
    property string desc: meta.desc || ""
    property bool wantsPreview: meta.preview === true
    /** Stage pill to bring forward, "idle" or "hover"; empty keeps both even. */
    property string stageEmphasis: ""
    property var tabs: []
    property string currentTab: tabs && tabs.length > 0 ? tabs[0] : ""
    property bool resettable: true
    default property alias content: body.data

    readonly property bool isAppPage: true
    readonly property bool hasTabs: !!tabs && tabs.length > 0
    readonly property alias stage: stageItem
    property var rowMap: ({})

    /** Pages override this to put their settings back to the shipped defaults. */
    function reset() {
    }

    /** The inline form open on this page, if any; a press outside it asks `cancel(true)`. */
    property Item activeForm: null

    /** Pages with inline forms override this: Esc asks with `outside` false, a press beside the form with true. True when a form closed. */
    function cancel(outside) {
        return false;
    }

    function registerRow(key, item) {
        rowMap[key] = item;
    }

    function unregisterRow(key, item) {
        if (rowMap[key] === item)
            delete rowMap[key];
    }

    /** Switches tab, opens More options and scrolls to the row; a row another setting hides lands on its group. */
    function reveal(key) {
        const row = rowMap[key];
        if (!row)
            return false;
        const g = row.group;
        if (g && g.tab.length > 0 && g.tab !== currentTab)
            currentTab = g.tab;
        if (g && row.advanced && !g.showMore)
            g.expandNow();
        if (App.shell)
            App.shell.scrollToItem(row.visible || !g ? row : g, row.visible);
        return true;
    }

    width: parent ? parent.width : implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width

        Item {
            id: banner
            width: parent.width
            height: 20 * page.s + Math.max(30 * page.s, textFlow.implicitHeight)

            Item {
                id: mark
                x: 12 * page.s
                y: 20 * page.s + (parent.height - 20 * page.s - height) / 2
                width: 30 * page.s
                height: width

                Text {
                    anchors.centerIn: parent
                    visible: Flags.showGlyphs && page.kanji.length > 0
                    text: page.kanji
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 23 * page.s
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !Flags.showGlyphs || page.kanji.length === 0
                    width: 22 * page.s
                    height: width
                    name: page.icon
                    color: Theme.cream
                    stroke: 1.7
                }
            }

            Flow {
                id: textFlow
                anchors.left: mark.right
                anchors.leftMargin: 12 * page.s
                anchors.right: resetLink.left
                anchors.rightMargin: 12 * page.s
                y: 20 * page.s + (parent.height - 20 * page.s - height) / 2
                spacing: 12 * page.s

                Text {
                    id: titleText
                    text: page.title
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 18 * page.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.2 * page.s
                }
                Text {
                    height: titleText.height
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 2 * page.s
                    text: page.desc
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12.5 * page.s
                }
            }

            Rectangle {
                id: resetLink
                anchors.right: parent.right
                anchors.rightMargin: 8 * page.s
                y: mark.y + (mark.height - height) / 2
                visible: page.resettable
                width: visible ? resetText.implicitWidth + 16 * page.s : 0
                height: 24 * page.s
                radius: 7 * page.s
                color: resetArea.containsMouse ? Theme.frameBg : "transparent"
                border.width: activeFocus ? 2 * page.s : 0
                border.color: Qt.alpha(Theme.vermLit, 0.6)
                activeFocusOnTab: visible
                Keys.onSpacePressed: page.resetNow()
                Keys.onReturnPressed: page.resetNow()

                Text {
                    id: resetText
                    anchors.centerIn: parent
                    text: "Reset to default"
                    color: resetArea.containsMouse ? Theme.cream : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12 * page.s
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.resetNow()
                }
            }
        }

        AppStage {
            id: stageItem
            width: parent.width
            visible: page.wantsPreview
            height: visible ? implicitHeight : 0
            s: page.s
            emphasis: page.stageEmphasis
        }

        Item {
            width: parent.width
            height: page.hasTabs ? tabsItem.height + 16 * page.s : 0
            visible: page.hasTabs

            AppTabs {
                id: tabsItem
                y: 16 * page.s
                width: parent.width
                s: page.s
                tabs: page.tabs
                current: page.currentTab
                onPicked: (label) => page.currentTab = label
            }
        }

        Column {
            id: body
            width: parent.width
        }
    }

    function resetNow() {
        page.reset();
        App.toast(page.title + " is back to default");
    }
}
