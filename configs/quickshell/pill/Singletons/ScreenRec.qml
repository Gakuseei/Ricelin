pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Screen-recorder backend over gpu-screen-recorder for the 録 RECORD surface, hover cluster and OSD, which picks the target before any countdown starts.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string defaultDir: home + "/Videos/Recordings"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/ricelin/rec-thumbs/"
    readonly property string thumbScript: home + "/.config/hypr/scripts/rec-thumbs.sh"
    readonly property string outDir: {
        var d = Flags.recordDir;
        return d && d.length > 0 ? d : defaultDir;
    }

    onOutDirChanged: if (recorderOpen) refreshRecent()

    readonly property int fps: Flags.recordFps
    readonly property string quality: Flags.recordQuality
    readonly property bool captureCursor: Flags.recordCursor
    readonly property bool micOn: Flags.recordMic
    readonly property bool desktopOn: Flags.recordDesktop

    property bool recording: false
    /**
     * Counted, not a bool: two monitors' surfaces open and close in any order.
     */
    property int recorderOpenCount: 0
    readonly property bool recorderOpen: recorderOpenCount > 0
    property var currentFiles: []
    property var recent: []
    readonly property int recentCount: recent.length

    /**
     * The pre-roll countdown lives here and not in the surface, so the quick-record keybind gets it with no surface open.
     */
    property int countdown: 0
    readonly property bool counting: countdown > 0
    property string pendingTarget: ""

    /**
     * Quick-capture state read by both pills, where `quickMon` picks the one pill that renders the chooser and countdown toast.
     */
    property bool quickChoosing: false
    property bool quickScreenChoosing: false
    property string quickMon: ""

    signal targetReady(string token)
    signal targetAborted()

    /**
     * Fired from this singleton's own `targetReady` so the surface and the quick-record keybind count down the same way.
     */
    function beginCountdown(token) {
        pendingTarget = token;
        var n = Flags.recordCountdown;
        if (n > 0) {
            countdown = n;
            cdTimer.restart();
        } else {
            countdown = 0;
            cdTimer.stop();
            start(token);
            pendingTarget = "";
        }
    }

    function cancel() {
        cdTimer.stop();
        countdown = 0;
        pendingTarget = "";
    }

    Timer {
        id: cdTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                cdTimer.stop();
                root.start(root.pendingTarget);
                root.pendingTarget = "";
            }
        }
    }

    Connections {
        target: root
        function onTargetReady(token) {
            root.beginCountdown(token);
        }
        function onTargetAborted() {
            root.cancel();
        }
    }

    /**
     * Start of the running recording in ms, so every view shows the same elapsed time.
     */
    property double startedAt: 0

    onRecordingChanged: {
        startedAt = recording ? Date.now() : 0;
        if (recording) {
            cancel();
            quickChoosing = false;
            quickScreenChoosing = false;
        }
    }

    /**
     * Connected monitors as `{ name, w, h, label }`, where `name` is the connector that gsr's `-w` takes directly.
     */
    readonly property var monitors: {
        var out = [];
        var sc = Quickshell.screens;
        for (var i = 0; i < sc.length; i++) {
            var s = sc[i];
            out.push({ name: s.name, w: s.width, h: s.height, label: s.name + " · " + s.width + "×" + s.height });
        }
        return out;
    }

    readonly property var screenTargets: {
        var t = monitors.map(function(s) {
            return { name: s.name, title: s.name, detail: s.w + " × " + s.h };
        });
        if (monitors.length > 1)
            t.push({ name: "all", title: "All screens", detail: monitors.length + " files" });
        return t;
    }

    /**
     * UI labels sit one step above gsr's presets, so Ultra maps to `very_high` and Lossless to `ultra` because gsr has no lossless preset.
     */
    readonly property var qualityPreset: ({
        medium: "medium",
        high: "high",
        ultra: "very_high",
        lossless: "ultra"
    })

    function timestamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
    }

    function audioArg() {
        var sources = [];
        if (desktopOn)
            sources.push("default_output");
        if (micOn)
            sources.push("default_input");
        return sources.join("|");
    }

    /**
     * busy also covers an open picker so a second pick never stacks on the backend.
     */
    readonly property bool picking: windowProc.running
    readonly property bool busy: recording || recProc.running || picking

    function prepareScreen(name) {
        if (busy)
            return;
        targetReady(name && name.length > 0 ? name : "screen");
    }

    /**
     * Starts the combined Window / Region pick, which resolves to a `WxH+X+Y` geometry.
     */
    function prepareWindow() {
        if (busy)
            return;
        windowProc.running = true;
    }

    /**
     * Codec override from the `--info` probe, where `h264_vulkan` covers nvenc failures like nvidia 580xx on FFmpeg 9 and empty keeps gsr's own pick.
     */
    property var codecArgs: []

    /**
     * The probe runs once, the first time the recorder surface or the quick chooser opens.
     */
    property bool probed: false
    function probe() {
        if (probed)
            return;
        probed = true;
        infoProc.running = true;
    }

    onRecorderOpenChanged: if (recorderOpen) {
        probe();
        refreshRecent();
    }
    onQuickChoosingChanged: if (quickChoosing) probe()

    Process {
        id: infoProc
        command: ["gpu-screen-recorder", "--info"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/section=video_codecs\n([\s\S]*?)(\nsection=|$)/);
                var codecs = m ? m[1].split("\n") : [];
                var native = ["h264", "hevc", "av1"].some(function(c) { return codecs.indexOf(c) >= 0; });
                root.codecArgs = !native && codecs.indexOf("h264_vulkan") >= 0 ? ["-k", "h264_vulkan"] : [];
            }
        }
    }

    function buildArgs(captureToken, file) {
        var args = ["gpu-screen-recorder", "-w", captureToken,
                    "-f", String(fps), "-q", qualityPreset[quality] || "high",
                    "-cursor", captureCursor ? "yes" : "no",
                    "-fallback-cpu-encoding", "yes"].concat(codecArgs);
        var a = audioArg();
        if (a.length > 0)
            args = args.concat(["-a", a]);
        args = args.concat(["-o", file]);
        return args;
    }

    /**
     * One gsr per monitor under one shell, so recProc and the SIGINT stop cover every file and any failed recorder still fails the run.
     */
    function buildAll(files) {
        var q = function(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; };
        var lines = monitors.map(function(m, i) {
            return buildArgs(m.name, files[i]).map(q).join(" ") + " & pids=\"$pids $!\"";
        });
        return ["sh", "-c", lines.join("\n") + "\nrc=0; for p in $pids; do wait \"$p\" || rc=$?; done; exit $rc"];
    }

    /**
     * Starts gsr on an already resolved token, which is a monitor name, `screen`, `all` or a `WxH+X+Y` geometry.
     */
    function start(captureToken) {
        if (recording || recProc.running)
            return;
        stopGuard.stop();
        forcedStop = false;
        mkdirProc.command = ["mkdir", "-p", outDir];
        mkdirProc.pendingToken = captureToken;
        mkdirProc.pendingBase = outDir + "/recording_" + timestamp();
        mkdirProc.running = true;
    }

    function stop() {
        if (!recording)
            return;
        stopProc.command = ["pkill", "-SIGINT", "-f", "(^|/)gpu-screen-recorder"];
        stopProc.running = true;
        stopGuard.restart();
    }

    property bool forcedStop: false

    /**
     * gsr sometimes hangs after SIGINT with its file already finalized, and ignores SIGTERM too, so a stop still running after 5 s is killed.
     */
    Timer {
        id: stopGuard
        interval: 5000
        onTriggered: {
            root.forcedStop = true;
            killProc.running = true;
        }
    }

    Process {
        id: killProc
        command: ["pkill", "-KILL", "-f", "(^|/)gpu-screen-recorder"]
    }

    /**
     * Thumbnails are generated before the list lands so filmstrip delegates never bind to a not-yet-written jpg.
     */
    function refreshRecent() {
        if (thumbProc.running)
            return;
        thumbProc.running = true;
    }

    /**
     * Hides clips through a persisted mtime watermark without deleting any files.
     */
    function clearRecent() {
        var newest = 0;
        for (var i = 0; i < recent.length; i++)
            newest = Math.max(newest, recent[i].mtime);
        Flags.recordClearedBefore = newest;
        recent = [];
    }

    function openFile(path) {
        openProc.command = ["xdg-open", path];
        openProc.running = true;
    }

    function openDir() {
        openProc.command = ["xdg-open", outDir];
        openProc.running = true;
    }

    /**
     * Runs kdialog, else zenity, and writes the chosen folder to Flags so the surface, Open action and recent list follow it.
     */
    function pickDir() {
        pickProc.command = ["sh", "-c",
            "d=\"$1\"; if command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$d\"; else zenity --file-selection --directory --filename=\"$d/\"; fi",
            "_", outDir];
        pickProc.running = true;
    }

    Process {
        id: openProc
    }

    Process {
        id: pickProc
        stdout: StdioCollector {
            onStreamFinished: {
                var dir = this.text.trim();
                if (dir.length > 0)
                    Flags.recordDir = dir;
            }
        }
    }

    /**
     * Window rectangles are captured once, so a window moved or resized after the pick is not followed.
     */
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[] | \"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"' | slurp -f \"%wx%h+%x+%y\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var geom = this.text.trim();
                if (geom.length > 0)
                    root.targetReady(geom);
                else
                    root.targetAborted();
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.targetAborted();
        }
    }

    Process {
        id: mkdirProc
        property string pendingToken: ""
        property string pendingBase: ""
        onExited: {
            var all = pendingToken === "all";
            var base = pendingBase;
            root.currentFiles = all ? root.monitors.map(function(m) { return base + "_" + m.name + ".mp4"; }) : [base + ".mp4"];
            recProc.command = all ? root.buildAll(root.currentFiles) : root.buildArgs(pendingToken, root.currentFiles[0]);
            recProc.running = true;
        }
    }

    /**
     * Its own lifecycle drives `recording` for instant UI, and a non-zero exit before recording means gsr failed to start, so stderr is shown instead of a save.
     */
    Process {
        id: recProc
        stderr: StdioCollector { id: recErr }
        onStarted: {
            root.recording = true;
        }
        onExited: function(exitCode) {
            stopGuard.stop();
            root.recording = false;
            var forced = root.forcedStop;
            root.forcedStop = false;
            if (exitCode !== 0 && !forced) {
                var msg = recErr.text.trim();
                failProc.command = ["notify-send", "-a", "Ricelin", "-u", "critical",
                    "Recording failed", msg.length > 0 ? msg : "gpu-screen-recorder exited " + exitCode];
                failProc.running = true;
            } else {
                savedProc.running = true;
                Qt.callLater(root.refreshRecent);
            }
        }
    }

    Process {
        id: failProc
    }

    Process {
        id: stopProc
    }

    Process {
        id: savedProc
        command: ["notify-send", "-a", "Ricelin", "Recording saved",
            root.currentFiles.map(function(f) { return f.substring(f.lastIndexOf("/") + 1); }).join("\n")]
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript, root.outDir]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c",
            "d=\"$1\"; [ -d \"$d\" ] || exit 0; find \"$d\" -maxdepth 1 -type f -name 'recording_*.mp4' -printf '%T@\\t%s\\t%p\\n' | sort -rn | head -n 40",
            "_", root.outDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var cols = lines[i].split("\t");
                    if (cols.length < 3)
                        continue;
                    var mtime = parseFloat(cols[0]);
                    if (mtime <= Flags.recordClearedBefore)
                        continue;
                    var path = cols[2];
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    out.push({
                        path: path,
                        name: name,
                        mtime: mtime,
                        sizeLabel: root.humanSize(parseFloat(cols[1])),
                        thumb: root.thumbDir + name.replace(/\.mp4$/, "") + ".jpg"
                    });
                }
                root.recent = out;
            }
        }
    }

    function humanSize(bytes) {
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GB";
        if (bytes >= 1048576)
            return Math.round(bytes / 1048576) + " MB";
        if (bytes >= 1024)
            return Math.round(bytes / 1024) + " KB";
        return bytes + " B";
    }

    /**
     * Polls the real gsr process so a recorder started or stopped from anywhere is reflected.
     */
    Process {
        id: pollProc
        command: ["pgrep", "-f", "(^|/)gpu-screen-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                var running = this.text.trim().length > 0;
                /**
                 * Our own recProc owns the flag; the poll only tracks a gsr started elsewhere.
                 */
                if (!recProc.running && running !== root.recording) {
                    root.recording = running;
                    if (!running)
                        Qt.callLater(root.refreshRecent);
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: root.recording || root.recorderOpen
        repeat: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
}
