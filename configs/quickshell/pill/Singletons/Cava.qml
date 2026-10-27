pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Live audio spectrum from a headless cava, spawned only when the binary exists because the updater never installs packages.
 */
Singleton {
    id: root

    readonly property int bars: [3, 5, 7].indexOf(Flags.musicBars) >= 0 ? Flags.musicBars : 5
    property var levels: []
    property bool active: false

    /**
     * Counted, not a bool: each open EQ view holds one and gets the 40-band `spectrum`.
     */
    property int consumers: 0
    property var spectrum: []
    readonly property int bands: consumers > 0 ? 40 : bars

    readonly property bool playing: Players.list.some(p => p.isPlaying)
    readonly property bool restShown: Hyprland.monitors.values.some(m => !(m.activeWorkspace && m.activeWorkspace.lastIpcObject.hasfullscreen))

    property bool available: false
    readonly property bool wanted: available && (consumers > 0 || (Flags.musicViz && playing && restShown))

    /**
     * autosens is off so silence stays at zero bars, with a fixed sensitivity tuned so real music fills the bars.
     */
    readonly property string config: "[general]\n"
        + "bars = " + bands + "\nframerate = 60\nautosens = 0\nsensitivity = 5500\nsleep_timer = 1\n"
        + "[input]\nmethod = pipewire\nsource = auto\n"
        + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n"
        + "ascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
        + "channels = mono\nmono_option = average\n"
        + "[smoothing]\nnoise_reduction = 0.77\n"

    onWantedChanged: cavaProc.running = wanted
    onBandsChanged: {
        spectrum = [];
        if (cavaProc.running) {
            cavaProc.running = false;
            cavaProc.running = wanted;
        }
    }
    Component.onCompleted: cavaProc.running = wanted

    Process {
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
        onExited: (code) => root.available = (code === 0)
    }

    Process {
        id: cavaProc
        command: ["sh", "-c", "printf '%s' \"$1\" | cava -p /dev/stdin", "_", root.config]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line)
                    return;
                const parts = line.split(";");
                const n = root.bands;
                const all = [];
                for (let i = 0; i < n; i++)
                    all.push((parseInt(parts[i]) || 0) / 1000);
                const out = [];
                let peak = 0;
                for (let b = 0; b < root.bars; b++) {
                    const lo = Math.floor(b * n / root.bars);
                    const hi = Math.max(lo + 1, Math.floor((b + 1) * n / root.bars));
                    let v = 0;
                    for (let j = lo; j < hi; j++)
                        v += all[j];
                    v /= hi - lo;
                    out.push(v);
                    if (v > peak)
                        peak = v;
                }
                if (n > root.bars)
                    root.spectrum = all;
                /**
                 * Skips the 60Hz levels update while the frame and the stored levels are already flat.
                 */
                const flat = peak <= 0.001 && !root.active;
                if (!flat)
                    root.levels = out;
                if (peak > 0.02) {
                    root.active = true;
                    idle.restart();
                }
            }
        }
        /** A crash while cava is still wanted earns one relaunch after a beat, never a tight respawn loop. */
        onExited: if (root.wanted) relaunch.restart()
    }

    Timer {
        id: relaunch
        interval: 1500
        onTriggered: if (root.wanted) cavaProc.running = true
    }

    /** Short debounce so inter-track gaps do not snap the morph back to the clock. */
    Timer {
        id: idle
        interval: 450
        onTriggered: root.active = false
    }
}
