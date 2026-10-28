pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Session flags shared through a watched JSON file, so the pill and lock see the same Do-Not-Disturb and Keep-Awake state live and across restarts.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias time12h: adapter.time12h
    property alias clockSeconds: adapter.clockSeconds
    property alias showGlyphs: adapter.showGlyphs
    property alias paletteMode: adapter.paletteMode
    property alias appTheme: adapter.appTheme
    property alias wallpaperDir: adapter.wallpaperDir
    property alias randomScope: adapter.randomScope
    property alias uiScale: adapter.uiScale
    property alias reduceMotion: adapter.reduceMotion
    property alias manualHue: adapter.manualHue
    property alias manualDark: adapter.manualDark
    property alias manualSat: adapter.manualSat
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias pillBlur: adapter.pillBlur
    property alias topGap: adapter.topGap
    property alias appGap: adapter.appGap
    property alias recordCountdown: adapter.recordCountdown
    property alias recordDir: adapter.recordDir
    property alias recordFps: adapter.recordFps
    property alias recordQuality: adapter.recordQuality
    property alias recordCursor: adapter.recordCursor
    property alias recordMic: adapter.recordMic
    property alias recordDesktop: adapter.recordDesktop
    property alias recordClearedBefore: adapter.recordClearedBefore
    property alias idleLockMin: adapter.idleLockMin
    property alias idleScreenOffMin: adapter.idleScreenOffMin
    property alias idleSuspendMin: adapter.idleSuspendMin
    property alias weatherCity: adapter.weatherCity
    property alias musicViz: adapter.musicViz
    property alias gameMode: adapter.gameMode
    property alias gamePrevDnd: adapter.gamePrevDnd
    property alias gamePrevViz: adapter.gamePrevViz
    property alias gamePrevAwake: adapter.gamePrevAwake
    property alias gamePrevProfile: adapter.gamePrevProfile
    property alias nightLightMode: adapter.nightLightMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightOnMin: adapter.nightLightOnMin
    property alias nightLightOffMin: adapter.nightLightOffMin
    property alias iconWeight: adapter.iconWeight
    property alias paletteVibrancy: adapter.paletteVibrancy
    property alias idleModules: adapter.idleModules
    property alias hoverModules: adapter.hoverModules
    property alias hoverActions: adapter.hoverActions
    property alias expandMode: adapter.expandMode
    property alias openDelay: adapter.openDelay
    property alias closeDelay: adapter.closeDelay
    property alias wsStyle: adapter.wsStyle
    property alias wsShow: adapter.wsShow
    property alias wsScroll: adapter.wsScroll
    property alias pillHeight: adapter.pillHeight
    property alias pillRounding: adapter.pillRounding
    property alias idleWidth: adapter.idleWidth
    property alias pillShadow: adapter.pillShadow
    property alias pillBorder: adapter.pillBorder
    property alias pillSheen: adapter.pillSheen
    property alias springFeel: adapter.springFeel
    property alias liveOrder: adapter.liveOrder
    property alias liveOff: adapter.liveOff
    property alias batteryWarn: adapter.batteryWarn
    property alias restGlyph: adapter.restGlyph
    property alias musicBars: adapter.musicBars
    property alias dateStyle: adapter.dateStyle
    property alias dateLang: adapter.dateLang
    property alias weekStart: adapter.weekStart
    property alias weatherUnit: adapter.weatherUnit
    property alias lockUseFont: adapter.lockUseFont
    property alias lockSeconds: adapter.lockSeconds
    property alias appZoom: adapter.appZoom

    /** One write per event-loop turn, however many flags changed in it. */
    function flush() {
        file.writeAdapter();
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/flags.json"
        blockLoading: true
        /** Synchronous writes: an async write in flight gets joined by the next one, which reloads its older text over values set since. */
        blockWrites: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: Qt.callLater(root.flush)
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            property bool showGlyphs: true
            property string paletteMode: "static"
            /** GTK apps follow the pill palette. Off by default so an update never restyles apps unasked; the installer turns it on for fresh boxes. */
            property bool appTheme: false
            /** Explicit wallpaper folder override. Empty means autodetect: the dir wallpaper.sh last resolved (ricelin-wallpaper-dir state file), then ~/Ricelin/wallpapers. Lives in user state so an in-app update never clobbers a custom folder. */
            property string wallpaperDir: ""
            /** Super+B random target: "all" repaints every monitor, "cursor" only the one under the pointer. */
            property string randomScope: "all"
            property real uiScale: 1.0
            property bool reduceMotion: false
            property int manualHue: 30
            property bool manualDark: true
            property real manualSat: 0.5
            property string uiFont: ""
            property real pillOpacity: 1.0
            property bool pillBlur: false
            /** Top margin as a fraction of the shipped 8px. 0 sits the pill flush to the screen edge. */
            property real topGap: 1.0
            /** Pill-to-window band as a fraction of the shipped 12px. 0 tucks the windows flush under the pill. */
            property real appGap: 1.0
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
            property int idleLockMin: 5
            property int idleScreenOffMin: 6
            property int idleSuspendMin: 0
            property string weatherCity: ""
            property bool musicViz: true
            property bool gameMode: false
            property bool gamePrevDnd: false
            property bool gamePrevViz: true
            property bool gamePrevAwake: false
            property string gamePrevProfile: ""
            property string nightLightMode: "off"
            property int nightLightTemp: 4000
            property int nightLightOnMin: 1260
            property int nightLightOffMin: 450
            /** Multiplier on every icon's stroke width. */
            property real iconWeight: 1.0
            /** Dynamic palette color strength, 0 muted to 1 vivid. */
            property real paletteVibrancy: 0.5
            property var idleModules: ["glyph", "clock", "div", "live"]
            /** Module ids in display order; "div" may repeat. */
            property var hoverModules: ["workspaces", "div", "clockdate", "div", "weather", "minimized", "tray", "dnd", "wifi", "bt", "battery", "inbox", "mixer", "sound", "sysmon", "recorder", "settings", "power"]
            /** Per hover icon { left, right } action overrides; missing keys keep the built-in behaviour. */
            property var hoverActions: ({})
            /** "hover" expands on pointer entry, "click" only on a click on free pill space. */
            property string expandMode: "hover"
            property int openDelay: 0
            property int closeDelay: 300
            property string wsStyle: "dots"
            property string wsShow: "occupied"
            property bool wsScroll: false
            property real pillHeight: 38
            property real pillRounding: 18
            property real idleWidth: 160
            property bool pillShadow: true
            property bool pillBorder: true
            property bool pillSheen: true
            property string springFeel: "soft"
            property var liveOrder: ["agent", "timer", "recording", "message", "music"]
            /** Live activity sources switched off by default so only the agent and timer show, as before. */
            property var liveOff: ["recording", "message", "music"]
            property int batteryWarn: 20
            property string restGlyph: "時"
            property int musicBars: 5
            property string dateStyle: "ddd d MMM"
            property string dateLang: "en"
            property string weekStart: "mon"
            property string weatherUnit: "c"
            property bool lockUseFont: true
            property bool lockSeconds: false
            /** Settings app zoom on top of uiScale, set with Ctrl+wheel or Ctrl+-/+/0. */
            property real appZoom: 0.85
        }
    }
}
