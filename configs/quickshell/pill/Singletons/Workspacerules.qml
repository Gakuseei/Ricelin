pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Workspace to monitor map from `hyprctl workspacerules`, so the dots show every workspace monitors.lua assigns before it is visited.
 */
Singleton {
    id: root

    property var byMonitor: ({})

    function refresh() {
        proc.running = true;
    }

    Process {
        id: proc
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                try {
                    var rules = JSON.parse(this.text);
                    for (var i = 0; i < rules.length; i++) {
                        var ws = parseInt(rules[i].workspaceString);
                        var mon = rules[i].monitor;
                        if (!mon || isNaN(ws))
                            continue;
                        if (!map[mon])
                            map[mon] = [];
                        map[mon].push(ws);
                    }
                } catch (e) {
                    return;
                }
                for (var k in map)
                    map[k].sort(function (a, b) { return a - b; });
                root.byMonitor = map;
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
