.import "setDeco.js" as Deco

/** Lua field reads and writes share setDeco's word-bounded matchers. */
var getField = Deco.getField;
var setField = Deco.setField;

/**
 * Replaces the value of a `hl.env("KEY", ...)` call, returning `{ text, ok }` with ok false when the call is absent.
 */
function setEnv(text, key, valueRaw) {
    var re = new RegExp("(hl\\.env\\(\\s*\"" + Deco.escapeRe(key) + "\"\\s*,\\s*)\"[^\"]*\"");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1\"" + valueRaw + "\""), ok: true };
}

/**
 * Replaces theme and size in the `hyprctl setcursor` call, returning `{ text, ok }` with ok false when it is absent.
 */
function setCursorLine(text, theme, size) {
    var re = /setcursor\s+\S+\s+\d+/;
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "setcursor " + theme + " " + size), ok: true };
}
