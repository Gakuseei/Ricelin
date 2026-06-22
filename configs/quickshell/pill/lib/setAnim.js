/**
 * Read/write helpers for animations.lua, which is a list of `hl.curve(...)` and
 * `hl.animation({...})` calls plus a small `animations = { enabled = ... }` block
 * rather than a flat config table. Each setter returns `{ text, ok }`; ok is false
 * (text unchanged) when the target is absent, so a hand-trimmed file never throws.
 */

/** Reads the master `animations.enabled` flag as "true"/"false" (or "" if absent). */
function getEnabled(text) {
    var m = /animations\s*=\s*\{[^}]*?enabled\s*=\s*(\w+)/.exec(text);
    return m ? m[1] : "";
}

/** Flips `animations.enabled` to the literal "true"/"false". */
function setEnabled(text, literal) {
    var re = /(animations\s*=\s*\{[^}]*?enabled\s*=\s*)(\w+)/;
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + literal), ok: true };
}

/** Reads the `speed = N` of the named animation leaf (or "" if that leaf is absent). */
function getLeafSpeed(text, leaf) {
    var re = new RegExp("hl\\.animation\\(\\{[^}]*?leaf\\s*=\\s*\"" + leaf + "\"[^}]*?speed\\s*=\\s*([0-9.]+)");
    var m = re.exec(text);
    return m ? m[1] : "";
}

/**
 * Sets every animation leaf's `speed` to `literal`. Only `hl.animation` lines
 * carry a `speed =` field, so a blanket replace stays scoped to them. Returns the
 * count of leaves touched alongside the new text.
 */
function setAllSpeeds(text, literal) {
    var n = 0;
    var out = text.replace(/(\bspeed\s*=\s*)[0-9.]+/g, function (_, head) {
        n++;
        return head + literal;
    });
    return { text: out, ok: n > 0, count: n };
}

/**
 * Reads the four control-point numbers of a named bezier curve as
 * `[x1, y1, x2, y2]`, or null when the curve is absent. The curve reads
 * `hl.curve("name", { type = "bezier", points = { { x1, y1 }, { x2, y2 } } })`.
 */
function getCurvePoints(text, name) {
    var re = new RegExp("hl\\.curve\\(\\s*\"" + name + "\"[^)]*?points\\s*=\\s*\\{\\s*\\{\\s*([0-9.-]+)\\s*,\\s*([0-9.-]+)\\s*\\}\\s*,\\s*\\{\\s*([0-9.-]+)\\s*,\\s*([0-9.-]+)\\s*\\}");
    var m = re.exec(text);
    if (!m)
        return null;
    return [parseFloat(m[1]), parseFloat(m[2]), parseFloat(m[3]), parseFloat(m[4])];
}

/**
 * Rewrites a named bezier curve's two control points. `x1..y2` are formatted by
 * the caller. Only that curve's `points = { ... }` run is touched.
 */
function setCurvePoints(text, name, x1, y1, x2, y2) {
    var re = new RegExp("(hl\\.curve\\(\\s*\"" + name + "\"[^)]*?points\\s*=\\s*\\{\\s*\\{\\s*)[0-9.-]+\\s*,\\s*[0-9.-]+(\\s*\\}\\s*,\\s*\\{\\s*)[0-9.-]+\\s*,\\s*[0-9.-]+(\\s*\\})");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + x1 + ", " + y1 + "$2" + x2 + ", " + y2 + "$3"), ok: true };
}
