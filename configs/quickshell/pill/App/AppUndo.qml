pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

/** Snapshot of flags and the Hyprland files pages write, taken when the app opens; `revert()` puts every changed one back and reloads what needs it. */
Item {
    id: root

    property bool changed: false
    property var openFlags: ({})
    signal reverted()

    readonly property string hypr: Quickshell.env("HOME") + "/.config/hypr/"
    readonly property string flagsPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/flags.json"

    /** Runtime toggles and the app's own zoom, not settings: Undo leaves them alone. */
    readonly property var sessionKeys: ["appZoom", "dnd", "keepAwake", "gameMode", "gamePrevDnd", "gamePrevViz", "gamePrevAwake", "gamePrevProfile", "recordClearedBefore"]

    readonly property var files: [
        { path: hypr + "modules/decoration.lua", apply: "hypr" },
        { path: hypr + "modules/input.lua", apply: "hypr" },
        { path: hypr + "modules/env.lua", apply: "hypr" },
        { path: hypr + "modules/autostart.lua", apply: "hypr" },
        { path: hypr + "modules/animations.lua", apply: "hypr" },
        { path: hypr + "modules/binds.lua", apply: "hypr" },
        { path: hypr + "modules/spaces.lua", apply: "hypr" },
        { path: hypr + "modules/stash-apps.lua", apply: "hypr" },
        { path: hypr + "hypridle.conf", apply: "hypridle" },
        { path: hypr + "hyprsunset.conf", apply: "hyprsunset" }
    ]

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function flagKeys() {
        const skip = ["objectName", "reloadableId", "children", "data", "resources"].concat(sessionKeys);
        const out = [];
        for (const k in Flags) {
            if (skip.indexOf(k) < 0 && typeof Flags[k] !== "function")
                out.push(k);
        }
        return out;
    }

    /** Every flag explicitly: the file's value where it has one, else what Flags holds in memory. */
    function snapshotFlags() {
        let file = {};
        try {
            file = JSON.parse(flagsView.text()) || {};
        } catch (e) {
            file = {};
        }
        const o = {};
        const keys = flagKeys();
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            const v = file.hasOwnProperty(k) ? file[k] : Flags[k];
            o[k] = JSON.parse(JSON.stringify(v === undefined ? null : v));
        }
        openFlags = o;
    }

    function flagsDiffer() {
        let cur = null;
        try {
            cur = JSON.parse(flagsView.text());
        } catch (e) {
            return false;
        }
        for (const k in cur) {
            if (openFlags.hasOwnProperty(k) && !same(cur[k], openFlags[k]))
                return true;
        }
        return false;
    }

    function check() {
        let c = flagsDiffer();
        for (let i = 0; !c && i < views.count; i++) {
            const v = views.objectAt(i);
            if (v && v.differs())
                c = true;
        }
        changed = c;
    }

    function revert() {
        changed = false;
        for (const k in openFlags) {
            if (!same(Flags[k], openFlags[k]))
                Flags[k] = JSON.parse(JSON.stringify(openFlags[k]));
        }
        const need = {};
        for (let i = 0; i < views.count; i++) {
            const v = views.objectAt(i);
            if (v && v.differs()) {
                v.restore();
                need[v.apply] = true;
            }
        }
        if (need.hypr)
            HyprReload.request();
        if (need.hypridle)
            Quickshell.execDetached(["systemctl", "--user", "restart", "hypridle"]);
        if (need.hyprsunset)
            Quickshell.execDetached(["systemctl", "--user", "restart", "hyprsunset"]);
        settle.restart();
        reverted();
    }

    Component.onCompleted: {
        snapshotFlags();
        check();
    }

    /** Re-checks once the restored writes have landed, so a change made in the same breath still counts. */
    Timer {
        id: settle
        interval: 600
        onTriggered: root.check()
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.check()
    }

    FileView {
        id: flagsView
        path: root.flagsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: debounce.restart()
    }

    Instantiator {
        id: views
        model: root.files

        FileView {
            id: view
            required property var modelData
            readonly property string apply: modelData.apply
            property var base: null
            property bool failed: false

            function differs() {
                return base !== null && !failed && text() !== base;
            }

            function restore() {
                setText(base);
            }

            path: modelData.path
            blockLoading: true
            watchChanges: true
            atomicWrites: true
            printErrors: false
            onFileChanged: reload()
            onLoadFailed: failed = true
            onLoaded: {
                failed = false;
                if (base !== null)
                    debounce.restart();
            }
            Component.onCompleted: {
                const t = text();
                base = failed ? null : t;
            }
        }
    }
}
