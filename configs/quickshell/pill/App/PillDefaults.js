.pragma library

/** Shipped values of every flag the pill, appearance and clock pages write; must match Singletons/Flags.qml. */
var flags = {
    idleModules: ["glyph", "clock", "div", "live"],
    hoverModules: ["workspaces", "div", "clockdate", "div", "weather", "minimized", "tray", "dnd", "wifi", "bt", "battery", "inbox", "mixer", "sound", "sysmon", "recorder", "settings", "power"],
    hoverActions: {},
    expandMode: "hover",
    openDelay: 0,
    closeDelay: 300,
    wsStyle: "dots",
    wsShow: "occupied",
    wsScroll: false,
    pillHeight: 38,
    pillRounding: 18,
    idleWidth: 160,
    uiScale: 1.0,
    pillOpacity: 1.0,
    pillBlur: false,
    pillShadow: true,
    pillBorder: true,
    pillSheen: true,
    springFeel: "soft",
    topGap: 1.0,
    appGap: 1.0,
    liveOrder: ["agent", "timer", "recording", "message", "music"],
    liveOff: ["recording", "message", "music"],
    batteryWarn: 20,
    restGlyph: "時",
    musicBars: 5,
    paletteMode: "static",
    manualHue: 30,
    manualDark: true,
    manualSat: 0.5,
    paletteVibrancy: 0.5,
    showGlyphs: true,
    musicViz: true,
    uiFont: "",
    iconWeight: 1.0,
    appTheme: false,
    randomScope: "all",
    reduceMotion: false,
    time12h: false,
    clockSeconds: false,
    dateStyle: "ddd d MMM",
    dateLang: "en",
    weekStart: "mon"
};

var pillKeys = ["idleModules", "hoverModules", "hoverActions", "expandMode", "openDelay", "closeDelay", "wsStyle", "wsShow", "wsScroll",
    "pillHeight", "pillRounding", "idleWidth", "uiScale", "pillOpacity", "pillBlur", "pillShadow", "pillBorder", "pillSheen", "springFeel",
    "topGap", "appGap", "liveOrder", "liveOff", "batteryWarn"];
var appearanceKeys = ["paletteMode", "manualHue", "manualDark", "manualSat", "paletteVibrancy", "showGlyphs", "restGlyph", "musicViz", "musicBars",
    "uiFont", "iconWeight", "appTheme", "randomScope", "reduceMotion"];
var clockKeys = ["time12h", "clockSeconds", "dateStyle", "dateLang", "weekStart"];

/** What a preset carries besides the Hyprland look: GTK theming, wallpaper scope and reduce motion stay personal. */
var presetKeys = pillKeys.concat(["paletteMode", "manualHue", "manualDark", "manualSat", "paletteVibrancy", "showGlyphs", "musicViz", "uiFont", "iconWeight"], clockKeys);

/** decoration.lua fields a preset covers: `block` scopes names shared by shadow and blur. */
var decoFields = [
    { key: "gaps_in", name: "gaps_in", block: "", type: "int", def: 6 },
    { key: "gaps_out", name: "gaps_out", block: "", type: "int", def: 12 },
    { key: "rounding", name: "rounding", block: "", type: "int", def: 12 },
    { key: "rounding_power", name: "rounding_power", block: "", type: "int", def: 4 },
    { key: "border_size", name: "border_size", block: "", type: "int", def: 2 },
    { key: "active_opacity", name: "active_opacity", block: "", type: "real", def: 1.0 },
    { key: "inactive_opacity", name: "inactive_opacity", block: "", type: "real", def: 1.0 },
    { key: "shadow.enabled", name: "enabled", block: "shadow", type: "bool", def: true },
    { key: "shadow.range", name: "range", block: "shadow", type: "int", def: 12 },
    { key: "shadow.render_power", name: "render_power", block: "shadow", type: "int", def: 3 },
    { key: "blur.enabled", name: "enabled", block: "blur", type: "bool", def: true },
    { key: "blur.size", name: "size", block: "blur", type: "int", def: 8 },
    { key: "blur.passes", name: "passes", block: "blur", type: "int", def: 3 },
    { key: "blur.vibrancy", name: "vibrancy", block: "blur", type: "real", def: 0.17 },
    { key: "blur.noise", name: "noise", block: "blur", type: "real", def: 0.01 }
];

function decoDefaults() {
    var o = {};
    for (var i = 0; i < decoFields.length; i++)
        o[decoFields[i].key] = decoFields[i].def;
    return o;
}

/** Every module a list can hold, in the order switched-off ones first appear. */
var modules = [
    { id: "glyph", label: "Glyph", kanji: "時", note: "The rest glyph, music bars while something plays" },
    { id: "clock", label: "Clock", icon: "clock", note: "The time" },
    { id: "date", label: "Date", icon: "type", note: "Today in the date style" },
    { id: "clockdate", label: "Clock & date", icon: "clock", note: "Time over date; a click opens the calendar" },
    { id: "workspaces", label: "Workspaces", icon: "layers", note: "Click one to go there" },
    { id: "weather", label: "Weather", icon: "cloud", note: "Sky and temperature; a click opens the calendar" },
    { id: "battery", label: "Battery", icon: "bolt", note: "Charge left, only on laptops" },
    { id: "musicbars", label: "Music bars", icon: "waves", note: "Bars that move with the music" },
    { id: "live", label: "Live activity", icon: "check", note: "Whatever is running right now" },
    { id: "minimized", label: "Minimized windows", icon: "minimize", note: "Click one to bring it back" },
    { id: "tray", label: "Tray", icon: "app-window", note: "Icons of background apps" },
    { id: "dnd", label: "Do not disturb", icon: "dnd", note: "Shows only while it is on" },
    { id: "wifi", label: "Wi-Fi", icon: "wifi", note: "" },
    { id: "bt", label: "Bluetooth", icon: "bluetooth", note: "" },
    { id: "inbox", label: "Notifications", icon: "inbox", note: "" },
    { id: "mixer", label: "Mixer", icon: "mixer", note: "" },
    { id: "sound", label: "Sound", icon: "music", note: "" },
    { id: "sysmon", label: "System monitor", icon: "monitor", note: "" },
    { id: "recorder", label: "Recorder", icon: "video", note: "" },
    { id: "settings", label: "Settings", icon: "cog", note: "" },
    { id: "power", label: "Power", icon: "shutdown", note: "" }
];

function moduleInfo(id) {
    if (id === "div")
        return { id: "div", label: "Divider", kanji: "|", note: "A thin line between groups" };
    for (var i = 0; i < modules.length; i++)
        if (modules[i].id === id)
            return modules[i];
    return { id: id, label: id, icon: "", note: "Unknown module, the pill skips it" };
}

/** Built-in click behaviour of every icon whose clicks can be changed. */
var iconDefaults = {
    battery: { left: "open", right: "none" },
    wifi: { left: "open", right: "toggle-wifi" },
    bt: { left: "open", right: "toggle-bt" },
    inbox: { left: "open", right: "none" },
    mixer: { left: "open", right: "none" },
    sound: { left: "open", right: "none" },
    sysmon: { left: "open", right: "none" },
    recorder: { left: "open", right: "stop-recording" },
    settings: { left: "open", right: "none" },
    power: { left: "open", right: "none" }
};

var actions = [
    { label: "Open its panel", value: "open" },
    { label: "Toggle Wi-Fi", value: "toggle-wifi" },
    { label: "Toggle Bluetooth", value: "toggle-bt" },
    { label: "Toggle do not disturb", value: "toggle-dnd" },
    { label: "Toggle game mode", value: "toggle-game" },
    { label: "Stop recording", value: "stop-recording" },
    { label: "Nothing", value: "none" },
    { label: "Run command…", value: "cmd" }
];

function actionLabel(v) {
    for (var i = 0; i < actions.length; i++)
        if (actions[i].value === v)
            return actions[i].label;
    return v;
}

var liveSources = [
    { id: "agent", label: "Claude agent", icon: "check", sub: "While an agent works or waits for you" },
    { id: "timer", label: "Timer", icon: "stopwatch", sub: "A running countdown" },
    { id: "recording", label: "Recording", icon: "record", sub: "While the screen records" },
    { id: "message", label: "New message", icon: "inbox", sub: "A new notification, for a few seconds" },
    { id: "music", label: "Music", icon: "music", sub: "The song while music plays" }
];

var dateStyles = ["ddd d", "d MMM", "ddd d MMM", "dd.MM."];

var builtins = [
    { id: "ricelin", name: "Ricelin", desc: "Today's look: glyph, clock and whatever is running", values: {} },
    { id: "minimal", name: "Minimal", desc: "Just the clock. A little lower, no glyphs, no sheen line",
        values: { idleModules: ["clock"], showGlyphs: false, pillHeight: 34, pillSheen: false, idleWidth: 140 } },
    { id: "info", name: "Info", desc: "Workspaces, clock, what's running and the date at a glance",
        values: { idleModules: ["workspaces", "div", "clock", "live", "div", "date"] } }
];

function clone(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

/** Deep equality that ignores object key order and float noise; lists from Flags are sequence wrappers, so both sides go through JSON first. */
function same(a, b) {
    return eq(typeof a === "object" && a !== null ? clone(a) : a, typeof b === "object" && b !== null ? clone(b) : b);
}

function eq(a, b) {
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(a - b) < 1e-6;
    if (a === b)
        return true;
    if (a === null || b === null || a === undefined || b === undefined || typeof a !== "object" || typeof b !== "object")
        return false;
    var aa = Array.isArray(a), ba = Array.isArray(b);
    if (aa !== ba)
        return false;
    if (aa) {
        if (a.length !== b.length)
            return false;
        for (var i = 0; i < a.length; i++)
            if (!eq(a[i], b[i]))
                return false;
        return true;
    }
    var ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length)
        return false;
    for (var j = 0; j < ka.length; j++)
        if (!eq(a[ka[j]], b[ka[j]]))
            return false;
    return true;
}

/** A preset's full value set: the shipped look with the preset's own values on top, so older saves stay complete. */
function fullValues(values) {
    var v = values || {};
    var out = {};
    for (var i = 0; i < presetKeys.length; i++) {
        var k = presetKeys[i];
        out[k] = clone(v.hasOwnProperty(k) ? v[k] : flags[k]);
    }
    out.deco = Object.assign(decoDefaults(), clone(v.deco || {}));
    return out;
}

