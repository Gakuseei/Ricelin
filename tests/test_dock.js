// Self-check for configs/quickshell/pill/lib/dock.js. The file is a QML
// `.pragma library`, so the pragma line is stripped and the rest runs in a vm.
// Run: node tests/test_dock.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const file = path.join(__dirname, "..", "configs", "quickshell", "pill", "lib", "dock.js");
const src = fs.readFileSync(file, "utf8").replace(/^\.pragma.*$/m, "");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);
const D = ctx;

let failed = 0;
function check(name, fn) {
    try { fn(); console.log("  ok   " + name); }
    catch (e) { failed++; console.log("  FAIL " + name + "\n         " + e.message); }
}

const entries = [
    { id: "org.kde.dolphin", name: "Dolphin", icon: "system-file-manager", startupClass: "dolphin" },
    { id: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty", startupClass: "" },
    { id: "firefox", name: "Firefox", icon: "firefox", startupClass: "firefox" },
    { id: "steam", name: "Steam", icon: "steam", startupClass: "Steam" },
    { id: "org.gnome.Calculator", name: "Calculator", icon: "calc", startupClass: "" },
];
const win = (address, cls, workspace) => ({ address, cls, title: cls + " window", workspace: workspace || "1" });
// Arrays built inside the vm have a different prototype; compare them as JSON.
const same = (a, b) => assert.strictEqual(JSON.stringify(a), JSON.stringify(b));
const ids = (items) => items.map((i) => i.id).join(",");

console.log("matchEntry");
check("exact id", () => assert.strictEqual(D.matchEntry("firefox", entries).id, "firefox"));
check("id is case-insensitive", () => assert.strictEqual(D.matchEntry("Firefox", entries).id, "firefox"));
check("id with .desktop", () => assert.strictEqual(D.matchEntry("firefox.desktop", entries).id, "firefox"));
check("startup class", () => assert.strictEqual(D.matchEntry("Steam", entries).id, "steam"));
check("last segment of a reverse-DNS id", () => assert.strictEqual(D.matchEntry("ghostty", entries).id, "com.mitchellh.ghostty"));
check("full reverse-DNS class", () => assert.strictEqual(D.matchEntry("org.kde.dolphin", entries).id, "org.kde.dolphin"));
check("name as the last resort", () => assert.strictEqual(D.matchEntry("calculator", entries).id, "org.gnome.Calculator"));
check("an exact id beats a looser rule", () => {
    const e = [
        { id: "org.example.term", name: "Other", icon: "", startupClass: "" },
        { id: "term", name: "Term", icon: "", startupClass: "" },
    ];
    assert.strictEqual(D.matchEntry("term", e).id, "term");
});
check("no match, empty class and missing list give null", () => {
    assert.strictEqual(D.matchEntry("cyberpunk2077.exe", entries), null);
    assert.strictEqual(D.matchEntry("", entries), null);
    assert.strictEqual(D.matchEntry("x", null), null);
});

console.log("build");
check("pinned apps come first, in pinned order, even when not running", () => {
    const items = D.build(["firefox", "org.kde.dolphin"], [], entries, "");
    assert.strictEqual(ids(items), "firefox,org.kde.dolphin");
    assert.ok(items.every((i) => i.pinned && i.running === 0));
});
check("running unpinned apps follow, in first-window order", () => {
    const ws = [win("0x2", "steam"), win("0x1", "ghostty")];
    const items = D.build(["firefox"], ws, entries, "");
    assert.strictEqual(ids(items), "firefox,steam,com.mitchellh.ghostty");
    assert.ok(!items[1].pinned);
});
check("windows of one app are grouped under it", () => {
    const ws = [win("0x1", "firefox"), win("0x2", "dolphin"), win("0x3", "firefox")];
    const items = D.build(["firefox"], ws, entries, "");
    assert.strictEqual(items[0].running, 2);
    assert.strictEqual(items[1].running, 1);
});
check("a pinned app's windows attach to the pinned item", () => {
    const items = D.build(["org.kde.dolphin"], [win("0x1", "dolphin")], entries, "");
    assert.strictEqual(items.length, 1);
    assert.strictEqual(items[0].running, 1);
    assert.ok(items[0].pinned);
});
check("a window with no desktop entry gets its own item", () => {
    const items = D.build([], [win("0x9", "cyberpunk2077.exe")], entries, "");
    assert.strictEqual(items.length, 1);
    assert.strictEqual(items[0].id, "cyberpunk2077.exe");
    assert.strictEqual(items[0].icon, "");
    assert.strictEqual(items[0].cls, "cyberpunk2077.exe");
    assert.ok(!items[0].installed);
});
check("a pinned app that is not installed and not running is hidden", () => {
    const items = D.build(["gone-app", "firefox"], [], entries, "");
    assert.strictEqual(ids(items), "firefox");
});
check("a duplicate pin is listed once", () => {
    const items = D.build(["firefox", "Firefox.desktop"], [], entries, "");
    assert.strictEqual(items.length, 1);
});
check("the focused window marks its app active", () => {
    const ws = [win("0x1", "firefox"), win("0x2", "dolphin")];
    const items = D.build([], ws, entries, "0x2");
    assert.ok(!items[0].active);
    assert.ok(items[1].active);
});
check("an app with only minimized windows reads as minimized", () => {
    const items = D.build([], [win("0x1", "firefox", "special:minimized")], entries, "");
    assert.ok(items[0].minimized);
    const mixed = D.build([], [win("0x1", "firefox", "special:minimized"), win("0x2", "firefox", "2")], entries, "");
    assert.ok(!mixed[0].minimized);
});
check("windows without a class are ignored", () => {
    assert.strictEqual(D.build([], [win("0x1", "")], entries, "").length, 0);
});
check("null inputs give an empty dock", () => assert.strictEqual(D.build(null, null, null, "").length, 0));
check("build never changes the inputs", () => {
    const pinned = ["firefox"];
    const ws = [win("0x1", "firefox")];
    D.build(pinned, ws, entries, "");
    same(pinned, ["firefox"]);
    assert.strictEqual(ws.length, 1);
});

console.log("nextWindow");
check("none running means launch", () => assert.strictEqual(D.nextWindow({ windows: [] }, ""), null));
check("no focused window picks the first visible one", () => {
    const item = { windows: [win("0x1", "f", "special:minimized"), win("0x2", "f")] };
    assert.strictEqual(D.nextWindow(item, "").address, "0x2");
});
check("only minimized windows picks the first", () => {
    const item = { windows: [win("0x1", "f", "special:minimized")] };
    assert.strictEqual(D.nextWindow(item, "").address, "0x1");
});
check("repeated clicks walk through the windows and wrap", () => {
    const item = { windows: [win("0x1", "f"), win("0x2", "f"), win("0x3", "f")] };
    assert.strictEqual(D.nextWindow(item, "0x1").address, "0x2");
    assert.strictEqual(D.nextWindow(item, "0x3").address, "0x1");
});
check("a focus elsewhere starts from the first window", () => {
    const item = { windows: [win("0x1", "f"), win("0x2", "f")] };
    assert.strictEqual(D.nextWindow(item, "0x99").address, "0x1");
});

console.log("pins");
check("togglePin adds at the end", () => same(D.togglePin(["a"], "b"), ["a", "b"]));
check("togglePin removes an existing pin, ignoring case and .desktop", () => {
    same(D.togglePin(["a", "Firefox"], "firefox.desktop"), ["a"]);
});
check("togglePin leaves the caller's array alone", () => {
    const p = ["a"];
    D.togglePin(p, "b");
    same(p, ["a"]);
});
check("movePin reorders", () => same(D.movePin(["a", "b", "c"], 2, 0), ["c", "a", "b"]));
check("movePin ignores out-of-range and no-op moves", () => {
    same(D.movePin(["a", "b"], 5, 0), ["a", "b"]);
    same(D.movePin(["a", "b"], 1, 1), ["a", "b"]);
});

if (failed) { console.log("\n" + failed + " failed"); process.exit(1); }
console.log("\nall ok");
