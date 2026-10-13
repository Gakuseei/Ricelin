pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../lib/dock.js" as DockLib

/**
 * State behind the dock: which apps are pinned, which windows are
 * open, and what a click on an app should do.
 *
 * The grouping rules live in lib/dock.js (unit-tested without Quickshell); this
 * file only feeds it live data (desktop entries, Hyprland clients) and carries
 * out the result. Pins are the only thing stored, in
 * ~/.config/ricelin/dock.json, as desktop entry ids:
 *
 *   { "pinned": ["com.mitchellh.ghostty", "org.kde.dolphin"], "reserve": true, "side": "right" }
 *
 * `reserve` keeps tiled windows clear of the dock; set it to false to let the
 * dock float over them. `side` is "right" (the default) or "left".
 *
 * `pinned` is always replaced, never changed in place, so every binding that
 * reads it refreshes.
 */
Singleton {
    id: root

    property bool ready: false
    property var pinned: []
    /** True: windows tile around the dock. False: the dock floats over them. */
    property bool reserve: true
    /** "right" or "left": which screen edge the dock sits on. */
    property string side: "right"
    readonly property bool onRight: root.side !== "left"

    /**
     * The capsule's geometry in unscaled pixels (multiply by the screen's scale).
     * DockBody draws from these and the blade fan reads `footprintPx` to keep its
     * corner clear of the dock, so the two cannot drift apart.
     */
    readonly property real edgePx: 10
    readonly property real tilePx: 44
    readonly property real padPx: 9
    /** Screen edge to the capsule's far side. */
    readonly property real footprintPx: edgePx + tilePx + 2 * padPx

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ricelin"
    readonly property string path: root.dir + "/dock.json"

    /** Offered on a first run. An app that is not installed is simply not shown. */
    readonly property var defaultPins: ["com.mitchellh.ghostty", "org.kde.dolphin", "firefox"]

    readonly property string guardScript: Quickshell.env("HOME") + "/.config/hypr/scripts/launch-guard.sh"

    /** Installed, visible desktop entries as plain records for lib/dock.js. */
    readonly property var entries: {
        var src = DesktopEntries.applications.values || [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var e = src[i];
            if (e && e.id && !e.noDisplay)
                out.push({ id: e.id, name: e.name || e.id, icon: e.icon || "", startupClass: e.startupClass || "" });
        }
        return out;
    }

    function hex(addr) {
        var a = String(addr || "");
        return a.length > 0 && a.indexOf("0x") !== 0 ? "0x" + a : a;
    }

    /** Hyprland clients as plain records for lib/dock.js. */
    readonly property var windows: {
        var out = [];
        var tl = Hyprland.toplevels.values || [];
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            if (!t)
                continue;
            var o = t.lastIpcObject;
            var cls = o && o.class ? o.class : (t.wayland && t.wayland.appId ? t.wayland.appId : "");
            out.push({
                address: root.hex(t.address),
                cls: cls,
                title: t.title || (o && o.title ? o.title : ""),
                workspace: t.workspace ? t.workspace.name : ""
            });
        }
        return out;
    }

    readonly property string activeAddress: {
        var t = Hyprland.activeToplevel;
        return t && t.address ? root.hex(t.address) : "";
    }

    readonly property var items: DockLib.build(root.pinned, root.windows, root.entries, root.activeAddress)

    function isPinned(item) {
        return !!item && item.pinned;
    }

    function togglePin(item) {
        if (!item)
            return;
        root.pinned = DockLib.togglePin(root.pinned, item.id);
        root.persist();
    }

    function movePin(from, to) {
        root.pinned = DockLib.movePin(root.pinned, from, to);
        root.persist();
    }

    /** The live DesktopEntry object for an item (the plain records above cannot start anything). */
    function entryFor(item) {
        if (!item || !item.installed)
            return null;
        var src = DesktopEntries.applications.values || [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && src[i].id === item.id)
                return src[i];
        return null;
    }

    /** Start a fresh instance of the app (also what a click does when nothing is open). */
    function launch(item) {
        var entry = root.entryFor(item);
        if (!entry)
            return;
        // Same guard the launcher uses: an app that dies on startup toasts its stderr.
        if (!entry.command || entry.command.length === 0) {
            entry.execute();
            return;
        }
        Quickshell.execDetached(["bash", root.guardScript, entry.name, entry.icon || "", entry.workingDirectory || ""].concat(entry.command));
    }

    /** Workspace a minimized window is brought back to: the one showing on `screenName`. */
    function restoreWorkspace(screenName) {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === screenName && ms[i].activeWorkspace)
                return ms[i].activeWorkspace.id;
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
    }

    /** Click on an app: bring its next window forward, or start it if it has none. */
    function activate(item, screenName) {
        var w = DockLib.nextWindow(item, root.activeAddress);
        if (!w) {
            root.launch(item);
            return;
        }
        if (w.workspace === "special:minimized")
            Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + root.restoreWorkspace(screenName) + ', window = "address:' + w.address + '" })');
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + w.address + '" })');
    }

    function persist() {
        if (!root.ready)
            return;
        store.setText(JSON.stringify({ pinned: root.pinned, reserve: root.reserve, side: root.side }, null, 2));
    }

    /** Receives the raw text of an unparsable dock.json before the defaults replace it. */
    FileView {
        id: brokenStore
        path: root.path + ".broken"
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: store
        path: root.path
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    /** `~/.config/ricelin` may not exist yet; the first load waits for this to exit before touching the store. */
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.dir]
        onExited: root.load()
    }

    function load() {
        var raw = "";
        try {
            raw = store.text();
        } catch (e) {
            raw = "";
        }
        if (raw && raw.length > 0) {
            try {
                var data = JSON.parse(raw);
                root.pinned = Array.isArray(data.pinned) ? data.pinned.map(String) : [];
                root.reserve = data.reserve !== false;
                root.side = data.side === "left" ? "left" : "right";
                root.ready = true;
                return;
            } catch (e) {
                console.warn("Dock: dock.json failed to parse, keeping it as dock.json.broken:", e);
                brokenStore.setText(raw);
            }
        }
        root.pinned = root.defaultPins.slice();
        root.ready = true;
        root.persist();
    }

    Component.onCompleted: mkdirProc.running = true
}
