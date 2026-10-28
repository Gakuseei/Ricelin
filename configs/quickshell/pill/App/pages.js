.pragma library

var sections = [
    { title: "Pill", pages: ["pill", "appearance", "clock", "presets"] },
    { title: "Desktop", pages: ["windows", "workspaces", "animation"] },
    { title: "Devices", pages: ["display", "input"] },
    { title: "System", pages: ["keybinds", "idlelock", "recorder", "weather", "updates"] }
];

var pages = {
    pill:       { name: "Pill",         kanji: "丸", icon: "minimize",   file: "PagePill.qml",       preview: true,  desc: "The bar on top of every screen" },
    appearance: { name: "Appearance",   kanji: "相", icon: "sparkles",   file: "PageAppearance.qml", preview: true,  desc: "Palette, glyphs, font, icons and motion" },
    clock:      { name: "Clock & date", kanji: "暦", icon: "clock",      file: "PageClock.qml",      preview: true,  desc: "How time and date read in the pill" },
    presets:    { name: "Presets",      kanji: "型", icon: "palette",    file: "PagePresets.qml",    preview: true,  desc: "Whole pill looks you can switch between" },
    windows:    { name: "Windows",      kanji: "窓", icon: "app-window", file: "PageWindows.qml",    preview: false, desc: "Gaps, corners, blur, shadow and night light" },
    workspaces: { name: "Workspaces",   kanji: "場", icon: "layers",     file: "PageWorkspaces.qml", preview: false, desc: "Special spaces, their keys and apps" },
    animation:  { name: "Animation",    kanji: "動", icon: "waves",      file: "PageAnimation.qml",  preview: false, desc: "Speed and the curve every window moves on" },
    display:    { name: "Display",      kanji: "画", icon: "monitor",    file: "PageDisplay.qml",    preview: false, desc: "Arrange monitors, pick modes and scale" },
    input:      { name: "Input",        kanji: "操", icon: "mouse",      file: "PageInput.qml",      preview: false, desc: "Pointer, keyboard and cursor" },
    keybinds:   { name: "Keybinds",     kanji: "鍵", icon: "keyboard",   file: "PageKeybinds.qml",   preview: false, desc: "Every shortcut, searchable and editable" },
    idlelock:   { name: "Idle & lock",  kanji: "錠", icon: "lock",       file: "PageIdleLock.qml",   preview: false, desc: "When the screen locks, blanks and sleeps" },
    recorder:   { name: "Recorder",     kanji: "録", icon: "video",      file: "PageRecorder.qml",   preview: false, desc: "Frame rate, quality, audio and where clips go" },
    weather:    { name: "Weather",      kanji: "天", icon: "cloud",      file: "PageWeather.qml",    preview: true,  desc: "Town and units" },
    updates:    { name: "Updates",      kanji: "更", icon: "download",   file: "PageUpdates.qml",    preview: false, desc: "Version, changelog and updates" }
};

var home = "pill";

var order = [];
for (var i = 0; i < sections.length; i++)
    order = order.concat(sections[i].pages);
