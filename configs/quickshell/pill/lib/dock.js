.pragma library

/*
 * What the dock shows: pinned apps first, then every other running app, with
 * each app's windows grouped under it.
 *
 * Pure functions on plain objects, so the rules can be unit-tested without
 * Quickshell (tests/test_dock.js). The Dock singleton feeds them:
 *
 *   entries  [{ id, name, icon, startupClass }]            installed desktop entries
 *   windows  [{ address, cls, title, workspace }]          Hyprland clients
 *   pinned   ["org.kde.dolphin", ...]                      desktop entry ids, in dock order
 *
 * An item looks like:
 *   { key, id, name, icon, cls, pinned, windows: [...], running, active, minimized }
 * `icon` is a desktop entry's icon name; for a window with no matching entry it
 * is empty and `cls` (the window class) is what the caller tries as an icon name.
 */

function lower(v) {
    return String(v === undefined || v === null ? "" : v).toLowerCase();
}

/** Desktop entry ids come with or without ".desktop"; compare them without. */
function norm(id) {
    var s = lower(id);
    return s.slice(-8) === ".desktop" ? s.slice(0, -8) : s;
}

function lastSegment(id) {
    var s = norm(id);
    var i = s.lastIndexOf(".");
    return i >= 0 ? s.slice(i + 1) : s;
}

function findById(entries, id) {
    var want = norm(id);
    for (var i = 0; i < (entries ? entries.length : 0); i++)
        if (entries[i] && norm(entries[i].id) === want)
            return entries[i];
    return null;
}

/**
 * The desktop entry a window class belongs to. Window classes rarely equal the
 * entry id exactly (a Dolphin window is "org.kde.dolphin" or just "dolphin"), so
 * the rules run strictest first and each rule scans every entry before the next
 * one is tried: an exact id always beats a looser match.
 */
function matchEntry(cls, entries) {
    var c = norm(cls);
    if (c.length === 0 || !entries)
        return null;
    var rules = [
        function (e) { return norm(e.id) === c; },
        function (e) { return lower(e.startupClass) === c || norm(e.startupClass) === c; },
        function (e) { return lastSegment(e.id) === c; },
        function (e) { return lower(e.name) === c; }
    ];
    for (var r = 0; r < rules.length; r++)
        for (var i = 0; i < entries.length; i++)
            if (entries[i] && entries[i].id && rules[r](entries[i]))
                return entries[i];
    return null;
}

function isMinimized(w) {
    return String(w && w.workspace || "") === "special:minimized";
}

/**
 * Dock order: pinned apps in pinned order (hidden while their entry is not
 * installed and they are not running), then the other running apps in the order
 * their first window appears.
 */
function build(pinned, windows, entries, activeAddress) {
    var items = [];
    var index = {};

    for (var p = 0; p < (pinned ? pinned.length : 0); p++) {
        var entry = findById(entries, pinned[p]);
        var pk = norm(entry ? entry.id : pinned[p]);
        if (index[pk] !== undefined)
            continue;
        index[pk] = items.length;
        items.push({
            key: pk,
            id: entry ? entry.id : String(pinned[p]),
            name: entry ? entry.name : String(pinned[p]),
            icon: entry ? entry.icon || "" : "",
            cls: "",
            pinned: true,
            installed: entry !== null,
            windows: []
        });
    }

    for (var w = 0; w < (windows ? windows.length : 0); w++) {
        var win = windows[w];
        if (!win || !win.cls)
            continue;
        var e = matchEntry(win.cls, entries);
        var k = norm(e ? e.id : win.cls);
        var at = index[k];
        if (at === undefined) {
            at = items.length;
            index[k] = at;
            items.push({
                key: k,
                id: e ? e.id : String(win.cls),
                name: e ? e.name : String(win.cls),
                icon: e ? e.icon || "" : "",
                cls: String(win.cls),
                pinned: false,
                installed: e !== null,
                windows: []
            });
        }
        if (!items[at].cls)
            items[at].cls = String(win.cls);
        items[at].windows.push(win);
    }

    var out = [];
    for (var i = 0; i < items.length; i++) {
        var it = items[i];
        if (it.windows.length === 0 && !it.installed)
            continue;
        it.running = it.windows.length;
        it.active = false;
        var live = 0;
        for (var j = 0; j < it.windows.length; j++) {
            if (activeAddress && it.windows[j].address === activeAddress)
                it.active = true;
            if (!isMinimized(it.windows[j]))
                live++;
        }
        it.minimized = it.windows.length > 0 && live === 0;
        out.push(it);
    }
    return out;
}

/**
 * The window a click should bring forward. With no focused window of this app it
 * is the first one (a visible one before a minimized one); with one focused it is
 * the next, so repeated clicks walk through the app's windows. Null when the app
 * has none, which means "launch it".
 */
function nextWindow(item, activeAddress) {
    var ws = item && item.windows ? item.windows : [];
    if (ws.length === 0)
        return null;
    var at = -1;
    for (var i = 0; i < ws.length; i++)
        if (activeAddress && ws[i].address === activeAddress)
            at = i;
    if (at >= 0)
        return ws[(at + 1) % ws.length];
    for (var j = 0; j < ws.length; j++)
        if (!isMinimized(ws[j]))
            return ws[j];
    return ws[0];
}

/** Pinned list with `id` added at the end, or removed if already there. */
function togglePin(pinned, id) {
    var want = norm(id);
    var out = [];
    var found = false;
    for (var i = 0; i < (pinned ? pinned.length : 0); i++) {
        if (norm(pinned[i]) === want)
            found = true;
        else
            out.push(pinned[i]);
    }
    if (!found)
        out.push(id);
    return out;
}

/** Move the pinned entry at `from` to `to`; out-of-range moves return the list unchanged. */
function movePin(pinned, from, to) {
    var out = pinned ? pinned.slice() : [];
    if (from < 0 || from >= out.length || to < 0 || to >= out.length || from === to)
        return out;
    out.splice(to, 0, out.splice(from, 1)[0]);
    return out;
}
