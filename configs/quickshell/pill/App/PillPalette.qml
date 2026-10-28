import QtQuick
import Quickshell
import "../Singletons"

/**
 * Re-runs wallcolors.py whenever a palette flag changes, the way the old Appearance surface did per mode; runs are detached so leaving the page never kills one, and a lock lets only the newest waiting run go.
 */
Item {
    id: root

    property bool palettePending: false
    property bool appsPending: false

    readonly property string gate: 't="${XDG_RUNTIME_DIR:-/tmp}/ricelin-wallcolors"; echo $$ > "$t.$1"; exec 9>"$t.lock"; flock 9; [ "$(cat "$t.$1" 2>/dev/null)" = "$$" ] || exit 0; export RICELIN_PALETTE="$2"; shift 2; '
    readonly property string wc: 'python3 "$HOME/.config/hypr/scripts/wallcolors.py"'
    readonly property string ghostty: 'busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate "sava{sv}" reload-config 0 0 >/dev/null 2>&1 || true'
    readonly property string wallpaper: 'f="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper"; pic=$(cat "$f" 2>/dev/null); case "$pic" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper-still.png";; esac; '

    function schedulePalette() {
        palettePending = true;
        debounce.restart();
    }

    function scheduleApps() {
        appsPending = true;
        debounce.restart();
    }

    function flush() {
        debounce.stop();
        const mode = Flags.paletteMode;
        if (palettePending) {
            if (mode === "manual")
                Quickshell.execDetached(["sh", "-c", gate + wc + ' --hue "$1" "$2" "$3"; ' + ghostty,
                    "sh", "pal", mode, String(Math.round(Flags.manualHue)), Flags.manualDark ? "dark" : "light", String(Flags.manualSat)]);
            else if (mode === "dynamic")
                Quickshell.execDetached(["sh", "-c", gate + wallpaper + '[ -f "$pic" ] && ' + wc + ' "$pic" >/dev/null 2>&1; ' + ghostty,
                    "sh", "pal", mode]);
            else if (Flags.appTheme)
                appsPending = true;
        }
        if (appsPending)
            Quickshell.execDetached(["sh", "-c", gate + wc + ' --apps "$1"', "sh", "apps", mode, Flags.appTheme ? "on" : "off"]);
        palettePending = false;
        appsPending = false;
    }

    Timer {
        id: debounce
        interval: 260
        onTriggered: root.flush()
    }

    Component.onDestruction: if (palettePending || appsPending) flush()

    Connections {
        target: Flags
        function onPaletteModeChanged() {
            root.schedulePalette();
        }
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.schedulePalette();
        }
        function onManualSatChanged() {
            if (Flags.paletteMode === "manual")
                root.schedulePalette();
        }
        function onManualDarkChanged() {
            if (Flags.paletteMode === "manual")
                root.schedulePalette();
        }
        function onPaletteVibrancyChanged() {
            if (Flags.paletteMode === "dynamic")
                root.schedulePalette();
        }
        function onAppThemeChanged() {
            root.scheduleApps();
        }
    }
}
