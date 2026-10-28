pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"

/** A thin reader of ricelin-update.py's JSON: `check` is a dry run, `apply` updates and only overwrites the conflicts the user opted into. */
AppPage {
    id: page
    pageId: "updates"
    resettable: false

    readonly property string engine: Quickshell.env("HOME") + "/.config/hypr/scripts/ricelin-update.py"

    property string status: ""
    property string version: ""
    property int behindCount: 0
    property string fromDate: ""
    property string toDate: ""
    property var changelog: []
    property var conflicts: []
    property string errorText: ""
    property real checkedAt: 0

    property bool checking: false
    property bool applying: false
    property bool restartNeeded: false

    /** Target short sha, split off the engine's "<sha> <date>" version string. */
    readonly property string targetShort: version.split(" ")[0]

    /** Installed short sha from the engine's manifest; empty until a first apply. */
    property string installedShort: ""

    function readManifest() {
        try {
            page.installedShort = (JSON.parse(manifestFile.text()).syncedSha || "").slice(0, 7);
        } catch (e) {
            page.installedShort = "";
        }
    }

    /** Conflicting rel-paths the user chose to overwrite with upstream on the next apply. */
    property var takePaths: ({})

    /** Core packages this update needs that aren't installed yet: [{id, name, desc, group}]. */
    property var missingDeps: []

    /** Packages the last apply couldn't bring in, [{id, error}], held until the next check. */
    property var depFailures: []

    /** Per-dep install choice, keyed by id. Absent means default on, false means opted out. */
    property var installDeps: ({})

    function depChosen(id) {
        return page.installDeps[id] !== false;
    }

    readonly property int chosenDeps: {
        let n = 0;
        for (let i = 0; i < missingDeps.length; i++)
            if (installDeps[missingDeps[i].id] !== false)
                n++;
        return n;
    }

    /** Title-case the package id into a readable label, e.g. noto-fonts-cjk -> Noto Fonts Cjk. */
    function prettyDep(id) {
        return id.split("-").map(w => w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w).join(" ");
    }

    readonly property bool busy: checking || applying
    readonly property bool behind: status === "ok" && behindCount > 0
    readonly property bool upToDate: status === "ok" && behindCount === 0

    /** rel-path -> human label for the protected files the engine can three-way merge. */
    readonly property var friendlyName: ({
        "hypr/modules/binds.lua": "Keybinds",
        "hypr/modules/decoration.lua": "Look",
        "hypr/modules/monitors.lua": "Display",
        "hypr/modules/input.lua": "Input",
        "hypr/modules/env.lua": "Environment",
        "hypr/modules/autostart.lua": "Autostart",
        "hypr/modules/animations.lua": "Animations",
        "hypr/hypridle.conf": "Idle & lock"
    })

    function labelFor(rel) {
        return friendlyName[rel] !== undefined ? friendlyName[rel] : rel;
    }

    readonly property string statusKind: applying ? "applying"
        : checking ? "checking"
        : restartNeeded ? "applied"
        : status === "devmode" ? "devmode"
        : status === "offline" ? "offline"
        : status === "noclone" ? "noclone"
        : status === "error" ? "error"
        : behind ? "behind"
        : upToDate ? "ok"
        : "idle"

    readonly property bool spinning: checking || applying

    readonly property string badgeIcon: statusKind === "behind" ? "arrow-up"
        : statusKind === "error" || statusKind === "offline" ? "close"
        : statusKind === "devmode" ? "bolt"
        : statusKind === "noclone" || statusKind === "idle" ? "download"
        : "check"

    readonly property color badgeTint: statusKind === "error" || statusKind === "offline" ? Theme.danger
        : statusKind === "checking" || statusKind === "applying" || statusKind === "idle" || statusKind === "noclone" ? Theme.subtle
        : Theme.vermLit

    readonly property string headline: statusKind === "applying" ? "Updating…"
        : statusKind === "checking" ? "Checking…"
        : statusKind === "applied" ? "Updated"
        : statusKind === "devmode" ? "Developer install"
        : statusKind === "offline" ? "Couldn't reach the server"
        : statusKind === "noclone" ? "Ready to set up"
        : statusKind === "error" ? "Check failed"
        : statusKind === "behind" ? (behindCount + " update" + (behindCount === 1 ? "" : "s") + " available")
        : statusKind === "ok" ? "Up to date"
        : "Updates"

    /** A line beneath the headline that orients each state, dropped when empty. */
    readonly property string subline: statusKind === "devmode" ? "This is a clone or symlinked work-tree, so updates run through plain git. In-app updating is off here."
        : statusKind === "noclone" ? "The rice copy didn't land yet. Check for updates to fetch it, then updates show up here."
        : statusKind === "error" ? errorText
        : statusKind === "applied" && depFailures.length === 0 ? "Restarting the shell"
        : ""

    readonly property string versionText: version.length === 0 ? installedShort
        : behind && installedShort.length > 0 && installedShort !== targetShort ? installedShort + " → " + targetShort
        : version.replace(" ", " · ")

    readonly property string metaLine: {
        if (statusKind === "devmode")
            return "";
        const parts = ["Main channel"];
        if (versionText.length > 0)
            parts.push(versionText);
        if (checkedAt > 0)
            parts.push("checked " + Qt.formatTime(new Date(checkedAt), Flags.time12h ? "h:mm AP" : "HH:mm"));
        return parts.join(" · ");
    }

    readonly property string updateSub: {
        const parts = [];
        if (fromDate.length > 0)
            parts.push(fromDate + " → " + toDate);
        parts.push(changelog.length + " change" + (changelog.length === 1 ? "" : "s"));
        if (chosenDeps > 0)
            parts.push("asks for your password to install " + chosenDeps + " package" + (chosenDeps === 1 ? "" : "s"));
        parts.push("the shell restarts after");
        return parts.join(" · ");
    }

    function resetResult() {
        status = "";
        behindCount = 0;
        fromDate = "";
        toDate = "";
        changelog = [];
        conflicts = [];
        missingDeps = [];
        installDeps = ({});
        depFailures = [];
        errorText = "";
        takePaths = ({});
    }

    function clearPending() {
        behindCount = 0;
        changelog = [];
        conflicts = [];
        missingDeps = [];
        installDeps = ({});
        takePaths = ({});
    }

    /** Toast body for after the restart, built before clearPending wipes the changelog. */
    function updatedBody() {
        const v = page.version.replace(" ", " · ");
        if (page.changelog.length > 0) {
            const more = page.changelog.length > 1 ? "  (+" + (page.changelog.length - 1) + " more)" : "";
            return "Now on " + v + "\n" + page.changelog[0] + more;
        }
        return "Now on " + v;
    }

    function ingest(data) {
        page.status = data.status || "error";
        page.behindCount = data.behind || 0;
        page.fromDate = data.fromDate || "";
        page.toDate = data.toDate || "";
        page.changelog = data.changelog || [];
        page.conflicts = data.conflicts || [];
        page.missingDeps = data.missingDeps || [];
        page.depFailures = data.depFailures || [];
        page.errorText = data.error || "";
        if (data.version && data.version.length > 0)
            page.version = data.version;
        if (data.applied)
            page.restartNeeded = data.restartNeeded === true;
    }

    function startCheck() {
        if (page.busy)
            return;
        page.checking = true;
        page.restartNeeded = false;
        resetResult();
        checkProc.running = true;
    }

    function startApply() {
        if (page.busy)
            return;
        page.applying = true;
        const take = [];
        for (const rel in page.takePaths)
            if (page.takePaths[rel])
                take.push(rel);
        applyProc.takeArg = take.length > 0 ? take.join(",") : "";
        const deps = [];
        for (let i = 0; i < page.missingDeps.length; i++) {
            const id = page.missingDeps[i].id;
            if (page.depChosen(id))
                deps.push(id);
        }
        applyProc.installArg = deps.length > 0 ? deps.join(",") : "";
        applyProc.running = true;
    }

    Component.onCompleted: startCheck()

    FileView {
        id: manifestFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/update.json"
        watchChanges: true
        printErrors: false
        onLoaded: page.readManifest()
        onFileChanged: reload()
    }

    Process {
        id: checkProc
        command: ["python3", page.engine, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.checking = false;
                page.checkedAt = Date.now();
                try {
                    page.ingest(JSON.parse(this.text));
                } catch (e) {
                    page.status = "error";
                    page.errorText = "The updater returned something unexpected.";
                }
            }
        }
    }

    Process {
        id: applyProc
        property string takeArg: ""
        property string installArg: ""
        command: {
            let c = ["python3", page.engine, "apply"];
            if (takeArg.length > 0)
                c = c.concat(["--take", takeArg]);
            if (installArg.length > 0)
                c = c.concat(["--install-deps", installArg]);
            return c;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                page.applying = false;
                try {
                    page.ingest(JSON.parse(this.text));
                } catch (e) {
                    page.resetResult();
                    page.status = "error";
                    page.errorText = "The updater returned something unexpected.";
                }
                /** No auto-restart while an install failed: the restart would hide what did not install. */
                if (page.restartNeeded && page.depFailures.length === 0) {
                    markerProc.body = page.updatedBody();
                    markerProc.running = true;
                    page.clearPending();
                    restartTimer.start();
                }
            }
        }
    }

    /** The shell reloads itself after a short delay so the "Updated" line registers first. */
    Timer {
        id: restartTimer
        interval: 1200
        onTriggered: restartProc.running = true
    }

    /** setsid lets the relaunch outlive the instance it kills; it only spawns one when no watchdog will. */
    Process {
        id: restartProc
        command: ["setsid", "sh", "-c",
            "qs -c pill kill; sleep 0.4; pgrep -f 'watchdog[.]sh pill' >/dev/null || qs -c pill -d"]
    }

    /** One-shot marker the restarted shell toasts; the body rides as a positional arg so the shell never re-parses it. */
    Process {
        id: markerProc
        property string body: ""
        command: ["sh", "-c",
            "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/ricelin\"; mkdir -p \"$d\"; printf '%s' \"$1\" > \"$d/updated\"",
            "sh", body]
    }

    AppGroup {
        title: "Installed version"

        AppRow {
            block: true
            key: "updates.check"

            Item {
                width: parent.width
                height: Math.max(badge.height, headCol.implicitHeight, checkBtn.height)

                Rectangle {
                    id: badge
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42 * page.s
                    height: width
                    radius: 11 * page.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.hair

                    GlyphIcon {
                        anchors.centerIn: parent
                        visible: !page.spinning
                        width: 19 * page.s
                        height: width
                        name: page.badgeIcon
                        color: page.badgeTint
                        stroke: 2
                    }

                    GlyphIcon {
                        anchors.centerIn: parent
                        visible: page.spinning
                        width: 18 * page.s
                        height: width
                        name: "reboot"
                        color: page.badgeTint
                        stroke: 2

                        RotationAnimation on rotation {
                            running: page.spinning && !Motion.calm
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }
                }

                Column {
                    id: headCol
                    anchors.left: badge.right
                    anchors.leftMargin: 14 * page.s
                    anchors.right: checkBtn.visible ? checkBtn.left : parent.right
                    anchors.rightMargin: 14 * page.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * page.s

                    Text {
                        width: parent.width
                        text: page.headline
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 16 * page.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        visible: page.subline.length > 0
                        text: page.subline
                        color: Theme.subtle
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        font.family: Theme.font
                        font.pixelSize: 12 * page.s
                    }
                    Text {
                        width: parent.width
                        visible: page.metaLine.length > 0
                        text: page.metaLine
                        color: Theme.textFaint
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 11.5 * page.s
                        font.features: { "tnum": 1 }
                    }
                }

                AppButton {
                    id: checkBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.statusKind !== "devmode"
                    enabled: !page.busy
                    text: page.checking ? "Checking…" : page.statusKind === "offline" ? "Retry" : "Check for updates"
                    onClicked: page.startCheck()
                }
            }
        }
    }

    AppGroup {
        visible: page.behind
        title: "Update"

        AppRow {
            label: "Install " + page.behindCount + " update" + (page.behindCount === 1 ? "" : "s")
            sub: page.updateSub
            key: "updates.update"
            AppButton {
                kind: "primary"
                enabled: !page.applying
                text: page.applying ? "Updating…" : "Update now"
                onClicked: page.startApply()
            }
        }
    }

    AppGroup {
        visible: page.behind
        title: "What's new"

        AppRow {
            block: true
            key: "updates.whatsnew"

            Column {
                width: parent.width
                spacing: 8 * page.s

                Text {
                    visible: page.changelog.length === 0
                    text: "No highlights noted"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12.5 * page.s
                    font.italic: true
                }

                Repeater {
                    model: page.changelog

                    Item {
                        id: logLine
                        required property var modelData
                        width: parent.width
                        height: logText.implicitHeight

                        Rectangle {
                            y: logText.font.pixelSize * 0.62 - height / 2 + 1 * page.s
                            width: 5 * page.s
                            height: width
                            radius: width / 2
                            color: Theme.vermLit
                        }
                        Text {
                            id: logText
                            x: 16 * page.s
                            width: parent.width - x
                            text: String(logLine.modelData)
                            color: Theme.cream
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                            font.family: Theme.font
                            font.pixelSize: 13 * page.s
                        }
                    }
                }
            }
        }
    }

    AppGroup {
        visible: page.behind && page.conflicts.length > 0
        title: "Your edits clash with " + page.conflicts.length + " file" + (page.conflicts.length === 1 ? "" : "s")
        hint: "Keep mine leaves your file exactly as it is"

        Repeater {
            model: page.behind ? page.conflicts : []

            AppRow {
                id: confRow
                required property var modelData
                readonly property string rel: String(modelData)
                label: page.labelFor(rel)
                sub: rel
                AppSeg {
                    options: [{ label: "Keep mine", value: false }, { label: "Take new", value: true }]
                    value: page.takePaths[confRow.rel] === true
                    onPicked: (v) => page.takePaths = Object.assign({}, page.takePaths, { [confRow.rel]: v })
                }
            }
        }
    }

    AppGroup {
        visible: page.behind && page.missingDeps.length > 0
        title: "Needs " + page.missingDeps.length + " package" + (page.missingDeps.length === 1 ? "" : "s")
        hint: "Installing them asks for your password once"

        Repeater {
            model: page.behind ? page.missingDeps : []

            AppRow {
                id: depRow
                required property var modelData
                readonly property string depId: String(modelData.id)
                label: page.prettyDep(depId)
                sub: modelData.desc || ""
                clickable: true
                onClicked: page.installDeps = Object.assign({}, page.installDeps, { [depRow.depId]: !page.depChosen(depRow.depId) })
                AppToggle {
                    checked: page.depChosen(depRow.depId)
                    onToggled: (on) => page.installDeps = Object.assign({}, page.installDeps, { [depRow.depId]: on })
                }
            }
        }
    }

    AppGroup {
        visible: page.depFailures.length > 0
        title: "Couldn't install " + page.depFailures.length + " package" + (page.depFailures.length === 1 ? "" : "s")

        Repeater {
            model: page.depFailures

            AppRow {
                required property var modelData
                label: page.prettyDep(String(modelData.id))
                sub: modelData.error || ""

                GlyphIcon {
                    width: 16 * page.s
                    height: width
                    name: "close"
                    color: Theme.danger
                    stroke: 2.2
                }
            }
        }
    }
}
