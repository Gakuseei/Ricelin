pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Warm snapshot of the wallpaper folder so the strip opens instantly, applying picks through wallpaper.sh to share its transition and state with the random keybind.
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property string current: ""
    property bool pending: false

    property string resolvedDir: ""
    readonly property string wpDir: Flags.wallpaperDir.length > 0 ? Flags.wallpaperDir
        : (resolvedDir.length > 0 ? resolvedDir : Quickshell.env("HOME") + "/Ricelin/wallpapers")
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin-wp-thumbs/"
    readonly property string thumbScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-thumbs.sh"
    readonly property string setScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin-wallpaper"
    readonly property string dirStateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin-wallpaper-dir"

    onWpDirChanged: refresh()

    FileView {
        id: dirFile
        path: root.dirStateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.resolvedDir = dirFile.text().trim()
        onFileChanged: reload()
        onLoadFailed: root.resolvedDir = ""
    }

    function refresh() {
        if (resolveProc.running || thumbProc.running || listProc.running || stateProc.running) {
            pending = true;
            return;
        }
        /**
         * Autodetect only runs inside wallpaper.sh, so re-resolve the folder first or a shell restart leaves the strip on a stale state file.
         */
        if (Flags.wallpaperDir.length > 0) {
            thumbProc.running = true;
            return;
        }
        resolveProc.command = ["bash", root.setScript, "resolve"];
        resolveProc.running = true;
    }

    Process {
        id: resolveProc
        onExited: thumbProc.running = true
    }

    /**
     * wallpaper.sh blocks for the whole 1-2s transition, so the newest pick is queued and replayed instead of being swallowed.
     */
    property string queuedApply: ""
    property string queuedOutput: ""

    function apply(path, output) {
        var out = output === undefined ? "" : output;
        if (applyProc.running) {
            queuedApply = path;
            queuedOutput = out;
            return;
        }
        applyProc.command = out.length > 0
            ? ["bash", root.setScript, "set", path, out]
            : ["bash", root.setScript, "set", path];
        applyProc.running = true;
    }

    function trash(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].path !== path)
                kept.push(entries[i]);
        entries = kept;
    }

    Process {
        id: trashProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", root.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var path = lines[i].substring(tab + 1);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    out.push({
                        path: path,
                        name: name,
                        mtime: parseFloat(lines[i].substring(0, tab)),
                        thumb: root.thumbDir + name + ".png"
                    });
                }
                root.entries = out;
                stateProc.running = true;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                if (root.pending) {
                    root.pending = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                var nextOut = root.queuedOutput;
                root.queuedApply = "";
                root.queuedOutput = "";
                applyProc.command = nextOut.length > 0
                    ? ["bash", root.setScript, "set", next, nextOut]
                    : ["bash", root.setScript, "set", next];
                applyProc.running = true;
                return;
            }
            stateProc.running = true;
        }
    }

    Component.onCompleted: refresh()
}
