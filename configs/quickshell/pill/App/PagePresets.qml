pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "PillDefaults.js" as Defaults
import "app.js" as App

AppPage {
    id: page
    pageId: "presets"

    readonly property var builtins: Defaults.builtins.map(b => ({ id: b.id, name: b.name, desc: b.desc, user: false, values: Defaults.fullValues(b.values) }))
    readonly property var users: store.user.map(u => ({ id: String(u.id), name: String(u.name), desc: summary(u.values || {}), user: true, values: Defaults.fullValues(u.values) }))

    /** The preset the current look matches: the remembered one first, else the first match. */
    readonly property string activeMatch: {
        const all = builtins.concat(users);
        const mine = all.find(p => p.id === store.active);
        if (mine && matches(mine.values))
            return mine.id;
        const any = all.find(p => matches(p.values));
        return any ? any.id : "";
    }

    function summary(v) {
        const names = (v.idleModules || []).filter(id => id !== "div").map(id => Defaults.moduleInfo(id).label);
        const head = names.length > 0 ? names.join(", ") : "An empty resting pill";
        return head + (v.expandMode === "click" ? ". Opens on click" : "");
    }

    function current() {
        const o = {};
        for (const k of Defaults.presetKeys)
            o[k] = Defaults.clone(Flags[k]);
        o.deco = deco.values();
        return o;
    }

    function matches(v) {
        for (const k of Defaults.presetKeys)
            if (!Defaults.same(Flags[k], v[k]))
                return false;
        const d = deco.values();
        for (const f of Defaults.decoFields)
            if (!Defaults.same(d[f.key], v.deco[f.key]))
                return false;
        return true;
    }

    function statusOf(id) {
        return id === activeMatch ? "active" : (id === store.active ? "modified" : "");
    }

    /** Writes the whole set at once; Undo restores it from its snapshot and the window's PillPalette re-runs the palette. */
    function applyPreset(p, quiet) {
        const v = p.values;
        for (const k of Defaults.presetKeys)
            if (!Defaults.same(Flags[k], v[k]))
                Flags[k] = Defaults.clone(v[k]);
        deco.apply(v.deco, v.pillBlur === true);
        store.setActive(p.id);
        if (!quiet)
            App.toast("Applied " + p.name);
    }

    function saveNamed(raw) {
        const name = String(raw).trim();
        if (name.length === 0)
            return;
        const existed = store.user.some(x => String(x.name).toLowerCase() === name.toLowerCase());
        store.save(name, current());
        nameIn.text = "";
        if (App.shell)
            App.shell.focusHome();
        App.toast((existed ? "Updated " : "Saved ") + name);
    }

    function reset() {
        applyPreset(builtins[0], true);
    }

    PillDeco {
        id: deco
    }
    PresetStore {
        id: store
    }

    AppGroup {
        title: "Built in"
        hint: "Each sets the whole look, windows included. Undo takes it back."

        AppRow {
            key: "presets.builtin"
            block: true

            CardGrid {
                presets: page.builtins
            }
        }
    }

    AppGroup {
        title: "Yours"

        AppRow {
            label: "Save current as preset"
            sub: "Keeps the pill, palette, clock and window look under a name"
            key: "presets.save"

            Row {
                spacing: 8 * page.s

                AppField {
                    id: nameIn
                    s: page.s
                    fieldWidth: 170
                    placeholder: "Name"
                    maxLength: 40

                    Connections {
                        target: nameIn.input
                        function onAccepted() {
                            page.saveNamed(nameIn.text);
                        }
                    }
                }
                AppButton {
                    s: page.s
                    kind: "primary"
                    text: "Save"
                    enabled: nameIn.text.trim().length > 0
                    onClicked: page.saveNamed(nameIn.text)
                }
            }
        }

        AppRow {
            key: "presets.user"
            block: true

            Item {
                width: parent.width
                implicitHeight: page.users.length > 0 ? userGrid.implicitHeight : emptyText.implicitHeight + 4 * page.s

                Text {
                    id: emptyText
                    visible: page.users.length === 0
                    width: parent.width
                    text: "Nothing saved yet. Name the current look above to keep it."
                    color: Theme.textFaint
                    wrapMode: Text.WordWrap
                    font.family: Theme.font
                    font.pixelSize: 12 * page.s
                }

                CardGrid {
                    id: userGrid
                    visible: page.users.length > 0
                    presets: page.users
                }
            }
        }
    }

    component CardGrid: Item {
        id: grid

        property var presets: []
        readonly property real gap: 12 * page.s
        readonly property int cols: Math.max(1, Math.min(3, Math.floor((width + gap) / (220 * page.s + gap))))
        readonly property real cardW: Math.floor((width - (cols - 1) * gap) / cols)

        width: parent ? parent.width : 0
        implicitHeight: flow.implicitHeight

        Flow {
            id: flow
            width: parent.width
            spacing: grid.gap

            Repeater {
                model: grid.presets

                PresetsCard {
                    id: card
                    required property var modelData
                    width: grid.cardW
                    s: page.s
                    name: card.modelData.name
                    desc: card.modelData.desc
                    values: card.modelData.values
                    user: card.modelData.user
                    status: page.statusOf(card.modelData.id)
                    onApply: page.applyPreset(card.modelData)
                    onRenamed: (n) => store.rename(card.modelData.id, n)
                    onRemoved: {
                        const n = card.modelData.name;
                        store.remove(card.modelData.id);
                        App.toast("Deleted " + n);
                    }
                }
            }
        }
    }
}
