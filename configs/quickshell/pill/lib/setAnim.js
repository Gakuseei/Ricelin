/**
 * Read/write helpers for animations.lua whose setters return `{ text, ok }` and leave the text unchanged when the target is absent.
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
 * Only `hl.animation` lines carry a `speed =` field, so the blanket replace stays scoped to them.
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
 * Returns a named bezier curve's control points as `[x1, y1, x2, y2]`, or null when the curve is absent.
 */
function getCurvePoints(text, name) {
    var re = new RegExp("hl\\.curve\\(\\s*\"" + name + "\"[^)]*?points\\s*=\\s*\\{\\s*\\{\\s*([0-9.-]+)\\s*,\\s*([0-9.-]+)\\s*\\}\\s*,\\s*\\{\\s*([0-9.-]+)\\s*,\\s*([0-9.-]+)\\s*\\}");
    var m = re.exec(text);
    if (!m)
        return null;
    return [parseFloat(m[1]), parseFloat(m[2]), parseFloat(m[3]), parseFloat(m[4])];
}

/**
 * Rewrites only the named curve's `points = { ... }` run, with `x1..y2` already formatted by the caller.
 */
function setCurvePoints(text, name, x1, y1, x2, y2) {
    var re = new RegExp("(hl\\.curve\\(\\s*\"" + name + "\"[^)]*?points\\s*=\\s*\\{\\s*\\{\\s*)[0-9.-]+\\s*,\\s*[0-9.-]+(\\s*\\}\\s*,\\s*\\{\\s*)[0-9.-]+\\s*,\\s*[0-9.-]+(\\s*\\})");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + x1 + ", " + y1 + "$2" + x2 + ", " + y2 + "$3"), ok: true };
}
