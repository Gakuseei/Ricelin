pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."
import "../Singletons"
import "../lib/fuzzy.js" as Fuzzy
import "app.js" as App

/** Apps routed into one special space, with a fuzzy app search to add more; the page owns the file and gets `removed(index)` and `added(windowClass)`. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property string title: ""
    property string combo: ""
    property var entries: []
    signal removed(int index)
    signal added(string cls)
    signal back()

    property string query: ""
    property int current: 0
    readonly property int maxResults: 6

    width: parent ? parent.width : implicitWidth
    implicitWidth: 480 * s
    implicitHeight: col.implicitHeight

    readonly property var allApps: DesktopEntries.applications.values
    readonly property var results: query.trim().length === 0 ? [] : Fuzzy.rank(allApps.filter(e => e && !e.noDisplay), query, ({})).slice(0, maxResults)

    function focusSearch() {
        search.input.forceActiveFocus();
    }

    /** Comparable key for a class token: `[Ss]potify` and `Ghosttype-app` line up with StartupWMClass or id. */
    function normalizeClass(cls) {
        return String(cls).replace(/\[(.)(.)\]/g, "$2").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function className(cls) {
        return String(cls).replace(/\[(.)(.)\]/g, "$1").replace(/[\^$\\]|\.\*/g, "");
    }

    /** App behind a window class: exact normalized match first, else the longest 4+ char substring link (GhostType, not Ghostty). */
    function resolveEntry(cls) {
        const want = normalizeClass(cls);
        if (want.length === 0)
            return null;
        const apps = allApps;
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e)
                continue;
            const cands = [e.startupClass, e.id, e.name];
            for (let j = 0; j < cands.length; j++)
                if (cands[j] && normalizeClass(cands[j]) === want)
                    return e;
        }
        let best = null;
        let bestLen = 0;
        for (let k = 0; k < apps.length; k++) {
            const e = apps[k];
            if (!e)
                continue;
            const cands = [e.startupClass, e.id, e.name];
            for (let n = 0; n < cands.length; n++) {
                if (!cands[n])
                    continue;
                const got = normalizeClass(cands[n]);
                if (got.length < 4)
                    continue;
                const hit = (want.length >= 4 && got.indexOf(want) !== -1) || want.indexOf(got) !== -1;
                if (hit && got.length > bestLen) {
                    best = e;
                    bestLen = got.length;
                }
            }
        }
        return best;
    }

    function addEntry(e) {
        addClass(e.startupClass || e.id);
    }

    function addClass(cls) {
        cls = String(cls || "").trim();
        if (cls.length === 0)
            return;
        const want = normalizeClass(cls);
        if (entries.some(x => normalizeClass(x) === want)) {
            App.toast(className(cls) + " is already here", "error");
        } else {
            added(cls);
        }
        search.text = "";
        query = "";
        current = 0;
    }

    function accept() {
        if (results.length > 0)
            addEntry(results[Math.min(current, results.length - 1)]);
        else
            addClass(query);
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 44 * root.s

            AppButton {
                id: backBtn
                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                small: true
                icon: "chevron-left"
                text: "All spaces"
                onClicked: root.back()
            }
            Text {
                anchors.left: backBtn.right
                anchors.leftMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.title + " apps"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
            }
            KeyCap {
                anchors.right: parent.right
                anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: root.combo.length > 0
                s: root.s
                combo: root.combo
            }
        }

        Text {
            x: 12 * root.s
            width: parent.width - 24 * root.s
            bottomPadding: 8 * root.s
            text: "Windows of these apps open straight in " + root.title + "."
            color: Theme.textFaint
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
        }

        Text {
            x: 12 * root.s
            visible: root.entries.length === 0
            topPadding: 10 * root.s
            bottomPadding: 10 * root.s
            text: "No apps open here yet"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
        }

        Repeater {
            model: root.entries

            Item {
                id: entry
                required property string modelData
                required property int index
                readonly property var app: {
                    void root.allApps;
                    return root.resolveEntry(modelData);
                }
                readonly property string label: app && app.name ? app.name : root.className(modelData)

                width: col.width
                height: 46 * root.s

                HoverHandler {
                    id: entryHover
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 12 * root.s
                    height: 1
                    color: Theme.hairSoft
                    visible: entry.index > 0
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 9 * root.s
                    color: Theme.frameBg
                    opacity: entryHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                AppIcon {
                    id: icon
                    x: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    app: entry.app
                    letter: entry.label
                }
                Text {
                    id: nameText
                    anchors.left: icon.right
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.label
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Medium
                }
                Text {
                    anchors.left: nameText.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: removeBtn.left
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.modelData !== entry.label
                    text: entry.modelData
                    color: Theme.textFaint
                    elide: Text.ElideRight
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10.5 * root.s
                }
                AppButton {
                    id: removeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    kind: "ghost"
                    icon: "close"
                    onClicked: root.removed(entry.index)
                }
            }
        }

        Item {
            width: 1
            height: 14 * root.s
        }

        Item {
            width: parent.width
            height: 30 * root.s

            Text {
                x: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Add app"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
            AppField {
                id: search
                x: 92 * root.s
                fieldWidth: 300
                placeholder: "Search apps or type a window class"
                onEdited: (t) => {
                    root.query = t;
                    root.current = 0;
                }
                Keys.onDownPressed: root.current = Math.min(root.current + 1, Math.max(0, root.results.length - 1))
                Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
                Keys.onReturnPressed: root.accept()
                Keys.onEnterPressed: root.accept()
            }
        }

        Column {
            x: 92 * root.s
            width: Math.min(300 * root.s, parent.width - x)
            topPadding: 6 * root.s
            visible: root.query.trim().length > 0

            Repeater {
                model: root.results

                Rectangle {
                    id: hit
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 34 * root.s
                    radius: 7 * root.s
                    color: hitArea.pressed ? Theme.pressBg : (root.current === index ? Theme.frameBg : "transparent")

                    AppIcon {
                        id: hitIcon
                        x: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        app: hit.modelData
                        letter: hit.modelData.name || "?"
                    }
                    Text {
                        anchors.left: hitIcon.right
                        anchors.leftMargin: 10 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: hit.modelData.name || ""
                        color: root.current === hit.index ? Theme.cream : Theme.subtle
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                    }
                    MouseArea {
                        id: hitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) root.current = hit.index
                        onClicked: root.addEntry(hit.modelData)
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.results.length === 0
                topPadding: 4 * root.s
                text: "No app matches. Enter adds “" + root.query.trim() + "” as a window class"
                color: Theme.textFaint
                wrapMode: Text.WordWrap
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
            }
        }
    }

    component AppIcon: Rectangle {
        id: ai
        property var app: null
        property string letter: ""
        property real size: 28
        width: size * root.s
        height: width
        radius: 7 * root.s
        color: img.visible ? "transparent" : Theme.tileBg
        border.width: img.visible ? 0 : 1
        border.color: Theme.hairSoft

        Text {
            anchors.centerIn: parent
            visible: !img.visible
            text: ai.letter.length > 0 ? ai.letter.charAt(0).toUpperCase() : "?"
            color: Theme.iconDim
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
        }
        Image {
            id: img
            anchors.fill: parent
            sourceSize.width: Math.round(40 * root.s)
            sourceSize.height: Math.round(40 * root.s)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready && source != ""
            source: ai.app && ai.app.icon ? Quickshell.iconPath(ai.app.icon, true) : ""
        }
    }
}
