pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * One debounced `hyprctl reload` for every config writer, game mode stripped again after it.
 */
Singleton {
    id: root

    property bool failed: false

    function request() {
        timer.restart();
    }

    Timer {
        id: timer
        interval: 250
        onTriggered: {
            if (proc.running)
                restart();
            else
                proc.running = true;
        }
    }

    Process {
        id: proc
        command: ["hyprctl", "reload"]
        onExited: function (exitCode) {
            root.failed = exitCode !== 0;
            if (GameMode.active)
                GameMode.run("on");
        }
    }
}
