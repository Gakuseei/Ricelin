import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

AppPage {
    id: page
    pageId: "idlelock"

    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    readonly property var lockOptions: [0, 1, 3, 5, 10, 15]
    readonly property var screenOptions: [0, 3, 5, 10, 15]
    readonly property var suspendOptions: [0, 15, 30, 60]

    /** A value hand-edited outside the list shows as its own option instead of being rounded away. */
    function optionsFor(list, current) {
        const vals = list.indexOf(current) >= 0 || !(current > 0) ? list : list.concat([current]).sort((a, b) => a - b);
        return vals.map(v => ({ label: v === 0 ? "Off" : String(v), value: v }));
    }

    /** Full hypridle.conf: the general block plus one listener per non-zero timeout, minutes written as seconds. */
    function buildConf() {
        let out = "general {\n"
            + "    lock_cmd = " + page.lockScript + "\n"
            + "    before_sleep_cmd = loginctl lock-session\n"
            + "    inhibit_sleep = 3\n"
            + "    after_sleep_cmd = hyprctl dispatch \"hl.dsp.dpms({ action = 'on' })\"\n"
            + "}\n";

        if (Flags.idleLockMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleLockMin * 60) + "\n"
                + "    on-timeout = " + page.lockScript + "\n"
                + "}\n";

        if (Flags.idleScreenOffMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleScreenOffMin * 60) + "\n"
                + "    on-timeout = hyprctl dispatch \"hl.dsp.dpms({ action = 'off' })\"\n"
                + "    on-resume = hyprctl dispatch \"hl.dsp.dpms({ action = 'on' })\"\n"
                + "}\n";

        if (Flags.idleSuspendMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleSuspendMin * 60) + "\n"
                + "    on-timeout = systemctl suspend\n"
                + "}\n";

        return out;
    }

    function apply() {
        confWriter.setText(buildConf());
        restartProc.running = true;
    }

    function reset() {
        Flags.idleLockMin = 5;
        Flags.idleScreenOffMin = 6;
        Flags.idleSuspendMin = 0;
        Flags.lockUseFont = true;
        Flags.lockSeconds = false;
        apply();
    }

    FileView {
        id: confWriter
        path: page.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "hypridle"]
    }

    AppGroup {
        title: "When idle"
        hint: "Keep awake in the mixer pauses all of this while it is on"

        AppRow {
            label: "Lock after"
            sub: "Minutes without input before the screen locks"
            key: "idle.lock"
            AppSeg {
                options: page.optionsFor(page.lockOptions, Flags.idleLockMin)
                value: Flags.idleLockMin
                onPicked: (v) => { Flags.idleLockMin = v; page.apply(); }
            }
        }
        AppRow {
            label: "Screen off"
            sub: "Minutes until the screens go dark"
            key: "idle.screenOff"
            AppSeg {
                options: page.optionsFor(page.screenOptions, Flags.idleScreenOffMin)
                value: Flags.idleScreenOffMin
                onPicked: (v) => { Flags.idleScreenOffMin = v; page.apply(); }
            }
        }
        AppRow {
            label: "Suspend"
            sub: "Minutes until the PC goes to sleep"
            key: "idle.suspend"
            AppSeg {
                options: page.optionsFor(page.suspendOptions, Flags.idleSuspendMin)
                value: Flags.idleSuspendMin
                onPicked: (v) => { Flags.idleSuspendMin = v; page.apply(); }
            }
        }
    }

    AppGroup {
        title: "Lock screen"
        AppRow {
            label: "Show seconds"
            sub: "Adds seconds to the lock screen clock"
            key: "idle.lockSeconds"
            clickable: true
            onClicked: Flags.lockSeconds = !Flags.lockSeconds
            AppToggle {
                checked: Flags.lockSeconds
                onToggled: (on) => Flags.lockSeconds = on
            }
        }

        advanced: [
            AppRow {
                label: "Use UI font"
                sub: "The lock clock uses the font from Appearance"
                key: "idle.lockFont"
                clickable: true
                onClicked: Flags.lockUseFont = !Flags.lockUseFont
                AppToggle {
                    checked: Flags.lockUseFont
                    onToggled: (on) => Flags.lockUseFont = on
                }
            }
        ]
    }
}
