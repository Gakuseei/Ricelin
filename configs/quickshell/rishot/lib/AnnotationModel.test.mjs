import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { create } = require("./AnnotationModel.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        console.log("PASS " + msg);
    } else {
        failed++;
        console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a);
    }
}

const r = { type: "rect", points: [{ x: 10, y: 10 }, { x: 50, y: 40 }], color: "#e0563b", width: 3 };
const r2 = { type: "rect", points: [{ x: 0, y: 0 }, { x: 5, y: 5 }], color: "#e0563b", width: 3 };

const m = create();
eq(m.items.length, 0, "starts empty");
eq([m.canUndo(), m.canRedo()], [false, false], "no undo/redo at start");

m.add(r);
eq(m.items.length, 1, "add appends one");
eq(m.canUndo(), true, "can undo after add");

m.add(r2);
eq(m.items.length, 2, "add appends second");

m.undo();
eq(m.items.length, 1, "undo removes last");
eq(m.items[0].type, "rect", "remaining item intact");
eq(m.canRedo(), true, "can redo after undo");

m.redo();
eq(m.items.length, 2, "redo re-applies");
eq(m.items[1].points[1].x, 5, "redone item is the right one");

m.undo();
m.add(r);
eq(m.canRedo(), false, "add clears redo stack");
eq(m.items.length, 2, "add-after-undo count correct");

m.undo(); m.undo(); m.undo();
eq(m.items.length, 0, "undo to empty");
eq(m.undo(), false, "undo past bottom is false");

if (failed > 0) {
    console.log("\n" + failed + " test(s) FAILED");
    process.exit(1);
}
console.log("\nAll tests PASSED");
