pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Coding agent sessions that wait for Erik or just finished, written by hypr/scripts/agent-state.sh.
 */
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-agents"
    readonly property int doneSeconds: 8
    property var sessions: []
    readonly property var waiting: sessions.filter(a => a.status === "wait")
    readonly property var done: sessions.filter(a => a.status === "done")
    readonly property var top: waiting.length > 0 ? waiting[0] : (done.length > 0 ? done[0] : null)

    function drop(a) {
        Quickshell.execDetached(["rm", "-f", root.dir + "/" + a.session + ".json"]);
        root.sessions = root.sessions.filter(x => x.session !== a.session);
    }

    /**
     * Looking at the session's terminal answers the notice, so it leaves the pill.
     */
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            const addr = t ? String(t.address).replace(/^0x/, "") : "";
            if (addr.length === 0)
                return;
            for (const a of root.sessions)
                if (a.window && String(a.window).replace(/^0x/, "") === addr)
                    root.drop(a);
        }
    }

    function project(a) {
        const c = a && a.cwd ? String(a.cwd) : "";
        return c.length > 0 ? c.substring(c.lastIndexOf("/") + 1) : "Claude";
    }

    /**
     * Jumps to the session's terminal and lets a finished session go.
     */
    function focus(a) {
        if (!a)
            return;
        if (a.window && a.window.length > 0)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + a.window + "\" })");
        root.drop(a);
    }

    function reload() {
        if (!scan.running)
            scan.running = true;
    }

    Process {
        id: scan
        command: ["sh", "-c", "for f in \"$1\"/*.json; do [ -f \"$f\" ] && printf '%s\\t%s\\n' \"$(basename \"$f\" .json)\" \"$(cat \"$f\")\"; done", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    try {
                        const a = JSON.parse(line.slice(tab + 1));
                        a.session = line.slice(0, tab);
                        out.push(a);
                    } catch (e) {}
                }
                out.sort((x, y) => (y.at || 0) - (x.at || 0));
                root.sessions = out;
            }
        }
    }

    FileView {
        path: root.dir + "/.bump"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
        onLoaded: root.reload()
    }

    /**
     * A finished session is a short notice; a waiting one stays until Erik answers or looks at it.
     */
    Timer {
        interval: 1000
        running: root.done.length > 0
        repeat: true
        onTriggered: {
            const now = Date.now() / 1000;
            for (const a of root.done)
                if (now - (a.at || 0) >= root.doneSeconds)
                    root.drop(a);
        }
    }
}
