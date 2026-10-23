pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"
import "lib/fuzzy.js" as Fuzzy

/**
 * Add-app bar that opens into the launcher's fuzzy picker; emits picked(entry) and hosts the class-to-app helpers.
 */
Column {
    id: picker

    property real s: 1
    property bool addOpen: false
    property string query: ""
    property int selectedIndex: 0
    property bool barLit: false

    readonly property real rowH: 40 * s
    readonly property real rowGap: Theme.sp.xs * s
    readonly property int maxRows: 5
    readonly property int shownRows: Math.min(results.length, maxRows)

    signal picked(var entry)

    spacing: 0

    readonly property var allApps: DesktopEntries.applications.values

    /** Comparable key for a class token: `[Ss]potify` and `Ghosttype-app` line up with StartupWMClass or id. */
    function normalizeClass(cls) {
        return String(cls)
            .replace(/\[(.)(.)\]/g, "$2")
            .toLowerCase()
            .replace(/[^a-z0-9]/g, "");
    }

    /** App behind a window class: exact normalized match first, else the longest 4+ char substring link (GhostType, not Ghostty). */
    function resolveEntry(cls) {
        var want = picker.normalizeClass(cls);
        if (want.length === 0)
            return null;
        var apps = picker.allApps;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (!e)
                continue;
            var cands = [e.startupClass, e.id, e.name];
            for (var j = 0; j < cands.length; j++)
                if (cands[j] && picker.normalizeClass(cands[j]) === want)
                    return e;
        }
        var best = null;
        var bestLen = 0;
        for (var k = 0; k < apps.length; k++) {
            var e2 = apps[k];
            if (!e2)
                continue;
            var cands2 = [e2.startupClass, e2.id, e2.name];
            for (var n = 0; n < cands2.length; n++) {
                if (!cands2[n])
                    continue;
                var got = picker.normalizeClass(cands2[n]);
                if (got.length < 4)
                    continue;
                var hit = (want.length >= 4 && got.indexOf(want) !== -1) || want.indexOf(got) !== -1;
                if (hit && got.length > bestLen) {
                    best = e2;
                    bestLen = got.length;
                }
            }
        }
        return best;
    }

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay)
                out.push(src[i]);
        return out;
    }
    readonly property var results: Fuzzy.rank(allEntries, query, ({}))

    /** Last pointer position that moved the selection, so rows sliding under a still cursor never steal it. */
    property point lastPointer: Qt.point(-1, -1)

    function pick() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var e = results[selectedIndex];
        if (e)
            picker.picked(e);
    }

    /** named to dodge Column's built-in `move` Transition property */
    function moveSel(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        addList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function openAdd() {
        picker.query = "";
        picker.selectedIndex = 0;
        picker.addOpen = true;
    }

    function closeAdd() {
        picker.addOpen = false;
        picker.query = "";
    }

    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = 0;
    onAddOpenChanged: if (addOpen) Qt.callLater(search.input.forceActiveFocus)

    AddBar {
        visible: !picker.addOpen
        s: picker.s
        text: "Add app"
        lit: picker.barLit
        onClicked: picker.openAdd()
    }

    Item { width: 1; height: Theme.sp.xs * picker.s; visible: picker.addOpen }

    SearchField {
        id: search
        width: parent.width
        visible: picker.addOpen
        s: picker.s
        kanji: "探"
        placeholder: "Search apps"
        counterText: picker.results.length + ""
        onTextChanged: {
            picker.query = text;
            picker.selectedIndex = 0;
        }
        onMoved: (d) => picker.moveSel(d)
        onAccepted: picker.pick()
        onDismissed: picker.closeAdd()
    }

    Item { width: 1; height: Theme.sp.s * picker.s; visible: picker.addOpen }

    EmptyState {
        width: parent.width
        visible: picker.addOpen && picker.results.length === 0
        s: picker.s
        glyph: "app-window"
        text: "No apps match"
    }

    Item {
        width: parent.width
        height: picker.shownRows * picker.rowH + Math.max(0, picker.shownRows - 1) * picker.rowGap
        visible: picker.addOpen && picker.results.length > 0

        ListView {
            id: addList
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: picker.rowGap
            snapMode: ListView.SnapToItem
            model: picker.results.length

            delegate: Item {
                id: appRow
                required property int index
                width: addList.width
                height: picker.rowH

                readonly property var entry: picker.results[index]
                readonly property bool selected: index === picker.selectedIndex

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r.m * picker.s
                    visible: appRow.selected || appArea.containsMouse
                    color: appArea.pressed ? Theme.hair : (appRow.selected ? Theme.frameBg : Qt.alpha(Theme.cream, 0.03))
                    border.width: appRow.selected ? 1 : 0
                    border.color: Theme.frameBorder
                }

                MouseArea {
                    id: appArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (m) => {
                        var g = appArea.mapToItem(null, m.x, m.y);
                        if (g.x !== picker.lastPointer.x || g.y !== picker.lastPointer.y) {
                            picker.lastPointer = Qt.point(g.x, g.y);
                            picker.selectedIndex = appRow.index;
                        }
                    }
                    onClicked: {
                        picker.selectedIndex = appRow.index;
                        picker.pick();
                    }
                }

                Rectangle {
                    id: appTileBg
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.m * picker.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24 * picker.s
                    height: 24 * picker.s
                    radius: Theme.r.s * picker.s
                    color: Theme.frameBg
                    visible: !(appIcon.status === Image.Ready && appIcon.source != "")
                }
                Image {
                    id: appIcon
                    anchors.fill: appTileBg
                    sourceSize.width: Math.round(40 * picker.s)
                    sourceSize.height: Math.round(40 * picker.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: appRow.entry && appRow.entry.icon ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                }

                Text {
                    anchors.left: appTileBg.right
                    anchors.leftMargin: Theme.sp.m * picker.s
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.m * picker.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: appRow.entry ? appRow.entry.name : ""
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * picker.s
                    font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: picker.s
            flick: addList
        }
    }
}
