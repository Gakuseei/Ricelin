pragma Singleton
import QtQuick
import Quickshell

/**
 * One countdown at a time that chimes and notifies at zero; the resting pill shows it while it runs.
 */
Singleton {
    id: root

    property double endsAt: 0
    property int total: 0
    property int pausedLeft: 0
    property int left: 0

    readonly property bool running: endsAt > 0
    readonly property bool paused: pausedLeft > 0
    readonly property bool active: running || paused
    readonly property real progress: total > 0 ? 1 - left / total : 0
    readonly property string label: fmt(left)

    function start(seconds) {
        total = Math.max(1, Math.round(seconds));
        pausedLeft = 0;
        endsAt = Date.now() + total * 1000;
        tick();
    }

    function pause() {
        if (!running)
            return;
        pausedLeft = Math.max(1, Math.ceil((endsAt - Date.now()) / 1000));
        endsAt = 0;
        tick();
    }

    function resume() {
        if (!paused)
            return;
        endsAt = Date.now() + pausedLeft * 1000;
        pausedLeft = 0;
        tick();
    }

    function cancel() {
        endsAt = 0;
        pausedLeft = 0;
        total = 0;
        left = 0;
    }

    function tick() {
        left = running ? Math.max(0, Math.ceil((endsAt - Date.now()) / 1000)) : pausedLeft;
        if (running && left === 0) {
            const mins = Math.round(total / 60);
            cancel();
            Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]);
            Quickshell.execDetached(["notify-send", "-a", "Ricelin", "-i", "alarm-clock", "Timer done",
                mins > 0 ? mins + " min are up" : "Time is up"]);
        }
    }

    function fmt(sec) {
        const h = Math.floor(sec / 3600);
        const m = Math.floor(sec % 3600 / 60);
        const s = sec % 60;
        const ss = String(s).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }

    Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }
}
