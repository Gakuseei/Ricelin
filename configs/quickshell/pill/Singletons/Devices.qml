pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Single owner of screen vibrance (nvibrant) and monitor brightness (ddcutil, brightnessctl), with the persisted vibrance percent as the source of truth.
 */
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/nvibrant-value"

    property int vibrance: 40

    /**
     * DDC monitors from `ddcutil detect` as `[{ bus, label }]`, labelled by DRM connector or else the I2C bus number.
     */
    property var ddcMonitors: []

    /** Brightness percent per DDC bus, read once after detect and kept by setBrightness. */
    property var ddcPct: ({})
    property bool detected: false

    /** True once an internal backlight has been found under /sys/class/backlight. */
    property bool backlightPresent: false

    /** Current internal-backlight level, 0..100. */
    property int backlightPct: 75

    /**
     * Re-applies the saved vibrance once, and since singletons init lazily a startup caller must reference this for it to fire.
     */
    function restore() {
        var raw = vibState.text();
        var v = parseInt((raw || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
        if (raw && raw.trim().length)
            applyVibrance(root.vibrance);
    }

    function setVibrance(pct) {
        root.vibrance = Math.round(pct);
        applyVibrance(pct);
        saveVibrance(pct);
    }

    /**
     * nvibrant ignores extra connector slots, so every slot gets the same value instead of guessing which ones are lit.
     */
    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        var args = ["nvibrant"];
        for (var i = 0; i < 16; i++)
            args.push(String(raw));
        Quickshell.execDetached(args);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"',
            "_", root.stateFile, String(Math.round(pct))]);
    }

    function detect() {
        if (detected)
            return;
        detected = true;
        ddcDetect.running = true;
        blDetect.running = true;
    }

    function storePct(bus, pct) {
        var m = Object.assign({}, ddcPct);
        m[bus] = pct;
        ddcPct = m;
    }

    function setBrightness(bus, pct) {
        storePct(bus, pct);
        Quickshell.execDetached(["timeout", "3", "ddcutil", "setvcp", "10",
            String(pct), "--bus", bus, "--noverify"]);
    }

    /**
     * Harmless on machines without /sys/class/backlight or brightnessctl, since it just finds no device.
     */
    function setBacklight(pct) {
        root.backlightPct = Math.round(Math.max(1, Math.min(100, pct)));
        Quickshell.execDetached(["brightnessctl", "set", root.backlightPct + "%"]);
    }

    /**
     * Parses a `ddcutil getvcp --brief` line into a brightness percent, or -1 when no value is present.
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
                ddcRead.command = ["sh", "-c", "for b; do printf '%s %s\\n' \"$b\" \"$(timeout 3 ddcutil getvcp 10 --bus \"$b\" --brief)\"; done", "_"]
                    .concat(mons.map(function(d) { return d.bus; }));
                ddcRead.running = mons.length > 0;
            }
        }
    }

    /** One sequential getvcp per bus, so two monitors never fight over the I2C lines. */
    Process {
        id: ddcRead
        stdout: SplitParser {
            onRead: (line) => {
                var v = root.parseBrightness(line);
                if (v >= 0)
                    root.storePct(line.split(" ")[0], v);
            }
        }
    }

    Process {
        id: blDetect
        command: ["sh", "-c", "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); [ -n \"$dev\" ] || exit 0; max=$(cat /sys/class/backlight/$dev/max_brightness); cur=$(cat /sys/class/backlight/$dev/brightness); echo \"$(( cur * 100 / max ))\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim(), 10);
                if (!isNaN(v)) {
                    root.backlightPct = Math.max(1, Math.min(100, v));
                    root.backlightPresent = true;
                }
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
