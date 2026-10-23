pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/** One in-process backlight reader for every Osd; sysfs has no inotify, so udev change events trigger the reread. */
Singleton {
    id: root

    property real brightness: 0
    property int lastPct: -1
    property string dev: ""
    property int max: 0
    property string lastRaw: ""

    signal changed()

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && { echo \"$d\"; cat \"$d/max_brightness\"; exit 0; }; done; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n");
                var m = l.length > 1 ? parseInt(l[1], 10) : 0;
                if (m > 0) {
                    root.max = m;
                    root.dev = l[0];
                }
            }
        }
    }

    FileView {
        id: level
        path: root.dev ? root.dev + "/brightness" : ""
        printErrors: false
        onLoaded: {
            var raw = text().trim();
            var val = parseInt(raw, 10);
            if (isNaN(val) || raw === root.lastRaw)
                return;
            root.lastRaw = raw;
            var pct = Math.floor(val * 100 / root.max);
            var seen = root.lastPct >= 0;
            root.brightness = Math.max(0, Math.min(100, pct)) / 100.0;
            root.lastPct = pct;
            if (seen)
                root.changed();
        }
    }

    Process {
        running: root.dev !== ""
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: level.reload()
        }
    }
}
