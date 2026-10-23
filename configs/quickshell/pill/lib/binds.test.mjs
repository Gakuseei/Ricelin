import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const b = require("./binds.js");

let failed = 0;
function ok(cond, msg) {
    if (cond) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg); }
}

const base = 'local mod = "SUPER"\nhl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))\n';
let r = b.add(base, "SUPER + N", 'notify-send "1) done"', "note");
ok(r.ok, "add a bind whose command has quotes and a paren");
let entries = b.parse(r.text);
const note = entries.find(e => e.combo === "SUPER + N");
ok(note && b.execCmd(note.action) === 'notify-send "1) done"', "parse reads the escaped command back");

r = b.editCmd(r.text, note.lineIndex, 'notify-send "2) (again)"');
ok(r.ok, "edit that bind");
entries = b.parse(r.text);
ok(entries.length === 2, "both binds survive the edit");
ok(r.text.split("\n").every(l => !l.startsWith("hl.bind") || b.balanceOk(l)), "every bind line stays balanced");
ok(b.execCmd(entries[1].action) === 'notify-send "2) (again)"', "edited command round-trips");

r = b.rebind(r.text, note.lineIndex, "SUPER + M");
ok(r.ok && b.parse(r.text).some(e => e.combo === "SUPER + M"), "rebind past an escaped string");
ok(!b.balanceOk('hl.dsp.exec_cmd("open'), "unterminated string is unbalanced");

process.exit(failed ? 1 : 0);
