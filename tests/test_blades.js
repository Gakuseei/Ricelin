// Self-check for configs/quickshell/pill/lib/blades.js. The file is a QML
// `.pragma library`, so the pragma line is stripped and the rest runs in a vm.
// Run: node tests/test_blades.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const file = path.join(__dirname, "..", "configs", "quickshell", "pill", "lib", "blades.js");
const src = fs.readFileSync(file, "utf8").replace(/^\.pragma.*$/m, "");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);
const B = ctx;

let failed = 0;
function check(name, fn) {
    try { fn(); console.log("  ok   " + name); }
    catch (e) { failed++; console.log("  FAIL " + name + "\n         " + e.message); }
}
const rec = (o) => Object.assign({ id: "x", name: "X", category: "game", runner: "wine", favorite: false, lastLaunched: 0 }, o);
const names = (list) => list.map((a) => a.name).join(",");

console.log("eligible");
check("a game is in by default", () => assert.ok(B.eligible(rec({}))));
check("a Wine app that is not a game is in", () => assert.ok(B.eligible(rec({ category: "utility", runner: "wine" }))));
check("wine-staging, umu and steam count as Wine-family", () => {
    for (const r of ["wine-staging", "umu", "steam"])
        assert.ok(B.eligible(rec({ category: "utility", runner: r })), r);
});
check("a native utility is out", () => assert.ok(!B.eligible(rec({ category: "utility", runner: "native" }))));
check("a native game is in", () => assert.ok(B.eligible(rec({ category: "game", runner: "native" }))));
check("hide wins over everything", () => assert.ok(!B.eligible(rec({ blade: "hide", favorite: true }))));
check("pin brings in a native utility", () => assert.ok(B.eligible(rec({ category: "utility", runner: "native", blade: "pin" }))));
check("unknown blade values mean auto", () => assert.ok(B.eligible(rec({ blade: "banana" }))));
check("a record without an id is never listed", () => assert.ok(!B.eligible(rec({ id: "" }))));
check("null and undefined are tolerated", () => { assert.ok(!B.eligible(null)); assert.ok(!B.eligible(undefined)); });
check("case does not matter", () => assert.ok(B.eligible(rec({ category: "Game", runner: "WINE" }))));

console.log("order");
check("pinned, favorite, recent, then name", () => {
    const apps = [
        rec({ id: "a", name: "Alpha" }),
        rec({ id: "b", name: "Bravo", lastLaunched: 50 }),
        rec({ id: "c", name: "Charlie", favorite: true }),
        rec({ id: "d", name: "Delta", category: "utility", runner: "native", blade: "pin" }),
        rec({ id: "e", name: "Echo", lastLaunched: 90 }),
    ];
    assert.strictEqual(names(B.select(apps, 0)), "Delta,Charlie,Echo,Bravo,Alpha");
});
check("name order is case-insensitive", () => {
    const apps = [rec({ id: "1", name: "zeta" }), rec({ id: "2", name: "Alpha" })];
    assert.strictEqual(names(B.select(apps, 0)), "Alpha,zeta");
});

console.log("cap");
check("max keeps the first N in blade order", () => {
    const apps = ["A", "B", "C", "D"].map((n, i) => rec({ id: n, name: n, lastLaunched: i }));
    assert.strictEqual(names(B.select(apps, 2)), "D,C");
});
check("max 0 means no cap", () => {
    const apps = ["A", "B", "C"].map((n) => rec({ id: n, name: n }));
    assert.strictEqual(B.select(apps, 0).length, 3);
});
check("select does not reorder the caller's array", () => {
    const apps = [rec({ id: "z", name: "Z" }), rec({ id: "a", name: "A" })];
    B.select(apps, 0);
    assert.strictEqual(apps[0].name, "Z");
});
check("empty and missing lists give an empty list", () => {
    assert.strictEqual(B.select([], 6).length, 0);
    assert.strictEqual(B.select(null, 6).length, 0);
});

if (failed) { console.log("\n" + failed + " failed"); process.exit(1); }
console.log("\nall ok");
