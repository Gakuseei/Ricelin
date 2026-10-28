pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"
import "../lib/fuzzy.js" as Fuzzy
import "../lib/binds.js" as Binds
import "PageKeybindsNames.js" as Names
import "pages.js" as Pages
import "searchIndex.js" as Index

/** Top-bar search over searchIndex.js and live binds.lua; `chosen(entry)` fires on Enter or click with { page, tab, key }. */
Item {
    id: root

    property real s: 1
    property real resultsWidth: 470 * s
    property real maxResultsHeight: 470 * s
    readonly property string text: field.text
    readonly property bool focused: field.activeFocus
    readonly property bool open: focused && field.text.trim().length > 0
    property var results: []
    property int current: 0
    signal chosen(var entry)
    signal leave()

    readonly property int maxRows: 10
    readonly property int maxBinds: 5

    readonly property var syn: ({
        transparency: ["opacity", "see-through"], transparent: ["opacity", "see-through"], translucent: ["opacity"],
        dark: ["palette", "tone"], light: ["palette", "tone"], theme: ["palette", "appearance"],
        color: ["palette", "hue"], colour: ["palette", "hue"],
        hz: ["refresh rate", "refresh"], fps: ["frame rate", "refresh rate"], polling: ["input", "mouse"],
        corners: ["rounding"], corner: ["rounding"], round: ["rounding"], radius: ["rounding"],
        font: ["typeface", "type"], typeface: ["font"], fonts: ["font", "typeface"],
        gaps: ["gap", "spacing", "margin"], gap: ["gaps", "spacing"], spacing: ["gaps", "gap"], margin: ["gaps", "gap"],
        bar: ["pill"], panel: ["pill"], topbar: ["pill"],
        shortcut: ["keybind", "shortcut"], shortcuts: ["keybind"], hotkey: ["keybind"], hotkeys: ["keybind"],
        screen: ["display", "monitor"], monitor: ["display"], sleep: ["suspend", "idle"], wallpaper: ["random"]
    })

    function focusField() {
        field.forceActiveFocus();
        field.selectAll();
    }

    function clear() {
        field.text = "";
    }

    function esc(t) {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function mark(label, q) {
        const lo = label.toLowerCase();
        const toks = q.toLowerCase().trim().split(/\s+/).filter(t => t.length > 0).sort((a, b) => b.length - a.length);
        for (let i = 0; i < toks.length; i++) {
            const at = lo.indexOf(toks[i]);
            if (at >= 0) {
                const n = toks[i].length;
                return esc(label.slice(0, at)) + "<font color=\"" + Theme.vermLit + "\">" + esc(label.slice(at, at + n)) + "</font>" + esc(label.slice(at + n));
            }
        }
        return esc(label);
    }

    property var bindCache: null

    function bindEntries() {
        if (bindCache !== null)
            return bindCache;
        let parsed = [];
        try {
            parsed = Binds.parse(bindsFile.text());
        } catch (e) {
            parsed = [];
        }
        bindCache = parsed.map(b => ({
            page: "keybinds", tab: "", group: "", kind: "bind",
            label: Names.label(b),
            sub: Names.combo(b.combo),
            keywords: ["shortcut keybind hotkey", b.name, b.label, Names.action(b)].join(" "),
            key: "bind:" + b.combo, advanced: false
        }));
        return bindCache;
    }

    /** A token hits on a substring, a synonym, or as a typo-tolerant subsequence of a short label starting on a word. */
    function tokOk(t, hay, leaf, loose) {
        if (hay.indexOf(t) >= 0)
            return true;
        const alts = syn[t];
        if (alts)
            for (let i = 0; i < alts.length; i++)
                if (hay.indexOf(alts[i]) >= 0)
                    return true;
        return loose && t.length >= 3 && Fuzzy.subsequence(t, leaf) && leaf.split(/\s+/).some(w => w.charAt(0) === t.charAt(0));
    }

    function crumbOf(e) {
        const meta = Pages.pages[e.page];
        if (!meta)
            return [];
        if (e.kind !== "bind" && !e.key && e.label === meta.name)
            return [];
        const mid = e.tab || e.group || "";
        return mid.length > 0 && mid !== e.label && mid !== meta.name ? [meta.name, mid] : [meta.name];
    }

    function run(query) {
        const q = query.trim().toLowerCase();
        if (q.length === 0)
            return [];
        const toks = q.split(/\s+/);
        const all = Index.all().concat(bindEntries());
        const hits = [];
        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            const meta = Pages.pages[e.page];
            if (!meta || !e.label)
                continue;
            const leaf = String(e.label).toLowerCase();
            const hay = [meta.name, e.tab, e.group, e.label, e.sub, e.keywords].filter(x => x && String(x).length > 0).join(" ").toLowerCase();
            if (!toks.every(t => tokOk(t, hay, leaf, e.kind !== "bind")))
                continue;
            let sc = Fuzzy.score({ name: e.label, keywords: [hay] }, q);
            if (sc >= 99)
                sc = 1.5;
            if (e.kind === "bind")
                sc += 0.3;
            else if (!e.key)
                sc += sc === 0 ? 0.5 : 0.8;
            hits.push({ e: e, sc: sc, i: i });
        }
        hits.sort((a, b) => a.sc - b.sc || a.i - b.i);
        const out = [];
        let binds = 0;
        let bindTotal = 0;
        for (let i = 0; i < hits.length; i++) {
            const e = hits[i].e;
            if (e.kind === "bind") {
                bindTotal++;
                if (binds >= maxBinds)
                    continue;
                binds++;
            }
            if (out.length < maxRows)
                out.push(e);
        }
        if (bindTotal > binds)
            out.push({ page: "keybinds", tab: "", group: "", kind: "more", key: "filter:" + query.trim(),
                       label: "Show all " + bindTotal + " binds for “" + query.trim() + "”", sub: "" });
        return out.map(e => ({ entry: e, crumb: crumbOf(e) }));
    }

    function refresh() {
        results = run(field.text);
        current = 0;
    }

    function choose(i) {
        const r = results[i];
        if (!r)
            return;
        const e = r.entry;
        clear();
        root.leave();
        root.chosen({ page: e.page, tab: e.tab || "", key: e.key || "" });
    }

    FileView {
        id: bindsFile
        path: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.bindCache = null;
            if (root.open)
                root.refresh();
        }
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 9 * root.s
        color: Qt.alpha(Theme.cardBot, 0.75)
        border.width: 1
        border.color: field.activeFocus ? Qt.alpha(Theme.vermLit, 0.45) : (boxHover.hovered ? Theme.border : Theme.frameBorder)
        Behavior on border.color { ColorAnimation { duration: 120 } }

        HoverHandler {
            id: boxHover
            cursorShape: Qt.IBeamCursor
        }

        GlyphIcon {
            id: lens
            x: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: width
            name: "search"
            color: field.activeFocus ? Theme.subtle : Theme.textFaint
        }

        QQC.TextField {
            id: field
            anchors.left: lens.right
            anchors.leftMargin: 8 * root.s
            anchors.right: clearBtn.visible ? clearBtn.left : parent.right
            anchors.rightMargin: 6 * root.s
            anchors.verticalCenter: parent.verticalCenter
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            placeholderText: "Search settings"
            placeholderTextColor: Theme.textFaint
            selectByMouse: true
            selectionColor: Theme.verm
            selectedTextColor: Theme.bright
            onTextChanged: root.refresh()

            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
                    if (root.results.length > 0) {
                        const n = root.results.length;
                        root.current = (root.current + (e.key === Qt.Key_Down ? 1 : -1) + n) % n;
                        list.positionViewAtIndex(root.current, ListView.Contain);
                    }
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.choose(root.current);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    if (field.text.length > 0) {
                        root.clear();
                        root.leave();
                        e.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            id: clearBtn
            anchors.right: parent.right
            anchors.rightMargin: 5 * root.s
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text.length > 0
            width: 22 * root.s
            height: width
            radius: 6 * root.s
            color: clearArea.containsMouse ? Theme.frameBg : "transparent"

            GlyphIcon {
                anchors.centerIn: parent
                width: 12 * root.s
                height: width
                name: "close"
                stroke: 2
                color: clearArea.containsMouse ? Theme.cream : Theme.textFaint
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clear();
                    root.leave();
                }
            }
        }
    }

    Item {
        id: drop
        y: root.height + 6 * root.s
        width: root.resultsWidth
        height: panel.height
        visible: root.open
        opacity: visible ? 1 : 0

        RectangularShadow {
            anchors.fill: panel
            radius: panel.radius
            blur: 32 * root.s
            offset.y: 10 * root.s
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        Rectangle {
            id: panel
            width: parent.width
            height: root.results.length > 0 ? Math.min(root.maxResultsHeight, list.contentHeight + 10 * root.s) : none.implicitHeight + 10 * root.s
            radius: 12 * root.s
            color: Theme.cardTop
            border.width: 1
            border.color: Theme.border

            Text {
                id: none
                visible: root.results.length === 0
                x: 12 * root.s
                y: 5 * root.s
                topPadding: 8 * root.s
                bottomPadding: 8 * root.s
                text: "Nothing found for “" + field.text.trim() + "”"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 5 * root.s
                clip: true
                spacing: 1 * root.s
                boundsBehavior: Flickable.StopAtBounds
                model: root.results
                currentIndex: root.current

                QQC.ScrollBar.vertical: AppScrollBar {
                    s: root.s
                }

                WheelScroller {
                    parent: list
                    anchors.fill: parent
                    z: 5
                    s: root.s
                    step: 64
                    byNotch: true
                    flick: list
                }

                delegate: Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    readonly property var e: modelData.entry
                    readonly property bool on: root.current === index
                    readonly property string crumbText: modelData.crumb.length > 0 ? root.esc(modelData.crumb.join(" › ")) + " › " : ""

                    width: ListView.view.width
                    height: col.implicitHeight + 14 * root.s
                    radius: 8 * root.s
                    color: on ? Theme.frameBg : "transparent"

                    GlyphIcon {
                        x: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * root.s
                        height: width
                        name: (Pages.pages[res.e.page] || {}).icon || "cog"
                        color: res.on ? Theme.cream : Theme.textFaint
                    }

                    Column {
                        id: col
                        x: 36 * root.s
                        width: parent.width - x - 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1 * root.s

                        Text {
                            width: parent.width
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            text: res.e.kind === "more"
                                ? root.esc(res.e.label)
                                : "<font color=\"" + Theme.textFaint + "\">" + res.crumbText + "</font>" + root.mark(String(res.e.label), field.text)
                            color: res.e.kind === "more" ? Theme.subtle : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12.5 * root.s
                            font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: res.e.sub || ""
                            elide: Text.ElideRight
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) root.current = res.index
                        onClicked: root.choose(res.index)
                    }
                }
            }
        }
    }
}
