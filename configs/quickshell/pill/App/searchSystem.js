.pragma library

/** Search rows for windows, workspaces, animation, display, input, keybinds, idlelock, recorder, weather and updates, shaped like searchIndex.js entries. */
var entries = [
    { page: "keybinds", tab: "", group: "Shortcuts", label: "Add a bind", sub: "Runs a command when you press its keys", keywords: "new shortcut hotkey keybind create custom command launch app", key: "keys.add", advanced: false },
    { page: "keybinds", tab: "", group: "Shortcuts", label: "Edit a bind", sub: "Change the keys, name or command of a shortcut", keywords: "rebind change remap shortcut hotkey keybind delete remove rename", key: "", advanced: false },

    { page: "idlelock", tab: "", group: "When idle", label: "Lock after", sub: "Minutes without input before the screen locks", keywords: "auto lock autolock timeout idle away inactivity minutes hypridle", key: "idle.lock", advanced: false },
    { page: "idlelock", tab: "", group: "When idle", label: "Screen off", sub: "Minutes until the screens go dark", keywords: "display off blank dpms monitor sleep timeout idle minutes power saving", key: "idle.screenOff", advanced: false },
    { page: "idlelock", tab: "", group: "When idle", label: "Suspend", sub: "Minutes until the PC goes to sleep", keywords: "sleep standby hibernate idle timeout minutes power", key: "idle.suspend", advanced: false },
    { page: "idlelock", tab: "", group: "Lock screen", label: "Use UI font", sub: "The lock clock uses the font from Appearance", keywords: "lock screen font typeface clock lockscreen", key: "idle.lockFont", advanced: true },
    { page: "idlelock", tab: "", group: "Lock screen", label: "Show seconds", sub: "Adds seconds to the lock screen clock", keywords: "lock screen clock seconds time lockscreen", key: "idle.lockSeconds", advanced: false },

    { page: "recorder", tab: "", group: "Video", label: "Frame rate", sub: "Frames per second, higher is smoother", keywords: "fps framerate hz smooth screen recording video capture", key: "rec.fps", advanced: false },
    { page: "recorder", tab: "", group: "Video", label: "Quality", sub: "Higher means bigger files", keywords: "bitrate lossless ultra file size screen recording video", key: "rec.quality", advanced: false },
    { page: "recorder", tab: "", group: "Video", label: "Show cursor", sub: "Draw the pointer into the video", keywords: "mouse pointer cursor screen recording capture", key: "rec.cursor", advanced: true },
    { page: "recorder", tab: "", group: "Audio", label: "Record microphone", sub: "Your default input", keywords: "mic microphone voice audio sound screen recording", key: "rec.mic", advanced: false },
    { page: "recorder", tab: "", group: "Audio", label: "Record desktop audio", sub: "Everything you hear", keywords: "system sound speaker audio game sound screen recording", key: "rec.desktop", advanced: false },
    { page: "recorder", tab: "", group: "Start and save", label: "Countdown", sub: "Seconds before recording starts", keywords: "delay timer seconds wait screen recording", key: "rec.countdown", advanced: false },
    { page: "recorder", tab: "", group: "Start and save", label: "Folder", sub: "Where recordings are saved", keywords: "save location directory path videos clips output screen recording", key: "rec.folder", advanced: false },
    { page: "recorder", tab: "", group: "Start and save", label: "Open the folder", sub: "Shows your recordings in the file manager", keywords: "recordings clips videos file manager browse", key: "rec.open", advanced: true },

    { page: "weather", tab: "", group: "Location and units", label: "Town", sub: "Where the forecast is for, empty finds it automatically", keywords: "city location place weather forecast", key: "weather.city", advanced: false },
    { page: "weather", tab: "", group: "Location and units", label: "Unit", sub: "Temperature in the pill and calendar", keywords: "celsius fahrenheit temperature degrees °c °f", key: "weather.unit", advanced: false },
    { page: "weather", tab: "", group: "Forecast", label: "Refresh weather", sub: "Fetches the forecast again right now", keywords: "reload update forecast open-meteo now", key: "weather.refresh", advanced: false },

    { page: "updates", tab: "", group: "Installed version", label: "Check for updates", sub: "See if a newer Ricelin is out", keywords: "version upgrade new release latest", key: "updates.check", advanced: false },
    { page: "updates", tab: "", group: "Installed version", label: "Update now", sub: "Installs the update and restarts the shell", keywords: "upgrade install latest version", key: "updates.check", advanced: false },
    { page: "updates", tab: "", group: "Installed version", label: "What's new", sub: "The changelog of a waiting update", keywords: "changelog release notes changes news", key: "updates.check", advanced: false }
];
