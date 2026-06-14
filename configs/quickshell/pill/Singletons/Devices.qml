pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Device-control bridge — single owner of the screen vibrance (nvibrant) and
 * external-monitor brightness (ddcutil) integration the mixer drives. The
 * persisted vibrance percent is the rice's source of truth: it is loaded and
 * re-applied once at startup so the saved tint survives a reboot, and every
 * later set both pushes the value to nvibrant and writes it back to the same
 * state file. DDC-capable monitors are discovered once via `ddcutil detect`
 * (one brightness fader each) rather than hardcoding I2C bus numbers, and the
 * setvcp/getvcp wire format lives here so every caller speaks it identically.
 */
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/nvibrant-value"

    property int vibrance: 40

    /**
     * DDC-capable monitors from `ddcutil detect`: [{ bus, label }] with label
     * taken from the DRM connector, falling back to the I2C bus number.
     */
    property var ddcMonitors: []

    /**
     * Loads the persisted vibrance percent and applies it once, so the saved
     * tint is restored on boot. Singletons init lazily, so a startup caller
     * must reference this for the restore to fire.
     */
    function restore() {
        var raw = vibState.text();
        var v = parseInt((raw || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
        if (raw && raw.trim().length)
            applyVibrance(root.vibrance);
    }

    /**
     * Sets the screen vibrance to `pct` percent: pushes it to nvibrant and
     * persists it to the state file. `vibrance` mirrors the last set value.
     */
    function setVibrance(pct) {
        root.vibrance = Math.round(pct);
        applyVibrance(pct);
        saveVibrance(pct);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        Quickshell.execDetached(["nvibrant", String(raw), "0", String(raw)]);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"',
            "_", root.stateFile, String(Math.round(pct))]);
    }

    /** Discovers DDC-capable monitors into `ddcMonitors`. */
    function detect() {
        ddcDetect.running = true;
    }

    /** Writes brightness `pct` to monitor `bus` via ddcutil setvcp. */
    function setBrightness(bus, pct) {
        Quickshell.execDetached(["timeout", "3", "ddcutil", "setvcp", "10",
            String(pct), "--bus", bus, "--noverify"]);
    }

    /**
     * Parses a `ddcutil getvcp --brief` line, returning the current brightness
     * percent or -1 when no value is present.
     */
    function parseBrightness(text) {
        var m = text.match(/C\s+(\d+)\s+/);
        return m ? parseInt(m[1], 10) : -1;
    }

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var mons = [];
                var blocks = this.text.split(/\bDisplay \d+/);
                for (var i = 0; i < blocks.length; i++) {
                    var bus = /I2C bus:\s+\/dev\/i2c-(\d+)/.exec(blocks[i]);
                    var conn = /DRM connector:\s+card\d+-(\S+)/.exec(blocks[i]);
                    if (bus)
                        mons.push({ bus: bus[1], label: conn ? conn[1] : "BUS " + bus[1] });
                }
                root.ddcMonitors = mons;
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }
}
