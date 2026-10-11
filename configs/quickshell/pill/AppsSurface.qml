pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

PillSurface {
    id: root

    mTop: 16; mLeft: 19; mRight: 19; mBottom: 16
    implicitHeight: content.implicitHeight

    property string category: "game"
    property string viewState: "list"
    property string selectedId: ""
    readonly property var selectedApp: AppRegistry.byId(root.selectedId)

    onOpenChanged: if (!open) { root.viewState = "list"; root.selectedId = ""; }
    onSelectedAppChanged: if (!root.selectedApp && root.viewState !== "list" && root.viewState !== "add" && root.viewState !== "scan") root.viewState = "list";
    readonly property bool wantsSysmon: root.open && root.viewState === "detail"
    onWantsSysmonChanged: Sysmon.open = root.wantsSysmon

    function openDetail(id) { root.selectedId = id; root.viewState = "detail"; }
    function selectRelative(delta) {
        if (appsList.count === 0) return;
        var next = Math.max(0, Math.min(appsList.count - 1, appsList.currentIndex + delta));
        appsList.currentIndex = next;
        appsList.positionViewAtIndex(next, ListView.Contain);
    }
    function changeCategory(delta) {
        var cats = AppRegistry.categories;
        var idx = cats.findIndex(c => c.id === root.category);
        if (idx < 0) idx = 0;
        idx = Math.max(0, Math.min(cats.length - 1, idx + delta));
        root.category = cats[idx].id;
        appsList.currentIndex = AppRegistry.countFor(root.category) > 0 ? 0 : -1;
    }

    Column {
        id: content
        width: parent.width
        spacing: 0

        Item {
           width: parent.width
           height: visible ? 24 * root.s : 0
           visible: root.viewState === "list"
           Text {
               anchors.left: parent.left
               anchors.verticalCenter: parent.verticalCenter
               text: AppRegistry.categoryLabel(root.category)
               color: Theme.cream
               font.family: Theme.font
               font.pixelSize: 13 * root.s
               font.weight: Font.Bold
           }
            Row {
           anchors.right: parent.right
           anchors.verticalCenter: parent.verticalCenter
           spacing: 4 * root.s
               Rectangle {
                   width: 26 * root.s
                   height: 26 * root.s
                   radius: 8 * root.s
                   color: scanArea.containsMouse ? Theme.frameBg : "transparent"

                   GlyphIcon {
                       anchors.centerIn: parent
                       width: 14 * root.s
                       height: 14 * root.s
                       name: "download"
                       color: scanArea.containsMouse ? Theme.cream : Theme.iconDim
                       stroke: 1.8
                   }

                   MouseArea {
                       id: scanArea
                       anchors.fill: parent
                       hoverEnabled: true
                       cursorShape: Qt.PointingHandCursor
                       onClicked: root.viewState = "scan"
                   }
               }
               Rectangle {
                   width: 26 * root.s
                   height: 26 * root.s
                   radius: 8 * root.s
                   color: addArea.containsMouse ? Theme.frameBg : "transparent"

                   Text {
                       anchors.centerIn: parent
                       text: "+"
                       color: addArea.containsMouse ? Theme.cream : Theme.iconDim
                       font.pixelSize: 17 * root.s
                       font.weight: Font.Medium
                   }

                   MouseArea {
                       id: addArea
                       anchors.fill: parent
                       hoverEnabled: true
                       cursorShape: Qt.PointingHandCursor
                       onClicked: root.viewState = "add"
                   }
               }
            }
        }

       Item {
           width: 1
           height: visible ? 12 * root.s : 0
           visible: root.viewState === "list"
       }
        SettingsSeg {
           width: parent.width
           visible: root.viewState === "list"
           s: root.s
            options: [ { label: "Games", value: "game" }, { label: "Dev", value: "development" }, { label: "Eng", value: "engineering" }, { label: "Tools", value: "utility" } ]
            value: root.category
            onPicked: (v) => { root.category = v; appsList.currentIndex = AppRegistry.countFor(v) > 0 ? 0 : -1; }
        }
        Item { width: 1; height: visible ? 10 * root.s : 0; visible: root.viewState === "list" }
       Text {
           width: parent.width
           visible: root.viewState === "list" && AppRegistry.ready && appsList.count === 0
           wrapMode: Text.WordWrap
           text: "Nothing here yet. Use + to add an application, or Scan to discover installed ones."
           color: Theme.faint
           font.family: Theme.font
           font.pixelSize: 11 * root.s
           lineHeight: 1.3
       }

        ListView {
            id: appsList
            width: parent.width
            visible: root.viewState === "list" && count > 0
            height: Math.min(contentHeight, 360 * root.s)
            implicitHeight: visible ? height : 0
            clip: true
            focus: visible
            activeFocusOnTab: true
            keyNavigationEnabled: true
            keyNavigationWraps: false
            model: visible ? AppRegistry.appsFor(root.category) : []
            onVisibleChanged: if (visible) { if (currentIndex < 0 && count > 0) currentIndex = 0; forceActiveFocus(); }
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) { root.selectRelative(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Down) { root.selectRelative(1); event.accepted = true; }
                else if (event.key === Qt.Key_Left) { root.changeCategory(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Right) { root.changeCategory(1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (currentIndex >= 0 && currentIndex < count) root.openDetail(model[currentIndex].id); event.accepted = true; }
            }
            delegate: AppTile {
                required property var modelData
                required property int index
                app: modelData
               s: root.s
               revealIndex: index
                last: index === AppRegistry.appsFor(root.category).length - 1
                selected: index === appsList.currentIndex
                running: AppLauncher.isRunning(modelData.id)
                onActivated: {
                   appsList.currentIndex = index
                   root.openDetail(modelData.id)
               }
                onFavoriteToggled: AppRegistry.toggleFavorite(modelData.id)
            }
        }

       Text {
           width: parent.width
           visible: root.viewState === "list" && appsList.count > 0
           text: "↑ ↓ navigate · ← → category · Enter open"
           color: Theme.faint
           font.family: Theme.font
           font.pixelSize: 9.5 * root.s
           horizontalAlignment: Text.AlignRight
           topPadding: 5 * root.s
       }

       AppDetailView {
           width: parent.width
           visible: root.viewState === "detail" && root.selectedApp !== null

           app: root.selectedApp || AppRegistry.template()
           s: root.s
           running: AppLauncher.isRunning(root.selectedId)
           pid: AppLauncher.pidFor(root.selectedId)
           startedAt: AppLauncher.startedAt(root.selectedId)

           onBack: root.viewState = "list"
           onEditRequested: root.viewState = "editor"
           onLaunch: AppLauncher.launch(root.selectedId)
           onStop: AppLauncher.stop(root.selectedId)
           onForceStop: AppLauncher.forceStop(root.selectedId)

           onRestart: {
               AppLauncher.stop(root.selectedId)
               restartTimer.start()
           }

           onToggleFullscreen: AppRegistry.update(root.selectedId, {
               window: Object.assign({}, root.selectedApp.window, {
                   mode: root.selectedApp.window.mode === "fullscreen" ? "windowed" : "fullscreen"
               })
           })

           Timer {
               id: restartTimer
               interval: 900
               onTriggered: AppLauncher.launch(root.selectedId)
           }
       }
       AppEditor {
           width: parent.width
           visible: root.viewState === "editor" && root.selectedApp !== null
           app: root.selectedApp || AppRegistry.template()
           s: root.s
           onBack: root.viewState = root.selectedApp ? "detail" : "list"
       }
       AddApplicationSheet {
           width: parent.width
           visible: root.viewState === "add"
           s: root.s
           onCancelled: root.viewState = "list"
           onAdded: (id) => {
               root.category = (AppRegistry.byId(id) || {}).category || root.category
               root.openDetail(id)
           }
       }
        ScanApplicationsSheet { width: parent.width; visible: root.viewState === "scan"; s: root.s; onBack: root.viewState = "list"; onImported: (n) => root.viewState = "list" }
    }
}
