.pragma library
.import "../lib/keychord.js" as Chord

var MEDIA_KEYS = {
    XF86AudioRaiseVolume: ["Volume up", "Volume up"],
    XF86AudioLowerVolume: ["Volume down", "Volume down"],
    XF86AudioMute: ["Mute", "Mute sound"],
    XF86AudioMicMute: ["Mic mute", "Mute microphone"],
    XF86AudioPlay: ["Play", "Play or pause"],
    XF86AudioPause: ["Pause", "Pause"],
    XF86AudioNext: ["Next", "Next track"],
    XF86AudioPrev: ["Previous", "Previous track"],
    XF86MonBrightnessUp: ["Brightness up", "Brightness up"],
    XF86MonBrightnessDown: ["Brightness down", "Brightness down"]
};

var SURFACES = {
    launcher: "Launcher", clipboard: "Clipboard", settings: "Open settings", wallpaper: "Wallpaper picker",
    gameMode: "Game mode", keybinds: "Keybinds", calendar: "Calendar", recorder: "Recorder", mixer: "Mixer"
};

var SCRIPTS = {
    "minimize-toggle": "Minimize window", "lock": "Lock screen", "wallpaper": "Random wallpaper",
    "record": "Record screen", "volume": "Volume up"
};

var APPS = {
    ghostty: "Terminal", kitty: "Terminal", alacritty: "Terminal", foot: "Terminal", wezterm: "Terminal", konsole: "Terminal",
    dolphin: "Files", nautilus: "Files", thunar: "Files", nemo: "Files",
    hyprpicker: "Color picker", firefox: "Browser", chromium: "Browser", "zen-browser": "Browser"
};

var GLOBALS = { mediaToggle: "Play or pause", mediaNext: "Next track", mediaPrev: "Previous track" };

function cap(w) {
    return w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w;
}

/** One key of a stored combo as a readable cap: media keys get words, mouse codes become drag or scroll. */
function keyText(k) {
    if (MEDIA_KEYS[k])
        return MEDIA_KEYS[k][0];
    if (/^XF86/.test(k))
        return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
    if (k === "mouse:272")
        return "Left drag";
    if (k === "mouse:273")
        return "Right drag";
    if (k === "mouse_up")
        return "Scroll up";
    if (k === "mouse_down")
        return "Scroll down";
    return Chord.pretty(k);
}

/** Display form of a combo for KeyCap, "SUPER + mouse:272" reads "Super + Left drag". */
function combo(c) {
    return String(c).split("+").map(function (k) { return k.trim(); })
        .filter(function (k) { return k.length > 0; }).map(keyText).join(" + ");
}

/** The script or command a bind runs, `~` for $HOME and without the hl.dsp prefix, for the dim second line. */
function action(b) {
    if (b.cmd.length > 0)
        return b.cmd;
    var env = b.action.match(/exec_cmd\(\s*os\.getenv\(\s*"HOME"\s*\)\s*\.\.\s*"((?:[^"\\]|\\.)*)"\s*\)$/);
    if (env)
        return "~" + env[1];
    return b.action.replace(/^hl\.dsp\./, "");
}

/** Name shown for a bind: its `-- name` comment, else a plain-English guess from what it runs. */
function label(b) {
    if (b.name.length > 0)
        return b.name;
    var key = b.combo.split("+").map(function (k) { return k.trim(); }).pop();
    var a = b.action;
    var m;
    if ((m = a.match(/\/scripts\/open-surface\.sh\s+(\w+)/)))
        return SURFACES[m[1]] || "Open " + m[1];
    if ((m = a.match(/\/scripts\/special-toggle\.sh\s+(\w+)/)))
        return "Send window to " + m[1];
    if ((m = a.match(/\/scripts\/([\w-]+)\.sh/)) && SCRIPTS[m[1]] && !MEDIA_KEYS[key])
        return SCRIPTS[m[1]];
    if (MEDIA_KEYS[key])
        return MEDIA_KEYS[key][1];
    if (b.cmd.length > 0) {
        var bin = b.cmd.split(/\s+/)[0].split("/").pop();
        return APPS[bin] || cap(bin);
    }
    if (/window\.kill\b/.test(a)) return "Kill window";
    if (/window\.close\b/.test(a)) return "Close window";
    if (/window\.fullscreen\b/.test(a)) return "Fullscreen";
    if (/window\.float\b/.test(a)) return "Float window";
    if (/window\.drag\b/.test(a)) return "Move window";
    if (/window\.resize\b/.test(a)) return "Resize window";
    if ((m = a.match(/window\.move\(\s*\{\s*workspace\s*=\s*"?([\w+-]+)"?/)))
        return "Send window to workspace " + m[1];
    if ((m = a.match(/toggle_special\(\s*"([^"]+)"/)))
        return m[1] === "minimized" ? "Show minimized" : m[1] === "stash" ? "Stash" : cap(m[1]) + " space";
    if ((m = a.match(/focus\(\s*\{\s*workspace\s*=\s*"r([+-])1"/)))
        return m[1] === "-" ? "Previous workspace" : "Next workspace";
    if ((m = a.match(/focus\(\s*\{\s*workspace\s*=\s*"?(\w+)"?/)))
        return "Workspace " + m[1];
    if ((m = a.match(/global\(\s*"quickshell:(\w+)"/)))
        return GLOBALS[m[1]] || cap(m[1]);
    return b.label;
}

/** The bind that opens this app, marked in the list. */
function opensSettings(b) {
    return /open-surface\.sh\s+settings\b/.test(b.action);
}
