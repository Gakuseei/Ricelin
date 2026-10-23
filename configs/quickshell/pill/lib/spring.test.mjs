import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { step } = require("./spring.js");

let failed = 0;
function ok(cond, msg) {
    if (cond) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg); }
}

function run(x, v, w, z, dt, n) {
    let peak = 0;
    for (let i = 0; i < n; i++) {
        [x, v] = step(x, v, w, z, dt);
        peak = Math.max(peak, x);
    }
    return { x, v, peak };
}

const w = 2 * Math.PI / 0.4;
for (const z of [0.82, 1, 1.3]) {
    const r = run(-300, 0, w, z, 1 / 144, 144);
    ok(Math.abs(r.x) < 0.5 && Math.abs(r.v) < 5, `z=${z} settles within a second`);
}
ok(run(-300, 0, w, 0.82, 1 / 144, 144).peak > 1, "underdamped overshoots");
ok(run(-300, 0, w, 1, 1 / 144, 144).peak <= 0, "critical damping never overshoots");

const a = run(-300, 0, w, 0.82, 1 / 60, 30);
const b = run(-300, 0, w, 0.82, 1 / 240, 120);
ok(Math.abs(a.x - b.x) < 1e-6, "same path at 60 and 240 Hz");

const [x1, v1] = step(0, 1000, w, 1, 1 / 240);
ok(x1 > 0 && v1 > 0 && v1 < 1000, "carries velocity into a retarget");

process.exit(failed ? 1 : 0);
