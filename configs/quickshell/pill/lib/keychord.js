var NAMED_KEYS = {
    0x01000009: "Print",
    0x01001007: "Print",
    0x01000000: "Escape",
    0x01000001: "Tab",
    0x01000004: "Return",
    0x01000005: "Return",
    0x20:       "Space",
    0x01000006: "Insert",
    0x01000007: "Delete",
    0x01000010: "Home",
    0x01000011: "End",
    0x01000016: "PageUp",
    0x01000017: "PageDown",
    0x01000012: "Left",
    0x01000013: "Up",
    0x01000014: "Right",
    0x01000015: "Down"
};

var MOD_BITS = [
    { mask: 0x10000000, name: "SUPER" },
    { mask: 0x04000000, name: "CTRL" },
    { mask: 0x08000000, name: "ALT" },
    { mask: 0x02000000, name: "SHIFT" }
];

var MODIFIER_KEYS = {
    0x01000020: true, 0x01000021: true,
    0x01000022: true, 0x01000023: true,
    0x01000024: true,
    0x01000025: true,
    0x01000026: true,
    0x01001103: true
};

var F1 = 0x01000030, F35 = 0x01000052;

var PUNCT = {
    0x2e: "period", 0x2c: "comma", 0x2f: "slash", 0x5c: "backslash",
    0x3b: "semicolon", 0x27: "apostrophe", 0x60: "grave",
    0x5b: "bracketleft", 0x5d: "bracketright", 0x2d: "minus", 0x3d: "equal"
};

function keyName(key) {
    if (MODIFIER_KEYS[key]) return null;
    if (NAMED_KEYS[key]) return NAMED_KEYS[key];
    if (PUNCT[key]) return PUNCT[key];
    if (key >= F1 && key <= F35) return "F" + (key - F1 + 1);
    if (key >= 0x41 && key <= 0x5a) return String.fromCharCode(key);
    if (key >= 0x30 && key <= 0x39) return String.fromCharCode(key);
    return null;
}

function modNames(modifiers) {
    var out = [];
    for (var i = 0; i < MOD_BITS.length; i++)
        if (modifiers & MOD_BITS[i].mask) out.push(MOD_BITS[i].name);
    return out;
}

/**
 * Qt keypress as the combo binds.lua stores ("SUPER + K"); null for a bare modifier so capture keeps waiting.
 */
function chord(key, modifiers) {
    var k = keyName(key);
    if (k === null) return null;
    var parts = modNames(modifiers);
    parts.push(k);
    return parts.join(" + ");
}

/**
 * Display form of a stored combo, cased like KeyCap: "SUPER + Return" reads "Super + Return".
 */
function pretty(combo) {
    return String(combo).split("+").map(function (k) { return k.trim(); })
        .filter(function (k) { return k.length > 0; })
        .map(function (k) { return k.length > 1 ? k.charAt(0).toUpperCase() + k.slice(1).toLowerCase() : k.toUpperCase(); })
        .join(" + ");
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { chord, pretty };
}
