pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Execution layer: turns an AppRegistry record into a real process and keeps
 * track of it while it runs. One Process object is created per launch via
 * `procComponent.createObject()` — Process is a plain QtObject (see
 * Quickshell.Io docs), so this is the documented way to have more than one
 * in flight at once, rather than pre-declaring a fixed pool of slots.
 *
 * Environment variables are passed through Process.environment rather than
 * built into a `sh -c "VAR=val cmd"` string: several of these paths contain
 * spaces (the Cyberpunk working directory is literally ".../Cyberpunk 2077"),
 * and the structured command/environment/workingDirectory properties avoid
 * shell-quoting them entirely.
 *
 * `wine` and `umu-run` both block for the life of the game, so Process.running
 * going false *is* "the game closed" — no separate pgrep polling loop needed.
 * Stop sends SIGTERM (graceful); Force Stop pkills the executable's own path
 * so a wedged Windows process tree can't block the tile forever.
 */
Singleton {
    id: root

    /** True while auto-toggling Flags.gameMode for category:"game" launches. Flip off if you'd rather drive Game Mode by hand. */
    property bool autoGameMode: true

    /** appId -> { startedAt, pid }. Reassigned wholesale (never mutated in place) so isRunning()/pid() bindings refresh. */
    property var runningIds: ({})

    /** appId -> live Process, kept outside runningIds since UI never binds to the process object itself. */
    property var _procs: ({})
    property int _runningGameCount: 0

    function isRunning(appId) {
        return appId in root.runningIds;
    }

    function pidFor(appId) {
        var r = root.runningIds[appId];
        return r ? r.pid : 0;
    }

    function startedAt(appId) {
        var r = root.runningIds[appId];
        return r ? r.startedAt : 0;
    }

    function dllOverrideString(overrides) {
        if (!overrides)
            return "";
        var parts = [];
        for (var dll in overrides) {
            var mode = overrides[dll];
            var code = mode === "native" ? "n" : mode === "builtin" ? "b" : mode === "native,builtin" ? "n,b" : mode === "disabled" ? "" : "";
            parts.push(dll + "=" + code);
        }
        return parts.join(";");
    }

    function dirName(p) {
        var i = String(p).lastIndexOf("/");
        return i > 0 ? p.slice(0, i) : p;
    }

    /** Builds { command, environment, workingDirectory } for the app's current runner. Extracted from launch() so AddApplicationSheet can preview it before saving. */
    function buildInvocation(app) {
        var normalized = AppRegistry.normalizeRecord(app);
        var env = Object.assign({}, normalized.env || {});
        var overrideStr = root.dllOverrideString(normalized.dllOverrides);
        if (overrideStr.length > 0) env.WINEDLLOVERRIDES = overrideStr;
        if (normalized.performance && normalized.performance.fpsLimit > 0) env.DXVK_FRAME_RATE = String(normalized.performance.fpsLimit);
        if (normalized.performance && normalized.performance.mangohud) env.MANGOHUD = "1";

        var command;
        var workingDirectory = normalized.workingDirectory && normalized.workingDirectory.length > 0 ? normalized.workingDirectory : root.dirName(normalized.executable);
        var rt = normalized.runtime || {};
        if (normalized.runner === "umu") {
            env.GAMEID = normalized.umuId && normalized.umuId.length > 0 ? normalized.umuId : ("umu-" + normalized.id);
            if (normalized.prefix) env.WINEPREFIX = normalized.prefix;
            env.PROTONPATH = normalized.protonBuild || rt.build || "GE-Proton";
            command = ["umu-run", normalized.executable].concat(normalized.args || []);
        } else if (normalized.runner === "steam") {
            command = ["steam", "-applaunch", normalized.steamAppId || normalized.id].concat(normalized.args || []);
        } else if (normalized.runner === "wine" || normalized.runner === "wine-staging") {
            if (normalized.prefix) env.WINEPREFIX = normalized.prefix;
            var wineBin = normalized.runner === "wine-staging" && !root.wineIsStaging ? "wine-staging" : "wine";
            command = [wineBin, normalized.executable].concat(normalized.args || []);
        } else {
            command = [normalized.executable].concat(normalized.args || []);
        }
        if (normalized.performance && normalized.performance.mangohud) command = ["mangohud"].concat(command);
        if (normalized.performance && normalized.performance.gamescope) command = ["gamescope", "--"].concat(command);
        return { command: command, environment: env, workingDirectory: workingDirectory };
    }

    /** True once RuntimeManager has confirmed the plain `wine` binary already answers to Wine-Staging, so buildInvocation doesn't reach for a separate wine-staging binary that would just be missing. */
    readonly property bool wineIsStaging: RuntimeManager.wineVersion.toLowerCase().indexOf("staging") >= 0

    Component {
        id: procComponent
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    function launch(appId, useGameMode) {
        if (useGameMode === undefined)
            useGameMode = true;

        var app = AppRegistry.byId(appId);
        if (!app || root.isRunning(appId))
            return;

        var inv = root.buildInvocation(app);
        var proc = procComponent.createObject(root, {
            command: inv.command,
            environment: inv.environment,
            workingDirectory: inv.workingDirectory,
            running: true
        });
        if (!proc)
            return;

        root._procs[appId] = proc;
        root.runningIds = Object.assign({}, root.runningIds, {
            [appId]: { startedAt: Date.now(), pid: 0 }
        });

        AppRegistry.recordLaunch(appId);

        if (app.category === "game" && root.autoGameMode && useGameMode) {
            root._runningGameCount++;
            if (root._runningGameCount === 1)
                Flags.gameMode = true;
        }

        pidTimer.createObject(root, { appId: appId, proc: proc });

        proc.exited.connect(function (exitCode, exitStatus) {
            delete root._procs[appId];
            var next = Object.assign({}, root.runningIds);
            delete next[appId];
            root.runningIds = next;
            if (app.category === "game" && root.autoGameMode && useGameMode) {
                root._runningGameCount = Math.max(0, root._runningGameCount - 1);
                if (root._runningGameCount === 0)
                    Flags.gameMode = false;
            }
            proc.destroy();
        });
    }

    /** A one-shot Timer component rather than a single shared Timer, since several launches can be settling their pid at once. */
    Component {
        id: pidTimer
        Timer {
            property string appId: ""
            property var proc: null
            interval: 400
            running: true
            onTriggered: {
                if (proc && root.isRunning(appId)) {
                    var next = Object.assign({}, root.runningIds);
                    if (next[appId])
                        next[appId] = { startedAt: next[appId].startedAt, pid: proc.processId || 0 };
                    root.runningIds = next;
                }
                destroy();
            }
        }
    }

    /** Graceful stop: SIGTERM to our tracked process (Process.running = false), giving Wine/UMU a chance to shut the game down cleanly. */
    function stop(appId) {
        var proc = root._procs[appId];
        if (proc)
            proc.running = false;
    }

    /** Best-effort tree kill for a wedged process: matches the game's own executable path rather than the wine/umu-run wrapper, so the wrapper notices its child died and exits on its own — which fires the normal exited() cleanup above. */
    function forceStop(appId) {
        var proc = root._procs[appId];
        var pid = proc ? (proc.processId || 0) : root.pidFor(appId);
        if (pid <= 0) return;
       Quickshell.execDetached(["sh", "-c", 'kill_tree() { for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done; kill -KILL "$1" 2>/dev/null; }; kill_tree "$1"', "_", String(pid)]);
    }

    // ---- Environment (prefix) actions -------------------------------------
    function createPrefix(app) { return EnvironmentManager.create(app); }
    function openPrefixFiles(app) { return EnvironmentManager.openFiles(app); }
    function runWinetricks(app) { return EnvironmentManager.winetricks(app); }
    function clonePrefix(app, destPath) { return EnvironmentManager.clone(app, destPath); }
    function resetPrefix(app) { return EnvironmentManager.reset(app); }
    function deletePrefix(app) { return EnvironmentManager.remove(app); }

    // ---- File pickers (zenity, falling back to kdialog) -------------------

    Component {
        id: pickerComponent
        Process {
            stdout: StdioCollector {}
        }
    }

    function pickFile(callback) {
        root._runPicker(RuntimeManager.hasZenity
            ? ["zenity", "--file-selection", "--title=Select executable"]
            : RuntimeManager.hasKdialog
                ? ["kdialog", "--getopenfilename"]
                : [], callback);
    }

    function pickFolder(callback) {
        root._runPicker(RuntimeManager.hasZenity
            ? ["zenity", "--file-selection", "--directory", "--title=Select folder"]
            : RuntimeManager.hasKdialog
                ? ["kdialog", "--getexistingdirectory"]
                : [], callback);
    }

    function _runPicker(command, callback) {
        if (command.length === 0) {
            callback("");
            return;
        }
        var proc = pickerComponent.createObject(root, { command: command, running: true });
        proc.exited.connect(function () {
            var out = proc.stdout.text ? String(proc.stdout.text).trim() : "";
            callback(out);
            proc.destroy();
        });
    }
}
