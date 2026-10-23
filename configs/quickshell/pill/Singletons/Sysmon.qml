pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Vitals for the 系 SYSTEM surface, polled only while it is open: /proc and hwmon every 500 ms, GPU every 1 s, disk and uptime every 5 s.
 */
Singleton {
    id: root

    /** Counted, not a bool: two monitors' surfaces open and close in any order. */
    property int openCount: 0
    readonly property bool open: openCount > 0

    property int cpu: 0
    property int cpuTemp: -1

    property bool hasGpu: false
    property string gpuVendor: ""
    property string gpuDev: ""
    property string gpuPdev: ""
    property var gpuPrev: null
    property int gpu: 0
    property int gpuTemp: -1
    property bool hasVram: false
    property real vramUsedGb: 0
    property real vramTotalGb: 0

    property real memUsedGb: 0
    property real memTotalGb: 0
    property int memPct: 0
    property real swapUsedGb: 0

    property real netDown: 0
    property real netUp: 0

    property int diskPct: 0
    property string uptime: ""

    property string tempPath: ""

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property real prevNetTime: 0

    /** Intel load from cumulative fdinfo: i915 ns against wall time, xe cycles against the GT clock; the first sample seeds. */
    function fdinfoLoad(ns, cyc, tot) {
        var now = Date.now();
        var prev = root.gpuPrev;
        root.gpuPrev = { ns: ns, cyc: cyc, tot: tot, t: now };
        if (!prev || now <= prev.t)
            return 0;
        var pct = tot > prev.tot
            ? (cyc - prev.cyc) * 100 / (tot - prev.tot)
            : (ns - prev.ns) / ((now - prev.t) * 1e4);
        return Math.max(0, Math.min(100, Math.round(pct)));
    }

    function primeAll() {
        if (tempPath.length === 0 || gpuVendor.length === 0) {
            detectProc.running = true;
            return;
        }
        prevCpuTotal = 0;
        prevRx = 0;
        prevNetTime = 0;
        gpuPrev = null;
        readFast();
        if (hasGpu && gpuVendor !== "nvidia")
            gpuProc.running = true;
        slowProc.running = true;
    }

    function readFast() {
        statFile.reload();
        memFile.reload();
        netFile.reload();
        if (tempPath.length > 0)
            tempFile.reload();
    }

    onOpenChanged: if (open) primeAll()

    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return "Up " + d + "d " + h + "h";
        if (h > 0)
            return "Up " + h + "h " + (m < 10 ? "0" + m : m) + "m";
        return "Up " + m + "m";
    }

    Component.onCompleted: detectProc.running = true

    Process {
        id: detectProc
        command: ["sh", "-c",
            "tp=''; for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tdie ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = 'Package id 0' ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do for l in \"$h\"/temp*_label; do [ -r \"$l\" ] || continue; [ \"$(cat \"$l\")\" = Tctl ] && { tp=\"${l%_label}_input\"; break 2; }; done; done; "
            + "[ -z \"$tp\" ] && for h in /sys/class/hwmon/hwmon*; do [ -r \"$h/temp1_input\" ] && { tp=\"$h/temp1_input\"; break; }; done; "
            + "echo \"TEMP $tp\"; "
            + "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo 'GPU nvidia'; "
            + "else for d in /sys/class/drm/card*/device; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\")\" = 0x1002 ] && [ -r \"$d/gpu_busy_percent\" ] && { v=0; [ -r \"$d/mem_info_vram_total\" ] && v=1; echo \"GPU amd $d $v\"; exit; }; done; "
            + "for d in /sys/class/drm/card*/device; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\")\" = 0x8086 ] || continue; case \"$(readlink \"$d/driver\")\" in */i915|*/xe) echo \"GPU intel $d $(basename \"$(readlink -f \"$d\")\")\"; exit;; esac; done; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "TEMP" && p.length > 1)
                        root.tempPath = p.slice(1).join(" ");
                    else if (p[0] === "GPU" && p[1] === "nvidia") {
                        root.gpuVendor = "nvidia";
                        root.hasGpu = true;
                        root.hasVram = true;
                    } else if (p[0] === "GPU" && p[1] === "amd") {
                        root.gpuVendor = "amd";
                        root.gpuDev = p.slice(2, p.length - 1).join(" ");
                        root.hasGpu = true;
                        root.hasVram = p[p.length - 1] === "1";
                    } else if (p[0] === "GPU" && p[1] === "intel") {
                        root.gpuVendor = "intel";
                        root.gpuDev = p.slice(2, p.length - 1).join(" ");
                        root.gpuPdev = p[p.length - 1];
                        root.hasGpu = true;
                        root.hasVram = false;
                    }
                }
                if (root.gpuVendor.length === 0)
                    root.gpuVendor = "none";
                if (root.open)
                    root.primeAll();
            }
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            var t = text();
            var p = t.substring(0, t.indexOf("\n")).trim().split(/\s+/);
            var total = 0;
            for (var i = 1; i <= 8; i++)
                total += parseFloat(p[i]) || 0;
            var idle = (parseFloat(p[4]) || 0) + (parseFloat(p[5]) || 0);
            if (root.prevCpuTotal > 0) {
                var dt = total - root.prevCpuTotal;
                var di = idle - root.prevCpuIdle;
                root.cpu = dt > 0 ? Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt))) : 0;
            }
            root.prevCpuTotal = total;
            root.prevCpuIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            var kb = {};
            var lines = text().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].split(/:\s+/);
                kb[p[0]] = parseFloat(p[1]) || 0;
            }
            var mt = kb.MemTotal || 0;
            var ma = kb.MemAvailable || 0;
            root.memTotalGb = mt / 1048576;
            root.memUsedGb = (mt - ma) / 1048576;
            root.memPct = mt > 0 ? Math.round(100 * (mt - ma) / mt) : 0;
            root.swapUsedGb = ((kb.SwapTotal || 0) - (kb.SwapFree || 0)) / 1048576;
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            var rx = 0;
            var tx = 0;
            var lines = text().split("\n");
            for (var i = 2; i < lines.length; i++) {
                var p = lines[i].replace(/:/g, " ").trim().split(/\s+/);
                if (p.length > 9 && p[0] !== "lo") {
                    rx += parseFloat(p[1]) || 0;
                    tx += parseFloat(p[9]) || 0;
                }
            }
            var now = Date.now();
            var dt = (now - root.prevNetTime) / 1000;
            if (root.prevNetTime > 0 && dt > 0) {
                root.netDown = Math.max(0, (rx - root.prevRx) / dt / 1048576);
                root.netUp = Math.max(0, (tx - root.prevTx) / dt / 1048576);
            }
            root.prevRx = rx;
            root.prevTx = tx;
            root.prevNetTime = now;
        }
    }

    FileView {
        id: tempFile
        path: root.tempPath
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(parseFloat(text()) / 1000)
        onLoadFailed: root.cpuTemp = -1
    }

    /**
     * One long-lived nvidia-smi samples every second while open instead of a fresh spawn per tick.
     */
    Process {
        id: nvidiaProc
        running: root.open && root.gpuVendor === "nvidia"
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits", "-i", "0", "-lms", "1000"]
        stdout: SplitParser {
            onRead: (line) => {
                var c = line.split(",");
                if (c.length < 4)
                    return;
                root.gpu = Math.max(0, Math.min(100, Math.round(parseFloat(c[0]) || 0)));
                root.gpuTemp = Math.round(parseFloat(c[1]) || 0);
                root.vramUsedGb = (parseFloat(c[2]) || 0) / 1024;
                root.vramTotalGb = (parseFloat(c[3]) || 0) / 1024;
            }
        }
    }

    Process {
        id: gpuProc
        command: root.gpuVendor === "intel"
            ? ["sh", "-c",
                "d=\"$1\"; t=$( { cat \"$d\"/hwmon/hwmon*/temp2_input || cat \"$d\"/hwmon/hwmon*/temp1_input; } 2>/dev/null | head -1); echo \"TEMP ${t:--1000}\"; "
                + "for f in $(find /proc/[0-9]*/fd -lname '/dev/dri/*' 2>/dev/null); do cat \"${f%/fd/*}/fdinfo/${f##*/}\"; done 2>/dev/null | awk -v pdev=\"$2\" "
                + "'/^drm-pdev:/{p=$2} /^drm-client-id:/{dup=seen[$2]++} "
                + "p==pdev && !dup && /^drm-engine-render:/{ns+=$2} p==pdev && !dup && /^drm-cycles-rcs:/{cyc+=$2} p==pdev && /^drm-total-cycles-rcs:/{tot=$2} "
                + "END{print \"FD\", ns+0, cyc+0, tot+0}'",
                "_", root.gpuDev, root.gpuPdev]
            : ["sh", "-c",
                "d=\"$1\"; echo \"BUSY $(cat \"$d/gpu_busy_percent\" 2>/dev/null)\"; "
                + "t=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); echo \"TEMP ${t:-0}\"; "
                + "echo \"VU $(cat \"$d/mem_info_vram_used\" 2>/dev/null)\"; echo \"VT $(cat \"$d/mem_info_vram_total\" 2>/dev/null)\"",
                "_", root.gpuDev]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "BUSY")
                        root.gpu = Math.max(0, Math.min(100, Math.round(parseFloat(p[1]) || 0)));
                    else if (p[0] === "FD")
                        root.gpu = root.fdinfoLoad(parseFloat(p[1]) || 0, parseFloat(p[2]) || 0, parseFloat(p[3]) || 0);
                    else if (p[0] === "TEMP")
                        root.gpuTemp = Math.round((parseFloat(p[1]) || 0) / 1000);
                    else if (p[0] === "VU")
                        root.vramUsedGb = (parseFloat(p[1]) || 0) / 1073741824;
                    else if (p[0] === "VT")
                        root.vramTotalGb = (parseFloat(p[1]) || 0) / 1073741824;
                }
            }
        }
    }

    Process {
        id: slowProc
        command: ["sh", "-c",
            "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5);print \"DISK \"$5}'; awk '{print \"UP \"int($1)}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split(/\s+/);
                    if (p[0] === "DISK")
                        root.diskPct = parseInt(p[1], 10) || 0;
                    else if (p[0] === "UP")
                        root.uptime = root.fmtUptime(parseInt(p[1], 10) || 0);
                }
            }
        }
    }

    Timer {
        interval: 500
        running: root.open
        repeat: true
        onTriggered: root.readFast()
    }

    Timer {
        interval: 1000
        running: root.open && root.hasGpu && root.gpuVendor !== "nvidia"
        repeat: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: if (!slowProc.running) slowProc.running = true
    }
}
