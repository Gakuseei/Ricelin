pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Game mode that strips Hyprland eye-candy via gamemode.sh and quiets the desktop, with `Flags.gameMode` as the single source of truth.
 */
Singleton {
    id: root

    readonly property bool active: Flags.gameMode
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode.sh"
    property string pending: ""

    onActiveChanged: active ? root.enter() : root.leave()

    function enter() {
        Flags.gamePrevDnd = Flags.dnd;
        Flags.gamePrevViz = Flags.musicViz;
        Flags.gamePrevAwake = Flags.keepAwake;
        Flags.dnd = true;
        Flags.musicViz = false;
        Flags.keepAwake = true;
        root.run("on");
    }

    function leave() {
        root.run("off");
        Flags.dnd = Flags.gamePrevDnd;
        Flags.musicViz = Flags.gamePrevViz;
        Flags.keepAwake = Flags.gamePrevAwake;
    }

    function run(arg) {
        if (proc.running) {
            root.pending = arg;
            return;
        }
        proc.command = ["bash", root.script, arg];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: {
            if (root.pending.length === 0)
                return;
            var a = root.pending;
            root.pending = "";
            proc.command = ["bash", root.script, a];
            proc.running = true;
        }
    }
}
