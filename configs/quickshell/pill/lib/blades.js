.pragma library

/*
 * Which registry records belong on the blade fan, and in what order.
 *
 * Pure functions on plain records so the rule can be unit-tested without
 * Quickshell (tests/test_blades.js). The blades are the games and Wine apps
 * fan, so the default rule is exactly that; the per-app `blade` field is the
 * user's override:
 *
 *   "auto"  games and Wine-family apps appear (the default)
 *   "pin"   always appears, whatever it is
 *   "hide"  never appears
 */

var AUTO_RUNNERS = ["wine", "wine-staging", "umu", "steam"];

function lower(v) {
    return String(v === undefined || v === null ? "" : v).toLowerCase();
}

function mode(app) {
    var m = lower(app && app.blade);
    return m === "pin" || m === "hide" ? m : "auto";
}

function eligible(app) {
    if (!app || !app.id)
        return false;
    var m = mode(app);
    if (m === "hide")
        return false;
    if (m === "pin")
        return true;
    return lower(app.category) === "game" || AUTO_RUNNERS.indexOf(lower(app.runner)) >= 0;
}

/** Pinned first, then favorites, then the most recently launched, then A to Z. */
function compare(a, b) {
    var ap = mode(a) === "pin" ? 1 : 0;
    var bp = mode(b) === "pin" ? 1 : 0;
    if (ap !== bp)
        return bp - ap;

    var af = a.favorite ? 1 : 0;
    var bf = b.favorite ? 1 : 0;
    if (af !== bf)
        return bf - af;

    var at = Number(a.lastLaunched || 0);
    var bt = Number(b.lastLaunched || 0);
    if (at !== bt)
        return bt - at;

    var an = lower(a.name);
    var bn = lower(b.name);
    return an < bn ? -1 : (an > bn ? 1 : 0);
}

/** At most `max` eligible records in blade order; `max` <= 0 means no cap. */
function select(apps, max) {
    var out = [];
    for (var i = 0; i < (apps ? apps.length : 0); i++)
        if (eligible(apps[i]))
            out.push(apps[i]);
    out.sort(compare);
    return max > 0 ? out.slice(0, max) : out;
}
