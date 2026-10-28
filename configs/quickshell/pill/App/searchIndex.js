.pragma library
.import "searchPill.js" as SearchPill
.import "searchSystem.js" as SearchSystem
.import "searchDesktop.js" as SearchDesktop

/**
 * Entry shape: { page, tab, group, label, sub, keywords, key, advanced }. `tab` is the page tab label, `key` the AppRow key that reveal() scrolls to, `advanced` opens More options first.
 */
var entries = [
    { page: "pill", tab: "", group: "", label: "Pill", sub: "The bar on top of every screen", keywords: "bar panel top modules idle hover live activity shape height rounding", key: "", advanced: false },
    { page: "appearance", tab: "", group: "", label: "Appearance", sub: "Palette, glyphs, font, icons and motion", keywords: "palette theme colour color dark light font typeface glyphs kanji icons line weight motion gtk", key: "", advanced: false },
    { page: "clock", tab: "", group: "", label: "Clock & date", sub: "How time and date read in the pill", keywords: "time date 12h 24h seconds week start language format", key: "", advanced: false },
    { page: "presets", tab: "", group: "", label: "Presets", sub: "Whole pill looks you can switch between", keywords: "looks themes minimal info save preset", key: "", advanced: false },
    { page: "windows", tab: "", group: "", label: "Windows", sub: "Gaps, corners, blur, shadow and night light", keywords: "look gaps corners rounding blur shadow opacity transparency border night light", key: "", advanced: false },
    { page: "workspaces", tab: "", group: "", label: "Workspaces", sub: "Special spaces, their keys and apps", keywords: "special spaces stash private minimized apps keys", key: "", advanced: false },
    { page: "animation", tab: "", group: "", label: "Animation", sub: "Speed and the curve every window moves on", keywords: "speed curve bezier motion animations", key: "", advanced: false },
    { page: "display", tab: "", group: "", label: "Display", sub: "Arrange monitors, pick modes and scale", keywords: "monitors screens resolution refresh rate hz scale arrange main primary", key: "", advanced: false },
    { page: "input", tab: "", group: "", label: "Input", sub: "Pointer, keyboard and cursor", keywords: "mouse pointer keyboard cursor layout sensitivity touchpad", key: "", advanced: false },
    { page: "keybinds", tab: "", group: "", label: "Keybinds", sub: "Every shortcut, searchable and editable", keywords: "shortcuts hotkeys keys binds", key: "", advanced: false },
    { page: "idlelock", tab: "", group: "", label: "Idle & lock", sub: "When the screen locks, blanks and sleeps", keywords: "idle lock screen off suspend sleep timeout", key: "", advanced: false },
    { page: "recorder", tab: "", group: "", label: "Recorder", sub: "Frame rate, quality, audio and where clips go", keywords: "screen recording record fps quality audio microphone folder", key: "", advanced: false },
    { page: "weather", tab: "", group: "", label: "Weather", sub: "Town and units", keywords: "town city units celsius fahrenheit forecast", key: "", advanced: false },
    { page: "updates", tab: "", group: "", label: "Updates", sub: "Version, changelog and updates", keywords: "version changelog update upgrade", key: "", advanced: false }
];

function all() {
    return entries.concat(SearchPill.entries || [], SearchSystem.entries || [], SearchDesktop.entries || []);
}
