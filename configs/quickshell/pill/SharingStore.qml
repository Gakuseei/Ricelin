import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: imageStore

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin/dragdrop"

    property var entries: []
    property bool copying: false

    function addFiles(urls) {
        if (copying) return;

        var validPaths = [];
        for (var i = 0; i < urls.length; i++) {
            var urlStr = urls[i].toString();
            var path = decodeURIComponent(urlStr.indexOf("file://") === 0 ? urlStr.substring(7) : urlStr);
            if (path.length > 0) {
                validPaths.push(path);
            }
        }

        if (validPaths.length === 0) return;

        copying = true;
        copyProc.command = ["sh", "-c", 'dest="$1"; shift; mkdir -p "$dest" && cp -r "$@" "$dest"', "_", cacheDir].concat(validPaths);
        copyProc.running = true;
    }

    function clear() {
        clearProc.running = true;
    }

    function refresh() {
        listProc.running = true;
    }

    function deleteFile(path) {
        deleteSingleProc.command = ["rm", "-rf", path];
        deleteSingleProc.running = true;
    }

    property Process copyProc: Process {
        onExited: (exitCode) => {
            imageStore.copying = false;
            if (exitCode === 0) {
                imageStore.refresh();
            }
        }
    }

    property Process listProc: Process {
        command: ["sh", "-c", "find \"$1\" -mindepth 1 -maxdepth 1 -printf '%y:%p\\n' 2>/dev/null", "_", imageStore.cacheDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.length === 0) continue;
                    var colonIndex = line.indexOf(":");
                    if (colonIndex === -1) continue;
                    var typeChar = line.substring(0, colonIndex);
                    var path = line.substring(colonIndex + 1);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    var isDir = typeChar === "d";
                    var ext = path.split('.').pop().toLowerCase();
                    var isImage = !isDir && (ext === "png" || ext === "jpg" || ext === "jpeg" || ext === "webp" || ext === "gif" || ext === "svg");
                    var isVideo = !isDir && (ext === "mp4" || ext === "mkv" || ext === "webm" || ext === "avi" || ext === "mov" || ext === "flv" || ext === "wmv");
                    var isMusic = !isDir && (ext === "mp3" || ext === "wav" || ext === "ogg" || ext === "flac" || ext === "m4a" || ext === "aac" || ext === "opus" || ext === "wma");
                    out.push({
                        path: path,
                        name: name,
                        url: "file://" + path,
                        isDir: isDir,
                        isImage: isImage,
                        isVideo: isVideo,
                        isMusic: isMusic
                    });
                }
                imageStore.entries = out;
            }
        }
    }

    property Process clearProc: Process {
        command: ["sh", "-c", "rm -rf \"$1\"/*", "_", imageStore.cacheDir]
        onExited: {
            imageStore.refresh();
        }
    }

    property Process deleteSingleProc: Process {
        onExited: {
            imageStore.refresh();
        }
    }

    Component.onCompleted: refresh()
}
