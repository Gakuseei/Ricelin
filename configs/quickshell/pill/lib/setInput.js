.import "setDeco.js" as Deco

/** Lua field reads and writes share setDeco's word-bounded matchers. */
var getField = Deco.getField;
var setField = Deco.setField;

/**
 * Replaces the second argument of a `hl.env("KEY", "<old>")` call with the raw
 * value, re-quoted. Returns `{ text, ok }`; ok is false when the key's env call is
 * absent.
 */
function setEnv(text, key, valueRaw) {
    var re = new RegExp("(hl\\.env\\(\\s*\"" + Deco.escapeRe(key) + "\"\\s*,\\s*)\"[^\"]*\"");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1\"" + valueRaw + "\""), ok: true };
}

/**
 * Replaces the theme name and size in a `hyprctl setcursor <theme> <size>` call.
 * Returns `{ text, ok }`; ok is false when the call is absent.
 */
function setCursorLine(text, theme, size) {
    var re = /setcursor\s+\S+\s+\d+/;
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "setcursor " + theme + " " + size), ok: true };
}
