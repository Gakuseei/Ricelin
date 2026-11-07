.pragma library

/** Search rows for notifications, windows, workspaces, animation, display, input, keybinds, idlelock, recorder, weather and updates, shaped like searchIndex.js entries. */
var entries = [
    { page: "notifications", tab: "", group: "Media", label: "Play and pause", sub: "When music starts or stops", keywords: "media music osd flash play pause resume song card", key: "notif.play", advanced: false },
    { page: "notifications", tab: "", group: "Media", label: "New song", sub: "When the track changes", keywords: "media music osd flash track song next skip card", key: "notif.song", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Volume flash", sub: "When you change the volume or mute", keywords: "osd flash sound volume mute popup", key: "notif.volume", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Brightness flash", sub: "When the screen gets brighter or darker", keywords: "osd flash backlight brightness screen popup", key: "notif.brightness", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Workspace flash", sub: "The dots when you switch workspaces", keywords: "osd flash workspace switch dots popup", key: "notif.workspace", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Charging flash", sub: "When you plug in the charger", keywords: "osd flash battery charging charger plug popup", key: "notif.battery", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Recording flash", sub: "When a recording starts or stops", keywords: "osd flash screen recording record popup", key: "notif.record", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "How long flashes stay", sub: "Scales every flash, the song card included", keywords: "osd flash duration time length seconds longer shorter", key: "notif.osdtime", advanced: false },
    { page: "notifications", tab: "", group: "Pill flashes", label: "Do not disturb", sub: "Hides notifications and most flashes", keywords: "dnd quiet silence mute focus", key: "notif.dnd", advanced: false },
    { page: "notifications", tab: "", group: "App notifications", label: "Notification time", sub: "How long a new notification stays in the pill", keywords: "notification toast duration seconds time length", key: "notif.secs", advanced: false },
    { page: "notifications", tab: "", group: "Apps", label: "Mute an app", sub: "Keep an app's notifications out of the pill", keywords: "mute silence app notifications hide block inbox only", key: "notif.apps", advanced: false },

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
