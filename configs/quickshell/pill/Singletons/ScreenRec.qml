pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Screen-recorder backend, shared by the 録 RECORD surface, the pill's hover
 * cluster record indicator and the record OSD. gpu-screen-recorder is the
 * encoder (cross-vendor nvenc/vaapi/vulkan/cpu); this singleton owns the capture
 * settings, builds the argv from them, starts and stops the recorder and keeps
 * a live `recording` flag polled from the real process so an externally started
 * or stopped recorder is reflected too.
 *
 * The capture target is chosen at leisure BEFORE any countdown, so the user
 * picks WHAT to record with no recording running yet. The surface calls one of
 * two resolvers, each emitting `targetReady(token)` on a valid pick or
 * `targetAborted()` on cancel: `prepareScreen(name)` resolves synchronously to a
 * monitor connector name (`-w DP-1`, falling back to `-w screen`);
 * `prepareWindow()` feeds the Hyprland client rectangles to `slurp` for one
 * combined Window / Region pick — clicking a window snaps to it, dragging draws
 * a freeform region — and resolves to that `WxH+X+Y` geometry. Only after
 * `targetReady` does the surface run its countdown and call `start(token)`, so
 * the order is pick → countdown → record. Audio uses gsr's device aliases (`default_output` for desktop,
 * `default_input` for the mic) so no device id is ever hardcoded; the surface's
 * faders set the captured level by driving the default sink/source through
 * Pipewire. Stop sends SIGINT, which makes gsr finalise and save the file, then
 * notify-send announces the saved file; a recorder that exits non-zero before it
 * ever started reports its stderr and resets. The on-pill record OSD shows the
 * started/stopped state, so the start is not also pushed as a notification.
 *
 * The output directory is the Flags-persisted `recordDir`, falling back to
 * `$HOME/Videos/Recordings`; `pickDir()` runs a native folder picker (kdialog
 * or zenity) and writes the chosen path back to Flags so the displayed path,
 * Open action and recent list all follow it. A `recording` poll reconciles an
 * externally started or stopped recorder so the state is never stale.
 *
 * The recent list carries a cover thumbnail per clip: `refreshRecent()` first
 * runs the thumb script (ffmpeg extracts a single frame into a cache dir under
 * `$XDG_CACHE_HOME/ricelin/rec-thumbs`, skipping clips already cached) and only
 * then re-reads the list, so each entry's `thumb` path is on disk by the time
 * the filmstrip binds to it. Entries are `{ path, name, mtime, sizeLabel,
 * thumb }`.
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

    onOutDirChanged: refreshRecent()

    property int fps: Flags.recordFps
    onFpsChanged: Flags.recordFps = fps
    property string quality: Flags.recordQuality
    onQualityChanged: Flags.recordQuality = quality
    property bool captureCursor: Flags.recordCursor
    onCaptureCursorChanged: Flags.recordCursor = captureCursor
    property bool micOn: Flags.recordMic
    onMicOnChanged: Flags.recordMic = micOn
    property bool desktopOn: Flags.recordDesktop
    onDesktopOnChanged: Flags.recordDesktop = desktopOn

    property bool recording: false
    property bool recorderOpen: false
    property string currentFile: ""
    property var recent: []
    readonly property int recentCount: recent.length

    /**
     * Pre-roll countdown, owned here rather than in the surface so the quick-record
     * keybind flow gets it for free with no surface open. `beginCountdown(token)`
     * runs after any target resolves; at zero the recorder starts. `pendingTarget`
     * holds the resolved capture token across the tick-down. `counting` gates the
     * countdown UI in both the surface action bar and the standalone top toast.
     */
    property int countdown: 0
    readonly property bool counting: countdown > 0
    property string pendingTarget: ""

    /**
     * Standalone quick-capture state, read by both pills. `quickMon` is the focused
     * monitor's connector name the keybind targeted, so only that pill renders the
     * chooser and the countdown toast. `quickChoosing` shows the source chooser;
     * `quickScreenChoosing` the monitor sub-choice. The recorder surface stays out
     * of this entirely.
     */
    property bool quickChoosing: false
    property bool quickScreenChoosing: false
    property string quickMon: ""

    signal targetReady(string token)
    signal targetAborted()

    /**
     * Run the pre-roll for a freshly resolved capture token. Zero countdown starts
     * gsr at once; otherwise the token is parked and the timer ticks it down to the
     * start. Fired from this singleton's own `targetReady`, so every caller — the
     * recorder surface or the quick-record keybind — counts down the same way.
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

    /**
     * Abort an in-flight pre-roll: stop the timer, clear the countdown and the
     * parked token. Used by a cancelled pick and the surface's tap-to-cancel.
     */
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

    onRecordingChanged: if (recording) {
        cancel();
        quickChoosing = false;
        quickScreenChoosing = false;
    }

    /**
     * Connected monitors as `{ name, w, h, label }` for the Screen sub-chooser.
     * gsr's `-w <name>` records a monitor by its connector name, so the chooser
     * passes the chosen `name` straight into `prepareScreen()`. A single screen
     * needs no chooser; the surface uses the lone entry directly.
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

    /**
     * gsr quality preset for the surface's quality value. The UI labels Ultra and
     * Lossless above gsr's named presets, so Ultra maps to gsr `very_high` and
     * Lossless to gsr `ultra` (its highest QP quality); gsr has no literal
     * lossless preset.
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
     * True while a recording is live or a region/window picker is still up, so
     * the surface and the resolvers never stack a second pick on a busy backend.
     */
    readonly property bool picking: windowProc.running
    readonly property bool busy: recording || recProc.running || picking

    /**
     * Resolve a whole-screen target synchronously to a monitor connector name
     * (or `screen` when none was passed) and announce it. No picker runs; the
     * surface chose the screen at leisure already, so the countdown follows.
     */
    function prepareScreen(name) {
        if (busy)
            return;
        targetReady(name && name.length > 0 ? name : "screen");
    }

    /**
     * Feed the Hyprland client rectangles to `slurp` so the user picks at
     * leisure with nothing recording yet: clicking a window snaps to that
     * window, dragging draws a freeform region (one combined Window / Region
     * pick, like a screenshot tool). Announces the chosen `WxH+X+Y` geometry, or
     * aborts on cancel / non-zero exit (the user pressed Escape).
     */
    function prepareWindow() {
        if (busy)
            return;
        windowProc.running = true;
    }

    /**
     * Codec override from the `--info` probe: empty keeps gsr's native nvenc/vaapi pick,
     * `h264_vulkan` covers drivers the system FFmpeg's nvenc refuses (nvidia 580xx on FFmpeg 9).
     */
    property var codecArgs: []

    Process {
        id: infoProc
        command: ["gpu-screen-recorder", "--info"]
        running: true
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
     * Begin recording the already-resolved capture token (a monitor name,
     * `screen` or a WxH+X+Y geometry). Builds the output path, ensures the
     * directory exists, then launches gsr.
     */
    function start(captureToken) {
        if (recording || recProc.running)
            return;
        var file = outDir + "/recording_" + timestamp() + ".mp4";
        mkdirProc.command = ["mkdir", "-p", outDir];
        mkdirProc.pendingToken = captureToken;
        mkdirProc.pendingFile = file;
        mkdirProc.running = true;
    }

    function stop() {
        if (!recording)
            return;
        stopProc.command = ["pkill", "-SIGINT", "-f", "(^|/)gpu-screen-recorder"];
        stopProc.running = true;
    }

    /**
     * Re-read the recent list, regenerating any missing cover thumbnails first.
     * The thumb script extracts a frame per clip with ffmpeg into the cache dir
     * (skipping clips whose thumb already exists and is newer) and only then does
     * the list land, so filmstrip delegates never bind to a not-yet-written jpg;
     * a thumb run already in flight is left to finish rather than stacked.
     */
    function refreshRecent() {
        if (thumbProc.running)
            return;
        thumbProc.running = true;
    }

    /**
     * Hide every current clip from the recent list without touching the files:
     * the newest clip's mtime is parked as a persisted watermark and the list is
     * emptied, so refreshes filter out anything at or before it while later
     * recordings still surface. The clips stay on disk in the save folder.
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
     * Run a native folder picker (kdialog, else zenity) seeded at the current
     * directory and write the chosen path to Flags so the surface, Open action
     * and recent list all follow it. A cancelled pick prints nothing and leaves
     * the directory unchanged.
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
     * Combined Window / Region picker: feeds each Hyprland client's current
     * rectangle to `slurp`, so clicking a window snaps to its `WxH+X+Y` geometry
     * while dragging draws a freeform region. The rectangle is captured
     * statically, so a window moved or resized after the pick is not followed.
     * Empty pick or non-zero exit (Escape) aborts.
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
        property string pendingFile: ""
        onExited: {
            root.currentFile = pendingFile;
            recProc.command = root.buildArgs(pendingToken, pendingFile);
            recProc.running = true;
        }
    }

    /**
     * The live recorder. Its own lifecycle drives `recording` so start/stop UI is
     * immediate instead of waiting up to a poll cycle: onStarted marks running,
     * onExited marks stopped. The poll stays an external reconciler. A clean stop
     * (SIGINT) finalises and exits zero and the saved file is announced; a
     * non-zero exit before it ever reached the recording state means gsr failed to
     * start, so its stderr is surfaced and no save is announced.
     */
    Process {
        id: recProc
        stderr: StdioCollector { id: recErr }
        onStarted: {
            root.recording = true;
        }
        onExited: function(exitCode) {
            root.recording = false;
            if (exitCode !== 0) {
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
            root.currentFile.substring(root.currentFile.lastIndexOf("/") + 1)]
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
     * Poll the real recorder process so the flag tracks gsr started or stopped
     * from anywhere, not just this surface. On a save the recent list re-reads so
     * the new file appears.
     */
    Process {
        id: pollProc
        command: ["pgrep", "-f", "(^|/)gpu-screen-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                var running = this.text.trim().length > 0;
                if (running !== root.recording) {
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

    Component.onCompleted: refreshRecent()
}
