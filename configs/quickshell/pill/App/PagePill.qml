pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "PillDefaults.js" as Defaults
import "app.js" as App

AppPage {
    id: page
    pageId: "pill"
    tabs: ["Layout", "Behaviour", "Shape", "Live activity"]

    /** Which module list the Layout tab edits. */
    property string listMode: "idle"
    stageEmphasis: currentTab === "Layout" ? listMode : ""
    property var idleEntries: []
    property var hoverEntries: []
    property int divSeq: 0

    readonly property var idleItems: itemsFor(idleEntries, "idle")
    readonly property var hoverItems: itemsFor(hoverEntries, "hover")
    readonly property var liveItems: {
        const known = Defaults.liveSources.map(x => x.id);
        const order = Defaults.clone(Flags.liveOrder || []).filter(id => known.indexOf(id) >= 0);
        for (const id of known)
            if (order.indexOf(id) < 0)
                order.push(id);
        const off = Defaults.clone(Flags.liveOff || []);
        return order.map(id => {
            const m = Defaults.liveSources.find(x => x.id === id);
            return { id: id, label: m.label, icon: m.icon, sub: m.sub, on: off.indexOf(id) < 0 };
        });
    }

    function set(k, v) {
        if (!Defaults.same(Flags[k], v))
            Flags[k] = Defaults.clone(v);
    }

    function newDivKey() {
        divSeq++;
        return "div#" + divSeq;
    }

    function flagIds(mode) {
        const v = Defaults.clone(mode === "idle" ? Flags.idleModules : Flags.hoverModules);
        return Array.isArray(v) ? v.map(String) : [];
    }

    /** Entries follow the flag order; dividers keep their keys by position so a reorder never rebuilds them. */
    function sync(mode) {
        const prev = mode === "idle" ? idleEntries : hoverEntries;
        const ids = flagIds(mode);
        if (Defaults.same(prev.map(e => e.id), ids))
            return;
        const pool = prev.filter(e => e.id === "div").map(e => e.key);
        store(mode, ids.map(id => ({ key: id === "div" ? (pool.length > 0 ? pool.shift() : newDivKey()) : id, id: id })));
    }

    function store(mode, entries) {
        if (mode === "idle")
            idleEntries = entries;
        else
            hoverEntries = entries;
    }

    function commit(mode, items) {
        store(mode, items.map(o => ({ key: o.key, id: o.id })));
        set(mode === "idle" ? "idleModules" : "hoverModules", items.map(o => o.id));
    }

    function addModule(mode, id) {
        const entries = (mode === "idle" ? idleEntries : hoverEntries).slice();
        entries.push({ key: id === "div" ? newDivKey() : id, id: id });
        commit(mode, entries);
    }

    function liveTop() {
        const off = Flags.liveOff || [];
        const first = (Flags.liveOrder || []).find(id => off.indexOf(id) < 0);
        const m = Defaults.liveSources.find(x => x.id === first);
        return m ? m.label + " first" : "No source switched on";
    }

    function actionsNote(id) {
        const a = (Flags.hoverActions || {})[id];
        if (!a || !Defaults.iconDefaults[id])
            return "";
        const part = (side, name) => {
            const v = a[side];
            if (typeof v !== "string" || v.length === 0)
                return "";
            return name + ": " + (v.indexOf("cmd:") === 0 ? "runs a command" : Defaults.actionLabel(v).toLowerCase());
        };
        return [part("left", "Left"), part("right", "Right")].filter(t => t.length > 0).join(" · ");
    }

    function subFor(e, mode) {
        if (e.id === "glyph" && !Flags.showGlyphs)
            return "Clock icon while glyphs are off";
        if (e.id === "musicbars" && !Flags.musicViz)
            return "Needs the music visualizer";
        if (e.id === "live")
            return liveTop();
        return mode === "hover" ? actionsNote(e.id) : "";
    }

    function itemsFor(entries, mode) {
        return entries.map(e => {
            const m = Defaults.moduleInfo(e.id);
            const glyph = e.id === "glyph";
            const o = {
                key: e.key,
                id: e.id,
                label: m.label,
                icon: glyph ? (Flags.showGlyphs ? "" : "clock") : (m.icon || ""),
                kanji: glyph ? (Flags.restGlyph || "時") : (m.kanji || ""),
                sub: subFor(e, mode),
                removable: true
            };
            if (mode === "hover" && !Defaults.iconDefaults[e.id])
                o.expandable = false;
            return o;
        });
    }

    function setAction(id, side, v) {
        const all = Defaults.clone(Flags.hoverActions || {}) || {};
        const cur = Object.assign({}, all[id] || {});
        if (v === "default") {
            delete cur[side];
        } else if (v === "cmd") {
            const prev = cur[side];
            cur[side] = typeof prev === "string" && prev.indexOf("cmd:") === 0 ? prev : "cmd:";
        } else {
            cur[side] = v;
        }
        if (Object.keys(cur).length === 0)
            delete all[id];
        else
            all[id] = cur;
        set("hoverActions", all);
    }

    function reset() {
        for (const k of Defaults.pillKeys)
            set(k, Defaults.flags[k]);
        deco.setPillBlur(false);
    }

    /** "pill.idle" and "pill.hover" share one spot, so the list switch flips before the jump. */
    function reveal(key) {
        if (key === "pill.idle" || key === "pill.hover")
            listMode = key === "pill.idle" ? "idle" : "hover";
        const row = rowMap[key];
        if (!row)
            return false;
        const g = row.group;
        if (g && g.tab.length > 0 && g.tab !== currentTab)
            currentTab = g.tab;
        if (g && row.advanced && !g.showMore)
            g.expandNow();
        if (App.shell)
            App.shell.scrollToItem(row, true);
        return true;
    }

    Component.onCompleted: {
        sync("idle");
        sync("hover");
    }

    Connections {
        target: Flags
        function onIdleModulesChanged() {
            page.sync("idle");
        }
        function onHoverModulesChanged() {
            page.sync("hover");
        }
    }

    PillDeco {
        id: deco
    }

    AppGroup {
        tab: "Layout"

        AppRow {
            label: "Module list"
            sub: "Pick which state of the pill you are editing"
            key: "pill.list"

            AppSeg {
                s: page.s
                options: [{ label: "Idle", value: "idle" }, { label: "Hover", value: "hover" }]
                value: page.listMode
                onPicked: (v) => page.listMode = v
            }
        }
    }

    AppGroup {
        tab: "Layout"
        title: page.listMode === "idle" ? "Idle" : "Hover"
        hint: page.listMode === "idle" ? "Drag to reorder, the cross removes one"
            : "Drag to reorder. The arrow sets what a click does"

        AppRow {
            visible: page.listMode === "idle"
            key: "pill.idle"
            block: true

            ModuleList {
                mode: "idle"
                items: page.idleItems
            }
        }

        AppRow {
            visible: page.listMode === "hover"
            key: "pill.hover"
            block: true

            ModuleList {
                mode: "hover"
                items: page.hoverItems
                detail: Component {
                    ActionDetail {}
                }
            }
        }
    }

    AppGroup {
        tab: "Behaviour"
        title: "Opening"

        AppRow {
            label: "Expand"
            sub: "Click opens only on free space; moving away closes it"
            key: "pill.expand"

            AppSeg {
                s: page.s
                options: [{ label: "Hover", value: "hover" }, { label: "Click", value: "click" }]
                value: Flags.expandMode
                onPicked: (v) => Flags.expandMode = v
            }
        }

        advanced: [
            AppRow {
                label: "Open delay"
                sub: "Wait this long before the pill opens on hover"
                key: "pill.openDelay"

                AppSlider {
                    s: page.s
                    from: 0
                    to: 400
                    step: 10
                    unit: "ms"
                    value: Flags.openDelay
                    onCommitted: (v) => page.set("openDelay", Math.round(v))
                }
            },
            AppRow {
                label: "Close delay"
                sub: "How long the pill stays open after the mouse leaves"
                key: "pill.closeDelay"

                AppSlider {
                    s: page.s
                    from: 100
                    to: 1000
                    step: 10
                    unit: "ms"
                    value: Flags.closeDelay
                    onCommitted: (v) => page.set("closeDelay", Math.round(v))
                }
            }
        ]
    }

    AppGroup {
        tab: "Behaviour"
        title: "Workspaces"

        AppRow {
            label: "Workspace style"
            sub: "How workspaces look in the pill"
            key: "pill.wsStyle"

            AppSeg {
                s: page.s
                options: [{ label: "Dots", value: "dots" }, { label: "Numbers", value: "numbers" }, { label: "Names", value: "names" }]
                value: Flags.wsStyle
                onPicked: (v) => Flags.wsStyle = v
            }
        }

        AppRow {
            label: "Show workspaces"
            sub: "Occupied hides the empty ones"
            key: "pill.wsShow"

            AppSeg {
                s: page.s
                options: [{ label: "Occupied", value: "occupied" }, { label: "All", value: "all" }]
                value: Flags.wsShow
                onPicked: (v) => Flags.wsShow = v
            }
        }

        AppRow {
            label: "Scroll to switch workspace"
            sub: "Turn the mouse wheel over the workspaces"
            key: "pill.wsScroll"

            AppToggle {
                s: page.s
                checked: Flags.wsScroll
                onToggled: (on) => Flags.wsScroll = on
            }
        }
    }

    AppGroup {
        tab: "Shape"
        title: "Size"

        AppRow {
            label: "Height"
            sub: "Height at rest; the open pill grows with it"
            key: "pill.height"

            AppSlider {
                s: page.s
                from: 24
                to: 64
                step: 1
                unit: "px"
                value: Flags.pillHeight
                onMoved: (v) => page.set("pillHeight", v)
                onCommitted: (v) => page.set("pillHeight", v)
            }
        }

        AppRow {
            label: "Idle width"
            sub: "Make the resting pill longer"
            key: "pill.idleWidth"

            AppSlider {
                s: page.s
                from: 120
                to: 480
                step: 5
                unit: "px"
                value: Flags.idleWidth
                onMoved: (v) => page.set("idleWidth", v)
                onCommitted: (v) => page.set("idleWidth", v)
            }
        }

        AppRow {
            label: "Rounding"
            sub: "How round the corners are; half the height is fully round"
            key: "pill.rounding"

            AppSlider {
                readonly property int most: Math.floor(Math.max(24, Math.min(64, Flags.pillHeight)) / 2)
                s: page.s
                from: 0
                to: most
                step: 1
                unit: "px"
                value: Math.min(Flags.pillRounding, most)
                onMoved: (v) => page.set("pillRounding", v)
                onCommitted: (v) => page.set("pillRounding", v)
            }
        }

        AppRow {
            label: "UI scale"
            sub: "Size of the pill, its panels and this window"
            key: "pill.scale"

            AppSlider {
                s: page.s
                from: 80
                to: 150
                step: 5
                unit: "%"
                value: Math.round(Flags.uiScale * 100)
                onCommitted: (v) => page.set("uiScale", v / 100)
            }
        }

        advanced: [
            AppRow {
                label: "Top gap"
                sub: "Space above the pill; 100% is 8 px"
                key: "pill.topGap"

                AppSlider {
                    s: page.s
                    from: 0
                    to: 200
                    step: 5
                    unit: "%"
                    value: Math.round(Flags.topGap * 100)
                    onCommitted: (v) => page.set("topGap", v / 100)
                }
            },
            AppRow {
                label: "Window gap"
                sub: "Space between the pill and the windows below; 100% is 12 px"
                key: "pill.winGap"

                AppSlider {
                    s: page.s
                    from: 0
                    to: 200
                    step: 5
                    unit: "%"
                    value: Math.round(Flags.appGap * 100)
                    onCommitted: (v) => page.set("appGap", v / 100)
                }
            }
        ]
    }

    AppGroup {
        tab: "Shape"
        title: "Surface"

        AppRow {
            label: "Opacity"
            sub: "Lower lets the wallpaper show through"
            key: "pill.opacity"

            AppSlider {
                s: page.s
                from: 55
                to: 100
                step: 1
                unit: "%"
                value: Math.round(Flags.pillOpacity * 100)
                onMoved: (v) => page.set("pillOpacity", v / 100)
                onCommitted: (v) => page.set("pillOpacity", v / 100)
            }
        }

        AppRow {
            label: "Blur"
            sub: Flags.pillOpacity < 1 ? "Frosts what shows through the pill" : "Frosts what shows through; needs opacity under 100%"
            key: "pill.blur"

            AppToggle {
                s: page.s
                checked: Flags.pillBlur
                onToggled: (on) => {
                    Flags.pillBlur = on;
                    deco.setPillBlur(on);
                }
            }
        }

        AppRow {
            label: "Shadow"
            sub: "Soft shadow under the pill"
            key: "pill.shadow"

            AppToggle {
                s: page.s
                checked: Flags.pillShadow
                onToggled: (on) => Flags.pillShadow = on
            }
        }

        advanced: [
            AppRow {
                label: "Border"
                sub: "Thin outline around the pill"
                key: "pill.border"

                AppToggle {
                    s: page.s
                    checked: Flags.pillBorder
                    onToggled: (on) => Flags.pillBorder = on
                }
            },
            AppRow {
                label: "Sheen line"
                sub: "Thin light along the top edge"
                key: "pill.sheen"

                AppToggle {
                    s: page.s
                    checked: Flags.pillSheen
                    onToggled: (on) => Flags.pillSheen = on
                }
            },
            AppRow {
                label: "Spring feel"
                sub: "How the pill grows when it opens"
                key: "pill.spring"

                AppSeg {
                    s: page.s
                    options: [{ label: "Soft", value: "soft" }, { label: "Snappy", value: "snappy" }]
                    value: Flags.springFeel
                    onPicked: (v) => Flags.springFeel = v
                }
            }
        ]
    }

    AppGroup {
        tab: "Live activity"
        title: "Sources"
        hint: "The first running source shows beside the clock. Drag to set the order."

        AppRow {
            key: "pill.live"
            block: true

            AppSortableList {
                s: page.s
                items: page.liveItems
                onEdited: (a) => {
                    page.set("liveOrder", a.map(o => o.id));
                    page.set("liveOff", a.filter(o => !o.on).map(o => o.id));
                }
            }
        }
    }

    AppGroup {
        tab: "Behaviour"
        title: "Battery"

        AppRow {
            label: "Battery warning"
            sub: "The battery turns red below this"
            key: "pill.battWarn"

            AppSlider {
                s: page.s
                from: 5
                to: 50
                step: 1
                unit: "%"
                value: Flags.batteryWarn
                onCommitted: (v) => page.set("batteryWarn", Math.round(v))
            }
        }
    }

    component ModuleList: Column {
        id: ml

        property string mode: "idle"
        property alias items: sortable.items
        property alias detail: sortable.detail

        width: parent ? parent.width : 0
        spacing: 6 * page.s

        AppSortableList {
            id: sortable
            s: page.s
            onEdited: (a) => page.commit(ml.mode, a)
        }

        Text {
            x: 6 * page.s
            topPadding: 6 * page.s
            text: "Add to the " + (ml.mode === "idle" ? "idle" : "hover") + " pill"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11 * page.s
            font.weight: Font.Medium
        }

        Flow {
            id: chips
            readonly property var used: page.flagIds(ml.mode)
            x: 6 * page.s
            width: parent.width - 12 * page.s
            spacing: 6 * page.s

            Repeater {
                model: [Defaults.moduleInfo("div")].concat(Defaults.modules.filter(m => chips.used.indexOf(m.id) < 0))

                AppButton {
                    required property var modelData
                    s: page.s
                    small: true
                    icon: "plus"
                    text: modelData.label
                    onClicked: page.addModule(ml.mode, modelData.id)
                }
            }
        }
    }

    component ActionDetail: Column {
        id: det

        property var entry: ({})
        property int index: -1
        readonly property string mid: det.entry ? String(det.entry.id) : ""

        spacing: 8 * page.s
        bottomPadding: 4 * page.s

        ActionLine {
            mid: det.mid
            side: "left"
            label: "Left click"
        }
        ActionLine {
            mid: det.mid
            side: "right"
            label: "Right click"
        }
    }

    component ActionLine: Row {
        id: line

        property string mid: ""
        property string side: "left"
        property string label: ""
        readonly property var defs: Defaults.iconDefaults[line.mid] || ({ left: "open", right: "none" })
        readonly property string raw: {
            const a = (Flags.hoverActions || {})[line.mid];
            const v = a ? a[line.side] : undefined;
            return typeof v === "string" ? v : "";
        }
        readonly property string choice: raw.length === 0 ? "default" : (raw.indexOf("cmd:") === 0 ? "cmd" : raw)

        spacing: 10 * page.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 76 * page.s
            text: line.label
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * page.s
        }

        AppSelect {
            anchors.verticalCenter: parent.verticalCenter
            s: page.s
            minWidth: 200
            options: [{ label: "Default (" + Defaults.actionLabel(line.defs[line.side]) + ")", value: "default" }].concat(Defaults.actions)
            value: line.choice
            onPicked: (v) => page.setAction(line.mid, line.side, v)
        }

        AppField {
            id: cmdField
            anchors.verticalCenter: parent.verticalCenter
            visible: line.choice === "cmd"
            s: page.s
            fieldWidth: 230
            mono: true
            placeholder: "Command, e.g. kitty -e btop"
            text: line.raw.indexOf("cmd:") === 0 ? line.raw.slice(4) : ""
            valid: text.trim().length > 0
            onAccepted: (t) => {
                if (line.choice === "cmd")
                    page.setAction(line.mid, line.side, "cmd:" + t.trim());
            }
        }
    }
}
