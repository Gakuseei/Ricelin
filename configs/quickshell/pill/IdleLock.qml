pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 錠 IDLE / LOCK sub-surface: the three idle timeouts that drive hypridle, each
 * held in minutes (0 = off). Auto-lock runs the lock script, screen-off blanks
 * the display through DPMS, and suspend sleeps the machine. Any pick regenerates
 * the whole hypridle.conf from the current values and restarts hypridle, so the
 * change lands without a hand edit. Keep-awake in the mixer already inhibits the
 * Wayland idle notification, which pauses every listener while it is on, so this
 * surface never touches that wiring. Reached from the settings index and morphs
 * back to it on an empty click or the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    readonly property var lockOptions: [
        { label: "Off", value: 0 }, { label: "1 min", value: 1 }, { label: "3 min", value: 3 },
        { label: "5 min", value: 5 }, { label: "10 min", value: 10 }, { label: "15 min", value: 15 }
    ]
    readonly property var screenOptions: [
        { label: "Off", value: 0 }, { label: "3 min", value: 3 }, { label: "5 min", value: 5 },
        { label: "10 min", value: 10 }, { label: "15 min", value: 15 }
    ]
    readonly property var suspendOptions: [
        { label: "Off", value: 0 }, { label: "15 min", value: 15 },
        { label: "30 min", value: 30 }, { label: "60 min", value: 60 }
    ]

    rows: [
        { item: lockRow, kind: "seg", vals: root.lockOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleLockMin; }, set: function (v) { Flags.idleLockMin = v; root.apply(); } },
        { item: screenRow, kind: "seg", vals: root.screenOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleScreenOffMin; }, set: function (v) { Flags.idleScreenOffMin = v; root.apply(); } },
        { item: suspendRow, kind: "seg", vals: root.suspendOptions.map(function (o) { return o.value; }), get: function () { return Flags.idleSuspendMin; }, set: function (v) { Flags.idleSuspendMin = v; root.apply(); } }
    ]

    /**
     * Builds the full hypridle.conf from the three flag values. The general block
     * is always present; a listener block is appended only for each non-zero
     * timeout, in the order lock, screen-off, suspend. Minutes are written out as
     * seconds.
     */
    function buildConf() {
        var out = "general {\n"
            + "    lock_cmd = " + root.lockScript + "\n"
            + "    before_sleep_cmd = " + root.lockScript + " sleep\n"
            + "    after_sleep_cmd = sh -c \"hyprctl dispatch dpms on; sleep 0.05; qs -c lock ipc call lock reveal >/dev/null 2>&1\"\n"
            + "}\n";

        if (Flags.idleLockMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleLockMin * 60) + "\n"
                + "    on-timeout = " + root.lockScript + "\n"
                + "}\n";

        if (Flags.idleScreenOffMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleScreenOffMin * 60) + "\n"
                + "    on-timeout = hyprctl dispatch dpms off\n"
                + "    on-resume = hyprctl dispatch dpms on\n"
                + "}\n";

        if (Flags.idleSuspendMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleSuspendMin * 60) + "\n"
                + "    on-timeout = loginctl suspend\n"
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
        command: ["sh", "-c", "pkill -x hypridle; hypridle >/dev/null 2>&1 &"]
    }

    /**
     * One idle row: name and caption on their own full-width line with the
     * segmented control stacked below, so a six-option strip never squeezes the
     * caption into a narrow wrapping column. Hover lights the row and feeds the
     * soul seam, matching the rest of the settings rows.
     */
    component IdleRow: Item {
        id: irow
        property string name: ""
        property string caption: ""
        property bool last: false
        default property alias seg: segSlot.data
        readonly property real s: root.s

        width: parent ? parent.width : 0
        height: col.implicitHeight + 22 * irow.s

        HoverHandler {
            id: ih
            onHoveredChanged: root.reportRowHover(irow, hovered)
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3 * irow.s
            anchors.bottomMargin: 3 * irow.s
            radius: 9 * irow.s
            color: (ih.hovered || root.focusRowItem === irow) ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * irow.s
            anchors.rightMargin: 12 * irow.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * irow.s

            Text {
                text: irow.name
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * irow.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: irow.caption.length > 0
                text: irow.caption
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * irow.s
            }
            Item { width: 1; height: 7 * irow.s }
            Item {
                id: segSlot
                width: childrenRect.width
                height: childrenRect.height
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
            visible: !irow.last
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "錠"
            title: "IDLE / LOCK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        IdleRow {
            id: lockRow
            name: "Auto-lock"
            caption: "Lock the screen after idle"

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.lockOptions
                value: Flags.idleLockMin
                onPicked: (v) => { Flags.idleLockMin = v; root.apply(); }
            }
        }

        IdleRow {
            id: screenRow
            name: "Screen off"
            caption: "Blank the display after idle"

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.screenOptions
                value: Flags.idleScreenOffMin
                onPicked: (v) => { Flags.idleScreenOffMin = v; root.apply(); }
            }
        }

        IdleRow {
            id: suspendRow
            name: "Suspend"
            caption: "Sleep the machine after idle"
            last: true

            SettingsSeg {
                s: root.s
                flushLeft: true
                options: root.suspendOptions
                value: Flags.idleSuspendMin
                onPicked: (v) => { Flags.idleSuspendMin = v; root.apply(); }
            }
        }

        Text {
            topPadding: 12 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: "Keep-awake (in the mixer) pauses all of this while it is on."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 * root.s }
    }
}
