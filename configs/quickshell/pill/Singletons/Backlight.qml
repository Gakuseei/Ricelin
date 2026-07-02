pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * One shared poller for the internal laptop backlight. Every pill carries an
 * Osd, so watching /sys here keeps it a single loop instead of one per monitor.
 * `changed` fires on a new reading after the initial populate, so login doesn't
 * flash the OSD; the loop exits at once on machines without a backlight.
 */
Singleton {
    id: root

    property bool present: false
    property real brightness: 0
    property int lastPct: -1

    signal changed()

    Process {
        command: ["sh", "-c", "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); [ -n \"$dev\" ] || exit 0; max=$(cat /sys/class/backlight/$dev/max_brightness); last=\"\"; while true; do val=$(cat /sys/class/backlight/$dev/brightness); if [ \"$val\" != \"$last\" ]; then echo \"$(( val * 100 / max ))\"; last=\"$val\"; fi; sleep 1; done"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var pct = parseInt(line.trim(), 10);
                if (isNaN(pct))
                    return;
                var seen = root.lastPct >= 0;
                root.present = true;
                root.brightness = Math.max(0, Math.min(100, pct)) / 100.0;
                root.lastPct = pct;
                if (seen)
                    root.changed();
            }
        }
    }
}
