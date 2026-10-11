pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    readonly property string home:
        Quickshell.env("HOME")

    readonly property string cameraDir:
        home + "/Pictures/Ricelin/Camera"

    readonly property string cacheRoot:
        (Quickshell.env("XDG_CACHE_HOME") ||
         (home + "/.cache")) +
        "/ricelin/camera-thumbs"

    property var recent: []
    readonly property int recentCount: recent.length

    property int maxItems: 18

    Process {
        id: scanProc

        stdout: StdioCollector {}

        command: [
            "sh",
            "-c",
            "find " +
            "'" + root.qsReplaceAll(root.cameraDir, "'", "'\\''") + "'" +
            " -maxdepth 1 -type f " +
            "\\( " +
            "-iname '*.jpg' -o " +
            "-iname '*.jpeg' -o " +
            "-iname '*.png' -o " +
            "-iname '*.webp' -o " +
            "-iname '*.mp4' -o " +
            "-iname '*.mkv' -o " +
            "-iname '*.mov' " +
            "\\) " +
            "-printf '%T@\\t%s\\t%p\\n' 2>/dev/null"
        ]

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("MediaRec: camera scan failed")
                return
            }

            root.rebuild(String(stdout.text))
        }
    }

    Process {
        id: thumbProc

        command: [
            "sh",
            "-c",
            "mkdir -p " +
            "'" + root.qsReplaceAll(root.cacheRoot, "'", "'\\''") + "'" +
            " && find " +
            "'" + root.qsReplaceAll(root.cameraDir, "'", "'\\''") + "'" +
            " -maxdepth 1 -type f " +
            "\\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' " +
            "-o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "-print0 | while IFS= read -r -d '' f; do " +
            "b=$(basename \"$f\"); " +
            "case \"$f\" in " +
            "*.jpg|*.JPG|*.jpeg|*.JPEG|*.png|*.PNG|*.webp|*.WEBP) " +
            ";; " +
            "*.mp4|*.MP4|*.mkv|*.MKV|*.mov|*.MOV) " +
            "out=\"" + root.qsReplaceAll(root.cacheRoot, "'", "'\\''") +
            "/${b%.*}.jpg\"; " +
            "if [ ! -s \"$out\" ] || [ \"$f\" -nt \"$out\" ]; then " +
            "ffmpeg -hide_banner -loglevel error -y " +
            "-ss 00:00:01 -i \"$f\" -frames:v 1 " +
            "-vf 'scale=640:-2' \"$out\"; " +
            "fi; " +
            ";; " +
            "esac; " +
            "done"
        ]

        onExited: function(exitCode) {
            root.scanCamera()
        }
    }

    function qsReplaceAll(text, needle, replacement) {
        return String(text).split(String(needle)).join(String(replacement))
    }

    function shellQuote(path) {
        return "'" + root.qsReplaceAll(path, "'", "'\\''") + "'"
    }

    function localFileUrl(path) {
        var p = String(path || "")

        if (!p)
            return ""

        if (p.indexOf("file://") === 0)
            return p

        if (p.indexOf("file:") === 0)
            return p

        // Absolute local path -> exactly three slashes after file:
        if (p.charAt(0) === "/")
            return "file://" + p

        return "file:///" + p
    }

    function filename(path) {
        var p = String(path).split("/")
        return p.length ? p[p.length - 1] : String(path)
    }

    function extension(path) {
        var n = filename(path).toLowerCase()
        var i = n.lastIndexOf(".")
        return i >= 0 ? n.slice(i + 1) : ""
    }

    function classify(path) {
        var n = filename(path).toLowerCase()

        if (n.indexOf("photo_") === 0)
            return "photo"

        if (n.indexOf("video_") === 0)
            return "cameraVideo"

        if (n.indexOf("recording_") === 0)
            return "screen"

        return "video"
    }

    function cameraThumbnail(path, kind) {
        if (!path)
            return ""

        var p = String(path)
        var n = filename(p).toLowerCase()

        // Photos display directly.
        if (n.endsWith(".jpg") ||
            n.endsWith(".jpeg") ||
            n.endsWith(".png") ||
            n.endsWith(".webp")) {
            return root.localFileUrl(p)
        }

        // Videos use the cached preview frame.
        var dot = n.lastIndexOf(".")
        if (dot < 0)
            return ""

        var base = n.slice(0, dot)
        return root.localFileUrl(root.cacheRoot + "/" + base + ".jpg")
    }

    function rebuild(cameraText) {
        var merged = []

        // -------------------------------------------------------------
        // Existing ScreenRec media
        // -------------------------------------------------------------

        var screenItems = ScreenRec.recent || []

        for (var i = 0; i < screenItems.length; ++i) {
            var s = screenItems[i]

            merged.push({
                path: s.path || s.file || "",
                name: s.name || "",
                thumb: s.thumb || "",
                kind: "screen",
                mtime: Number(s.mtime || s.timestamp || 0),
                size: Number(s.size || 0)
            })
        }

        // -------------------------------------------------------------
        // Camera media
        // -------------------------------------------------------------

        var lines = String(cameraText)
            .split("\n")

        for (var j = 0; j < lines.length; ++j) {
            var line = lines[j]

            if (!line)
                continue

            var cols = line.split("\t")

            if (cols.length < 3)
                continue

            var mtime = Number(cols[0])
            var size = Number(cols[1])
            var path = cols.slice(2).join("\t")

            if (!path)
                continue

            var kind = classify(path)
            var normalizedPath = path.indexOf("file://") === 0
                ? path
                : path

            merged.push({
                path: normalizedPath,
                name: filename(path),
                thumb: cameraThumbnail(normalizedPath, kind),
                kind: kind,
                mtime: mtime,
                size: isFinite(size) ? size : 0
            })
        }

        merged.sort(function(a, b) {
            return Number(b.mtime) - Number(a.mtime)
        })

        recent = merged.slice(
            0,
            Math.max(1, Number(maxItems))
        )
    }

    function refresh() {
        if (!thumbProc.running)
            thumbProc.running = true
    }

    function scanCamera() {
        if (scanProc.running)
            return

        scanProc.running = true
    }

    function remove(path) {
        if (!path)
            return

        removeProc.targetPath = path
        removeProc.command = [
            "rm",
            "-f",
            path
        ]
        removeProc.running = true
    }

    Process {
        id: removeProc

        property string targetPath: ""

        onExited: function(exitCode) {
            if (exitCode === 0)
                root.refresh()
        }
    }

    function open(path) {
        if (!path)
            return

        Quickshell.execDetached([
            "xdg-open",
            path
        ])
    }

    function reveal(path) {
        if (!path)
            return

        Quickshell.execDetached([
            "xdg-open",
            "file://" +
            path.slice(
                0,
                path.lastIndexOf("/")
            )
        ])
    }

    function clearRecent() {
        refresh()
    }

    Connections {
        target: ScreenRec

        function onRecentChanged() {
            root.refresh()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
