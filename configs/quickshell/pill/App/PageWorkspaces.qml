pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "workspaces"

    readonly property string stashPath: Quickshell.env("HOME") + "/.config/hypr/modules/stash-apps.lua"
    property var stashEntries: []
    /** Space whose form is open, "new" for the create form, "" for none. */
    property string editId: ""
    /** Space whose app list fills the page, "" for the overview. */
    property string detailId: ""
    property string formError: ""

    readonly property var glyphChoices: ["layers", "lock", "sparkles", "app-window", "waves", "moon", "sun", "palette", "mic", "speaker"]
    readonly property var builtins: [
        { id: "stash", name: "Stash", combo: "Super + S", note: "Background apps open here", glyph: "layers" },
        { id: "private", name: "Private", combo: "Super + P", note: "A hidden scratchpad", glyph: "lock" },
        { id: "minimized", name: "Minimized", combo: "Super + Shift + M", note: "Minimized windows wait here", glyph: "minimize" }
    ]

    readonly property string stashHeader: "-- Window classes that auto-route into the special:stash space (SUPER+S).\n"
        + "-- The Settings rewrite this list, so keep it a plain array of strings.\n"

    readonly property var spaces: {
        const sl = Spaces.list;
        const over = {};
        for (let i = 0; i < sl.length; i++)
            if (Spaces.reserved(sl[i].id))
                over[sl[i].id] = sl[i];
        const out = builtins.map(b => {
            const e = over[b.id];
            return {
                id: b.id, builtin: true, name: e && e.name ? e.name : b.name, note: b.note, combo: b.combo,
                glyph: e && glyphChoices.indexOf(e.glyph) >= 0 ? e.glyph : b.glyph,
                desc: "", key: "", apps: b.id === "stash" ? stashEntries : [], appsEditable: b.id === "stash"
            };
        });
        for (let i = 0; i < sl.length; i++) {
            const c = sl[i];
            if (Spaces.reserved(c.id))
                continue;
            out.push({
                id: c.id, builtin: false, name: c.name, note: c.desc || "Custom space", combo: c.key ? "Super + " + c.key : "",
                glyph: c.glyph || "", desc: c.desc || "", key: c.key || "", apps: c.apps || [], appsEditable: true
            });
        }
        return out;
    }
    readonly property var detail: spaces.find(x => x.id === detailId) || null

    function reveal(key) {
        if (key === "workspaces.stashApps") {
            openApps("stash");
            return true;
        }
        detailId = "";
        const row = rowMap[key];
        if (!row)
            return false;
        if (App.shell)
            App.shell.scrollToItem(row, true);
        return true;
    }

    function openForm(id) {
        formError = "";
        editId = editId === id ? "" : id;
    }

    function cancel(outside) {
        if (outside || editId.length === 0)
            return false;
        closeForm();
        return true;
    }

    function closeForm() {
        formError = "";
        editId = "";
    }

    function openApps(id) {
        closeForm();
        detailId = id;
        if (App.shell)
            App.shell.scrollToItem(page, false);
    }

    function copyList() {
        return Spaces.list.map(e => Object.assign({}, e));
    }

    function saveSpace(sp, f) {
        const name = Spaces.clean(f.name);
        if (name.length === 0) {
            formError = "Name is empty";
            return;
        }
        if (!sp.builtin) {
            if (!/^[A-Z]$/.test(f.key)) {
                formError = "Pick a key";
                return;
            }
            if (Spaces.keyTaken(f.key, sp.id)) {
                formError = "Super + " + f.key + " is already in use";
                return;
            }
        }
        const next = copyList();
        const i = next.findIndex(e => e.id === sp.id);
        const glyph = Spaces.clean(f.glyph);
        if (i >= 0) {
            next[i].name = name;
            next[i].glyph = glyph;
            if (!sp.builtin) {
                next[i].desc = Spaces.clean(f.desc);
                next[i].key = f.key;
            }
        } else if (sp.builtin) {
            next.push({ id: sp.id, name: name, desc: "", key: "", glyph: glyph, apps: [] });
        } else {
            return;
        }
        Spaces.commit(next);
        closeForm();
        App.toast(name + " saved");
    }

    function createSpace(f) {
        const name = Spaces.clean(f.name);
        const id = Spaces.slug(name);
        if (name.length === 0) {
            formError = "Name is empty";
        } else if (id.length === 0) {
            formError = "Name needs a letter or a digit";
        } else if (Spaces.reserved(id)) {
            formError = "Name " + name + " belongs to a built-in space";
        } else if (Spaces.list.some(e => e.id === id)) {
            formError = "Name " + name + " is taken";
        } else if (!/^[A-Z]$/.test(f.key)) {
            formError = "Pick a key";
        } else if (Spaces.keyTaken(f.key, "")) {
            formError = "Super + " + f.key + " is already in use";
        } else {
            const next = copyList();
            next.push({ id: id, name: name, desc: Spaces.clean(f.desc), key: f.key, glyph: Spaces.clean(f.glyph), apps: [] });
            Spaces.commit(next);
            closeForm();
            App.toast(name + " created. Edit it to add apps");
        }
    }

    function removeSpace(sp) {
        if (editId === sp.id)
            closeForm();
        Spaces.removeSpace(sp.id);
        App.toast(sp.name + " removed. Undo brings it back");
    }

    function stashText(arr) {
        let body = "return {\n";
        for (let i = 0; i < arr.length; i++)
            body += "\t\"" + arr[i] + "\",\n";
        return stashHeader + body + "}\n";
    }

    function parseStash(text) {
        const ri = text.indexOf("return {");
        const body = ri >= 0 ? text.slice(ri + 8) : text;
        const out = [];
        const re = /"([^"]*)"/g;
        let m;
        while ((m = re.exec(body)) !== null)
            if (m[1].length > 0)
                out.push(m[1]);
        return out;
    }

    function writeStash(arr) {
        stashEntries = arr;
        stashWriter.put(stashText(arr));
    }

    function removeApp(sp, i) {
        if (sp.id === "stash") {
            const next = stashEntries.slice();
            next.splice(i, 1);
            writeStash(next);
        } else {
            Spaces.removeApp(sp.id, sp.apps[i]);
        }
    }

    function addApp(sp, cls) {
        cls = Spaces.clean(cls);
        if (cls.length === 0)
            return;
        if (sp.id === "stash")
            writeStash(stashEntries.concat([cls]));
        else
            Spaces.addApp(sp.id, cls);
    }

    /** Built-in names and glyphs go back to the shipped ones; custom spaces and app lists are yours and stay. */
    function reset() {
        const keep = copyList().filter(e => !Spaces.reserved(e.id));
        const base = builtins.map(b => ({ id: b.id, name: b.name, desc: "", key: "", glyph: b.glyph, apps: [] }));
        Spaces.commit(base.concat(keep));
        closeForm();
        detailId = "";
    }

    FileView {
        id: stashFile
        path: page.stashPath
        watchChanges: true
        printErrors: false
        onLoaded: page.stashEntries = page.parseStash(text())
        onFileChanged: reload()
    }

    Writer {
        id: stashWriter
        path: page.stashPath
        onWritten: HyprReload.request()
    }

    /** Atomic writer that keeps one write in flight, so a quick second edit can never land before the first. */
    component Writer: FileView {
        property string queued: ""
        property bool busy: false
        property bool more: false
        signal written()
        preload: false
        atomicWrites: true
        printErrors: false
        function put(t) {
            if (busy) {
                queued = t;
                more = true;
                return;
            }
            busy = true;
            setText(t);
        }
        function settle() {
            busy = false;
            if (more) {
                more = false;
                put(queued);
            } else {
                written();
            }
        }
        onSaved: Qt.callLater(settle)
        onSaveFailed: Qt.callLater(settle)
    }

    AppGroup {
        title: "Special spaces"
        hint: "Super plus the key opens a space, Super Shift sends a window there"
        visible: page.detailId.length === 0

        Repeater {
            model: page.spaces

            PageWorkspacesSpace {
                id: sp
                required property var modelData
                required property int index
                space: modelData
                key: "workspaces." + modelData.id
                first: index === 0
                editing: page.editId === modelData.id
                onEdit: page.openForm(modelData.id)
                onRemove: page.removeSpace(modelData)
                editor: Component {
                    PageWorkspacesForm {
                        mode: sp.space.builtin ? "builtin" : "custom"
                        spaceId: sp.space.id
                        name: sp.space.name
                        desc: sp.space.desc
                        key: sp.space.key
                        glyph: sp.space.glyph
                        appCount: sp.space.apps.length
                        appsEditable: sp.space.appsEditable
                        error: page.formError
                        onSubmitted: (f) => page.saveSpace(sp.space, f)
                        onCancelled: page.closeForm()
                        onManageApps: page.openApps(sp.space.id)
                        Component.onCompleted: focusName()
                    }
                }
            }
        }

        AppRow {
            label: "New space"
            sub: "A name, a Super key and a glyph. Apps come after"
            key: "workspaces.add"
            visible: page.editId !== "new"
            AppButton {
                icon: "sparkles"
                text: "Add space"
                onClicked: page.openForm("new")
            }
        }

        Item {
            width: parent.width
            visible: page.editId === "new"
            height: visible && newForm.item ? newForm.y + newForm.item.implicitHeight + 12 * page.s : 0

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 8 * page.s
                radius: 9 * page.s
                color: Theme.frameBg
            }
            Text {
                x: 12 * page.s
                y: 22 * page.s
                text: "New space"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * page.s
                font.weight: Font.Medium
            }
            Loader {
                id: newForm
                x: 58 * page.s
                y: 52 * page.s
                width: parent.width - x - 12 * page.s
                active: page.editId === "new"
                sourceComponent: PageWorkspacesForm {
                    mode: "new"
                    error: page.formError
                    appsEditable: true
                    onSubmitted: (f) => page.createSpace(f)
                    onCancelled: page.closeForm()
                    Component.onCompleted: focusName()
                }
            }
        }
    }

    AppGroup {
        visible: page.detail !== null

        PageWorkspacesApps {
            title: page.detail ? page.detail.name : ""
            combo: page.detail ? page.detail.combo : ""
            entries: page.detail ? page.detail.apps : []
            onBack: page.detailId = ""
            onRemoved: (i) => page.removeApp(page.detail, i)
            onAdded: (cls) => page.addApp(page.detail, cls)
        }
    }
}
