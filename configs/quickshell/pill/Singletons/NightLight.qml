pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 灯 Night-light controller over hyprsunset that pushes Off and On live over IPC and hands scheduled mode to the daemon via hyprsunset.conf.
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
     * A scrub tick that lands while hyprctl is still running is folded into the re-push on exit, so the final value always arrives.
     */
    function pushLive() {
        if (ipc.running)
            return;
        ipc.command = root.desiredCmd();
        ipc.running = true;
    }

    property bool pendingRestart: false

    /**
     * The conf write and daemon restart are debounced so a scrub flurry collapses into one write and one restart.
     */
    function commit(restart) {
        if (restart)
            root.pendingRestart = true;
        confTimer.restart();
        root.pushLive();
    }

    /**
     * Every mode change re-arms the daemon, or its stale 0:00 profile flips the choice back at midnight.
     */
    function setMode(m) {
        Flags.nightLightMode = m;
        root.commit(true);
    }

    function setTemp(t) {
        Flags.nightLightTemp = root.clampTemp(t);
        root.commit(Flags.nightLightMode !== "off");
    }

    function setOnMin(v) {
        Flags.nightLightOnMin = v;
        root.commit(Flags.nightLightMode === "scheduled");
    }

    function setOffMin(v) {
        Flags.nightLightOffMin = v;
        root.commit(Flags.nightLightMode === "scheduled");
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
            if (root.pendingRestart) {
                root.pendingRestart = false;
                restartProc.running = true;
            }
        }
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "hyprsunset"]
    }
}
