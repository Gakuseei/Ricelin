pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
import "lib/fuzzy.js" as Fuzzy
import "lib/calc.js" as Calc

/**
 * Launcher: fuzzy app search ranked by launch frequency (usage file shared with the standalone launcher).
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    property string query: ""
    property int selectedIndex: 0
    property var usage: ({})

    /** A query that is a real calculation (not a lone number or "python3") shows a result row; lib/calc.js never evals. */
    readonly property var calc: Calc.evaluate(query)
    readonly property bool calcActive: calc.ok
    property bool calcCopied: false
    onQueryChanged: calcCopied = false

    function copyResult() {
        if (!root.calcActive)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", root.calc.display]);
        root.calcCopied = true;
    }

    /** Row index currently in AppImage edit mode (rename plus armed delete), -1 when none. */
    property int editIndex: -1

    readonly property string appimageScript: Quickshell.env("HOME") + "/.config/hypr/scripts/app-install.sh"
    readonly property string guardScript: Quickshell.env("HOME") + "/.config/hypr/scripts/launch-guard.sh"

    /** execute() fails silently, so the guard script watches startup and toasts a crash with its stderr. */
    function launch(entry) {
        if (!entry.command || entry.command.length === 0) {
            entry.execute();
            return;
        }
        Quickshell.execDetached(["bash", root.guardScript, entry.name, entry.icon || "", entry.workingDirectory || ""].concat(entry.command));
    }

    function appimageSlug(entry) {
        return entry && entry.id && entry.id.indexOf("ricelin-") === 0 ? entry.id.substring(8) : "";
    }

    Process { id: appimageProc }

    /** Last pointer position that moved the selection, so rows sliding under a still cursor never steal it. */
    property point lastPointer: Qt.point(-1, -1)

    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void search.input.width;
        return search.input.mapToItem(root,
            search.input.cursorRectangle.x + search.input.cursorRectangle.width / 2,
            search.input.cursorRectangle.y + search.input.cursorRectangle.height / 2);
    }
    readonly property real caretX: caretPoint.x
    readonly property real caretY: caretPoint.y

    ameForm: "caret"
    amePoint: Qt.point(caretX, caretY)

    readonly property string usageFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/launcher-usage.json"

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }
    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    readonly property real rowH: 38 * s
    readonly property real rowGap: 5 * s

    /** Whole rows that fit between the divider (or calc row) and the hint, so no row is ever cut. */
    readonly property int rowsFit: {
        var top = (calcActive ? calcRow.y + calcRow.height : divider.y + divider.height) + 6 * s;
        var bottom = hint.visible ? hint.y - Theme.sp.s * s : height;
        return Math.max(0, Math.floor((bottom - top + rowGap) / (rowH + rowGap)));
    }

    function focusField() { search.input.forceActiveFocus(); }

    function mapCategory(raw) {
        const order = [
            ["TerminalEmulator", "Terminal"], ["WebBrowser", "Browser"],
            ["InstantMessaging", "Chat"], ["Audio", "Media"], ["AudioVideo", "Media"],
            ["Video", "Media"], ["Game", "Game"], ["Development", "Dev"],
            ["Graphics", "Graphics"], ["Office", "Office"], ["Settings", "System"],
            ["System", "System"], ["Utility", "Tool"], ["Network", "Net"]
        ];
        const cats = String(raw).split(/[;,]/);
        for (let i = 0; i < order.length; i++)
            if (cats.includes(order[i][0]))
                return order[i][1];
        return "";
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (root.calcActive) {
            root.copyResult();
            return;
        }
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var entry = results[selectedIndex];
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
                usageStore.setText(JSON.stringify(root.usage));
            }
            root.launch(entry);
        }
        root.requestClose();
    }

    onActiveChanged: {
        if (active) {
            query = "";
            search.text = "";
            selectedIndex = 0;
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: {
        if (selectedIndex >= results.length)
            selectedIndex = 0;
        editIndex = -1;
    }

    FileView {
        id: usageStore
        path: root.usageFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = usageStore.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    SearchField {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        kanji: "探"
        placeholder: "Search apps"
        counterText: root.results.length + " / " + root.totalCount
        onTextChanged: {
            root.query = text;
            root.selectedIndex = 0;
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.requestClose()
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Item {
        id: calcRow
        visible: root.calcActive
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? 44 * root.s : 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.r.m * root.s
            color: calcArea.pressed ? Theme.hair : Theme.frameBg
            border.width: 1
            border.color: Theme.frameBorder
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: calcArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyResult()
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s

            Column {
                anchors.left: parent.left
                anchors.right: copyHint.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s

                Text {
                    width: parent.width
                    text: "= " + root.calc.display
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.title * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.query
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    elide: Text.ElideRight
                }
            }

            Text {
                id: copyHint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.calcCopied ? "Copied" : "↵ Copy"
                color: root.calcCopied ? Theme.textFaint : Theme.vermLit
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
            }
        }
    }

    EmptyState {
        anchors.horizontalCenter: parent.horizontalCenter
        y: list.y + Theme.sp.l * root.s
        visible: root.results.length === 0 && !root.calcActive
        s: root.s
        glyph: "app-window"
        text: root.query.length ? "No matches" : "No apps found"
    }

    ListView {
        id: list
        anchors.top: root.calcActive ? calcRow.bottom : divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rowsFit * root.rowH + Math.max(0, root.rowsFit - 1) * root.rowGap
        spacing: root.rowGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        model: root.results.length

        delegate: Item {
            id: appRow
            required property int index
            width: list.width
            height: root.rowH

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex
            readonly property bool isAppImage: entry && entry.id && entry.id.indexOf("ricelin-") === 0
            readonly property bool editing: root.editIndex === index && isAppImage
            property bool armed: false
            onEditingChanged: if (!editing) armed = false

            readonly property string secondary: {
                if (!entry)
                    return "";
                if (entry.genericName && entry.genericName.length > 0)
                    return entry.genericName;
                if (entry.categories && entry.categories.length > 0)
                    return root.mapCategory(entry.categories);
                return "";
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.r.m * root.s
                visible: appRow.selected || rowArea.containsMouse
                color: rowArea.pressed ? Theme.hair : (appRow.selected ? Theme.frameBg : Qt.alpha(Theme.cream, 0.03))
                border.width: appRow.selected ? 1 : 0
                border.color: Theme.frameBorder
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: (m) => {
                    var g = rowArea.mapToItem(null, m.x, m.y);
                    if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                        root.lastPointer = Qt.point(g.x, g.y);
                        root.selectedIndex = appRow.index;
                    }
                }
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        if (appRow.isAppImage)
                            root.editIndex = appRow.editing ? -1 : appRow.index;
                        return;
                    }
                    if (appRow.editing)
                        return;
                    root.selectedIndex = appRow.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp.m * root.s
                anchors.rightMargin: Theme.sp.m * root.s

                Rectangle {
                    id: iconBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * root.s
                    height: width
                    radius: Theme.r.xs * root.s
                    color: Theme.frameBg
                    visible: !(icon.status === Image.Ready && icon.source != "")
                }
                Image {
                    id: icon
                    anchors.fill: iconBg
                    sourceSize.width: Math.round(40 * root.s)
                    sourceSize.height: Math.round(40 * root.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: {
                        if (!appRow.entry || !appRow.entry.icon)
                            return "";
                        var ic = appRow.entry.icon;
                        if (appRow.isAppImage && ic.indexOf("/") === 0)
                            return "file://" + ic;
                        return Quickshell.iconPath(ic, true);
                    }
                }

                TextMetrics {
                    id: retMetrics
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    text: "↵"
                }
                Text {
                    id: ret
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: retMetrics.text
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    visible: appRow.selected && !appRow.editing
                    width: visible ? retMetrics.advanceWidth + 6 * root.s : 0
                    horizontalAlignment: Text.AlignRight
                }

                GlyphIcon {
                    id: trashGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: appRow.editing ? 16 * root.s : 0
                    height: 16 * root.s
                    visible: appRow.editing
                    stroke: 2
                    name: "trash"
                    color: appRow.armed ? Theme.danger : Theme.iconDim

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        enabled: appRow.editing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!appRow.armed) {
                                appRow.armed = true;
                                return;
                            }
                            var slug = root.appimageSlug(appRow.entry);
                            if (slug) {
                                appimageProc.command = ["bash", root.appimageScript, "remove", slug];
                                appimageProc.running = true;
                            }
                            root.editIndex = -1;
                        }
                    }
                }

                Column {
                    anchors.left: iconBg.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: appRow.editing ? trashGlyph.left : ret.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Item {
                        width: parent.width
                        height: nameText.implicitHeight

                        Text {
                            id: nameText
                            anchors.fill: parent
                            visible: !appRow.editing
                            text: appRow.entry ? appRow.entry.name : ""
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        TextInput {
                            id: nameEdit
                            anchors.fill: parent
                            visible: appRow.editing
                            text: appRow.entry ? appRow.entry.name : ""
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            selectByMouse: true
                            clip: true
                            onVisibleChanged: if (visible) {
                                selectAll();
                                forceActiveFocus();
                            }
                            onEditingFinished: {
                                var slug = root.appimageSlug(appRow.entry);
                                var nm = nameEdit.text.trim();
                                if (slug && nm.length > 0 && nm !== appRow.entry.name) {
                                    appimageProc.command = ["bash", root.appimageScript, "rename", slug, nm];
                                    appimageProc.running = true;
                                }
                                root.editIndex = -1;
                            }
                        }
                    }
                    Text {
                        id: sec
                        width: parent.width
                        visible: appRow.secondary.length > 0
                        text: appRow.secondary
                        color: appRow.selected ? Theme.subtle : Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    WheelScroller {
        anchors.fill: list
        s: root.s
        flick: list
    }

    /** Quiet nudge so the drag-to-install gesture is discoverable at all. */
    Row {
        id: hint
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.sp.xxs * root.s
        spacing: 5 * root.s
        visible: root.query.length === 0 && root.editIndex === -1

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 12 * root.s
            height: 12 * root.s
            stroke: 1.7
            name: "download"
            color: Theme.textFaint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Drag an AppImage onto the pill"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
        }
    }
}
