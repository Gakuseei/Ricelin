pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 錠 IDLE / LOCK: three idle timeouts in minutes (0 = off); any pick rewrites hypridle.conf and restarts hypridle.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    readonly property var lockOptions: [
        { label: "Off", value: 0 }, { label: "1", value: 1 }, { label: "3", value: 3 },
        { label: "5", value: 5 }, { label: "10", value: 10 }, { label: "15", value: 15 }
    ]
    readonly property var screenOptions: [
        { label: "Off", value: 0 }, { label: "3", value: 3 }, { label: "5", value: 5 },
        { label: "10", value: 10 }, { label: "15", value: 15 }
    ]
    readonly property var suspendOptions: [
        { label: "Off", value: 0 }, { label: "15", value: 15 },
        { label: "30", value: 30 }, { label: "60", value: 60 }
    ]

    rows: [
        { item: lockRow, kind: "seg", vals: root.lockOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleLockMin; }, set: function (v) { Flags.idleLockMin = v; root.apply(); } },
        { item: screenRow, kind: "seg", vals: root.screenOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleScreenOffMin; }, set: function (v) { Flags.idleScreenOffMin = v; root.apply(); } },
        { item: suspendRow, kind: "seg", vals: root.suspendOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleSuspendMin; }, set: function (v) { Flags.idleSuspendMin = v; root.apply(); } }
    ]

    /**
     * Full hypridle.conf: the general block plus one listener per non-zero timeout, minutes written as seconds.
     */
    function buildConf() {
        var out = "general {\n"
            + "    lock_cmd = " + root.lockScript + "\n"
            + "    before_sleep_cmd = loginctl lock-session\n"
            + "    inhibit_sleep = 3\n"
            + "    after_sleep_cmd = hyprctl dispatch \"hl.dsp.dpms({ action = 'on' })\"\n"
            + "}\n";

        if (Flags.idleLockMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleLockMin * 60) + "\n"
                + "    on-timeout = " + root.lockScript + "\n"
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

    FileView {
        id: confWriter
        path: root.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "hypridle"]
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            s: root.s
            glyph: "錠"
            title: "IDLE / LOCK"
            canBack: true
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        SettingsRow {
            id: lockRow
            surface: root
            icon: "lock"
            name: "Auto-lock"
            sub: "Minutes until lock"

            SettingsSeg {
                s: root.s
                options: root.lockOptions
                value: Flags.idleLockMin
                onPicked: (v) => { Flags.idleLockMin = v; root.apply(); }
            }
        }

        SettingsRow {
            id: screenRow
            surface: root
            icon: "monitor"
            name: "Screen off"
            sub: "Minutes until blank"

            SettingsSeg {
                s: root.s
                options: root.screenOptions
                value: Flags.idleScreenOffMin
                onPicked: (v) => { Flags.idleScreenOffMin = v; root.apply(); }
            }
        }

        SettingsRow {
            id: suspendRow
            surface: root
            icon: "suspend"
            name: "Suspend"
            sub: "Minutes until sleep"
            last: true

            SettingsSeg {
                s: root.s
                options: root.suspendOptions
                value: Flags.idleSuspendMin
                onPicked: (v) => { Flags.idleSuspendMin = v; root.apply(); }
            }
        }

        Text {
            width: parent.width
            topPadding: Theme.sp.m * root.s
            leftPadding: Theme.sp.m * root.s
            rightPadding: Theme.sp.m * root.s
            text: "Keep-awake in the mixer pauses all of this while it is on."
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            wrapMode: Text.WordWrap
        }
    }
}
