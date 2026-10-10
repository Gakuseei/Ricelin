pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 灯 Night-light controller over hyprsunset, the Hyprland blue-light filter.
 * Off and On push straight to the running daemon over its IPC, so the screen
 * warms or clears at once with no service flicker. Scheduled mode writes a
 * two-profile hyprsunset.conf and restarts the service, handing the clock to the
 * daemon so the tint flips at the set times on its own and survives a logout.
 * The mode, warmth and the two times all live in Flags, so the pill and a fresh
 * login restore the same state. The service is enabled once at install, which is
 * why nothing here ever starts it; it is already up under the graphical session.
 */
Singleton {
    id: root

    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/hyprsunset.conf"

    function clampTemp(t) {
        return Math.max(2200, Math.min(6000, Math.round(t)));
    }

    function nowMin() {
        var d = clock.date;
        return d.getHours() * 60 + d.getMinutes();
    }

    /** True while the clock sits inside the on→off window, with the wrap past midnight handled. */
    function windowOpen() {
        var on = Flags.nightLightOnMin;
        var off = Flags.nightLightOffMin;
        var n = root.nowMin();
        return on <= off ? (n >= on && n < off) : (n >= on || n < off);
    }

    function hhmm(min) {
        var h = Math.floor(min / 60);
        var m = min % 60;
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    /** hyprsunset.conf for the current Flags. Off and On are one all-day profile, Scheduled is two. */
    function buildConf() {
        var out = "max-gamma = 150\n\n";
        if (Flags.nightLightMode === "scheduled") {
            out += "profile {\n    time = " + root.hhmm(Flags.nightLightOnMin)
                + "\n    temperature = " + root.clampTemp(Flags.nightLightTemp) + "\n}\n\n"
                + "profile {\n    time = " + root.hhmm(Flags.nightLightOffMin)
                + "\n    identity = true\n}\n";
        } else if (Flags.nightLightMode === "on") {
            out += "profile {\n    time = 0:00\n    temperature = "
                + root.clampTemp(Flags.nightLightTemp) + "\n}\n";
        } else {
            out += "profile {\n    time = 0:00\n    identity = true\n}\n";
        }
        return out;
    }

    /** The IPC command the current mode and clock resolve to. */
    function desiredCmd() {
        var warm = Flags.nightLightMode === "on"
            || (Flags.nightLightMode === "scheduled" && root.windowOpen());
        return warm
            ? ["hyprctl", "hyprsunset", "temperature", String(root.clampTemp(Flags.nightLightTemp))]
            : ["hyprctl", "hyprsunset", "identity"];
    }

    /**
     * Pushes the resolved state to the live daemon at once. A scrub tick that
     * lands while the prior hyprctl is still running is folded into the trailing
     * re-push in the process exit handler, so the final value always arrives.
     */
    function pushLive() {
        if (ipc.running)
            return;
        ipc.command = root.desiredCmd();
        ipc.running = true;
    }

    /**
     * Persists conf for the next login and pushes live now. The conf write and
     * the daemon re-arm are both debounced, so a scrub flurry collapses into one
     * write and one restart.
     */
    function commit() {
        confTimer.restart();
        root.pushLive();
    }

    /**
     * Re-arm is needed whenever scheduled sits on either side of the change, so
     * the daemon never holds stale profiles that would override the new choice at
     * the next clock boundary. Pure off↔on rides the IPC push alone, since its
     * conf is a single all-day profile that only fires at 0:00.
     */
    function setMode(m) {
        Flags.nightLightMode = m;
        root.commit();
    }

    function setTemp(t) {
        Flags.nightLightTemp = root.clampTemp(t);
        root.commit();
    }

    function setOnMin(v) {
        Flags.nightLightOnMin = v;
        root.commit();
    }

    function setOffMin(v) {
        Flags.nightLightOffMin = v;
        root.commit();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: writer
        path: root.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: ipc
        command: []
        onExited: {
            var want = root.desiredCmd();
            if (want.join(" ") !== ipc.command.join(" ")) {
                ipc.command = want;
                ipc.running = true;
            }
        }
    }

    /** Debounced conf write, then a re-arm restart when a scheduled change asked for one. */
    Timer {
        id: confTimer
        interval: 250
        onTriggered: {
            writer.setText(root.buildConf());
        }
    }

}
