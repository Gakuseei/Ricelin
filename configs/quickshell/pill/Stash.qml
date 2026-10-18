pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 蔵 STASH surface: the window classes that auto-route into the special:stash
 * space (SUPER+S), read from and written back to
 * ~/.config/hypr/modules/stash-apps.lua. Two views share one surface. The list
 * view shows each stashed class as an app tile, friendly name and faint raw-class
 * subtitle, with a ✕ to drop it, capped by a dashed "add app" bar. The add view
 * swaps in a fuzzy app search (the launcher's picker) whose pick derives a window
 * class from the entry's StartupWMClass, appends it and folds back to the list.
 *
 * Every add or remove regenerates the whole lua file through an atomic writer;
 * the write fires a debounced `hyprctl reload` so the new routing takes effect,
 * exactly as the keybinds editor reloads its binds.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    readonly property string stashPath: Quickshell.env("HOME") + "/.config/hypr/modules/stash-apps.lua"

    property var entries: []

    /** Pill.qml folds the picker back when the surface leaves */
    readonly property alias addOpen: content.addOpen
    function closeAdd() { content.closeAdd(); }

    readonly property string header:
        "-- Window classes that auto-route into the special:stash space (SUPER+S).\n"
        + "-- The Settings rewrite this list, so keep it a plain array of strings.\n"

    function parse(text) {
        var ri = text.indexOf("return {");
        var body = ri >= 0 ? text.slice(ri + 8) : text;
        var out = [];
        var re = /"([^"]*)"/g;
        var m;
        while ((m = re.exec(body)) !== null)
            if (m[1].length > 0)
                out.push(m[1]);
        return out;
    }

    function refresh() {
        root.entries = root.parse(stashFile.text());
    }

    function fileText(arr) {
        var body = "return {\n";
        for (var i = 0; i < arr.length; i++)
            body += "\t\"" + arr[i] + "\",\n";
        body += "}\n";
        return root.header + body;
    }

    function commit(arr) {
        writer.setText(root.fileText(arr));
    }

    function removeAt(i) {
        if (i < 0 || i >= root.entries.length)
            return;
        var next = root.entries.slice();
        next.splice(i, 1);
        root.commit(next);
    }

    function addClass(cls) {
        if (!cls || cls.length === 0)
            return;
        var want = content.normalizeClass(cls);
        for (var i = 0; i < root.entries.length; i++)
            if (content.normalizeClass(root.entries[i]) === want) {
                content.closeAdd();
                return;
            }
        var next = root.entries.slice();
        next.push(cls);
        root.commit(next);
        content.closeAdd();
    }

    onActiveChanged: {
        if (active) {
            stashFile.reload();
            refresh();
        }
        content.closeAdd();
    }

    ameForm: "off"

    FileView {
        id: stashFile
        path: root.stashPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    FileView {
        id: writer
        path: root.stashPath
        atomicWrites: true
        printErrors: false
        onSaved: {
            reloadProc.running = true;
            stashFile.reload();
            root.refresh();
        }
        onSaveFailed: (err) => console.log("stash: write failed: " + err)
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    AppRouteList {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        glyph: "蔵"
        title: "STASH"
        emptyText: "No apps stashed yet"
        entries: root.entries
        onRemoved: (i) => root.removeAt(i)
        onPicked: (entry) => root.addClass(entry.startupClass || entry.id)
    }
}
