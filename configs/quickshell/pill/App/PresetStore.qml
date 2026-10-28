import QtQuick
import Quickshell
import Quickshell.Io

/** Saved presets in presets.json beside flags.json: `user` [{ id, name, values }] and the `active` preset id, written atomically. */
Item {
    id: store

    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/presets.json"
    property var data: ({ active: "", user: [] })
    readonly property var user: Array.isArray(data.user) ? data.user : []
    readonly property string active: typeof data.active === "string" ? data.active : ""

    function parse() {
        try {
            const d = JSON.parse(file.text());
            data = (d && typeof d === "object") ? d : ({ active: "", user: [] });
        } catch (e) {
            data = { active: "", user: [] };
        }
    }

    function commit(d) {
        data = d;
        file.setText(JSON.stringify(d, null, 2) + "\n");
    }

    function copy() {
        return { active: active, user: JSON.parse(JSON.stringify(user)) };
    }

    function setActive(id) {
        if (id === active)
            return;
        const d = copy();
        d.active = id;
        commit(d);
    }

    /** Saving under a name that already exists replaces that preset; returns the id. */
    function save(name, values) {
        const d = copy();
        const lo = name.toLowerCase();
        let p = d.user.find(x => String(x.name).toLowerCase() === lo);
        if (p) {
            p.values = values;
        } else {
            p = { id: "u" + Date.now().toString(36), name: name, values: values };
            d.user.push(p);
        }
        d.active = p.id;
        commit(d);
        return p.id;
    }

    function rename(id, name) {
        const d = copy();
        const p = d.user.find(x => x.id === id);
        if (!p || p.name === name)
            return;
        p.name = name;
        commit(d);
    }

    function remove(id) {
        const d = copy();
        d.user = d.user.filter(x => x.id !== id);
        if (d.active === id)
            d.active = "";
        commit(d);
    }

    FileView {
        id: file
        path: store.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: store.parse()
    }
}
