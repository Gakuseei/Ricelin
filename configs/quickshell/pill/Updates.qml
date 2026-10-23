pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 更 UPDATES: a thin reader of ricelin-update.py's JSON; `check` is a dry run, `apply` updates and only overwrites the conflicts the user opted into.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight
    rows: []

    readonly property string engine: Quickshell.env("HOME") + "/.config/hypr/scripts/ricelin-update.py"

    property string status: ""
    property string version: ""
    property int behindCount: 0
    property string fromDate: ""
    property string toDate: ""
    property var changelog: []
    property var conflicts: []
    property string errorText: ""

    property bool checking: false
    property bool applying: false
    property bool restartNeeded: false

    /**
     * Target short sha, split off the engine's "<sha> <date>" version string.
     */
    readonly property string targetShort: version.split(" ")[0]

    /**
     * Installed short sha from the engine's manifest; empty until a first apply.
     */
    property string installedShort: ""

    function readManifest() {
        try {
            root.installedShort = (JSON.parse(manifestFile.text()).syncedSha || "").slice(0, 7);
        } catch (e) {
            root.installedShort = "";
        }
    }

    /**
     * Conflicting rel-paths the user chose to overwrite with upstream on the next apply.
     */
    property var takePaths: ({})

    /**
     * Core packages this update needs that aren't installed yet: [{id, name, desc, group}].
     */
    property var missingDeps: []

    /**
     * Packages the last apply couldn't bring in, [{id, error}], held until the next check.
     */
    property var depFailures: []

    /**
     * Per-dep install choice, keyed by id. Absent means default ON, false means opted out.
     */
    property var installDeps: ({})

    function depChosen(id) {
        return root.installDeps[id] !== false;
    }

    /**
     * Title-case the package id into a readable label, e.g. noto-fonts-cjk -> Noto Fonts Cjk.
     */
    function prettyDep(id) {
        return id.split("-").map(function (w) {
            return w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w;
        }).join(" ");
    }

    readonly property bool busy: checking || applying
    readonly property bool behind: status === "ok" && behindCount > 0
    readonly property bool upToDate: status === "ok" && behindCount === 0

    /**
     * rel-path -> human label for the protected files the engine can three-way merge.
     */
    readonly property var friendlyName: ({
        "hypr/modules/binds.lua": "Keybinds",
        "hypr/modules/decoration.lua": "Look",
        "hypr/modules/monitors.lua": "Display",
        "hypr/modules/input.lua": "Input",
        "hypr/modules/env.lua": "Environment",
        "hypr/modules/autostart.lua": "Autostart",
        "hypr/modules/animations.lua": "Animations",
        "hypr/hypridle.conf": "Idle & Lock"
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
        : statusKind === "noclone" ? "download"
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

    /**
     * A line beneath the headline that orients each state, dropped when empty.
     */
    readonly property string subline: statusKind === "devmode" ? "This is a clone or symlinked work-tree, so updates run through plain git. In-app updating is off here."
        : statusKind === "noclone" ? "The rice copy didn't land yet. Check for updates to fetch it, then updates show up here."
        : statusKind === "error" ? errorText
        : statusKind === "behind" ? (fromDate.length > 0 ? fromDate + " → " + toDate : "")
        : ""

    onActiveChanged: {
        if (active) {
            startCheck();
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
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

    /**
     * Toast body for after the restart, built before clearPending wipes the changelog.
     */
    function updatedBody() {
        var v = root.version.replace(" ", " · ");
        if (root.changelog.length > 0) {
            var more = root.changelog.length > 1
                ? "  (+" + (root.changelog.length - 1) + " more)" : "";
            return "Now on " + v + "\n" + root.changelog[0] + more;
        }
        return "Now on " + v;
    }

    function ingest(data) {
        root.status = data.status || "error";
        root.behindCount = data.behind || 0;
        root.fromDate = data.fromDate || "";
        root.toDate = data.toDate || "";
        root.changelog = data.changelog || [];
        root.conflicts = data.conflicts || [];
        root.missingDeps = data.missingDeps || [];
        root.depFailures = data.depFailures || [];
        root.errorText = data.error || "";
        if (data.version && data.version.length > 0)
            root.version = data.version;
        if (data.applied)
            root.restartNeeded = data.restartNeeded === true;
    }

    function startCheck() {
        if (root.busy)
            return;
        root.checking = true;
        root.restartNeeded = false;
        resetResult();
        checkProc.running = true;
    }

    function startApply() {
        if (root.busy)
            return;
        root.applying = true;
        var take = [];
        for (var rel in root.takePaths)
            if (root.takePaths[rel])
                take.push(rel);
        applyProc.takeArg = take.length > 0 ? take.join(",") : "";
        var deps = [];
        for (var i = 0; i < root.missingDeps.length; i++) {
            var id = root.missingDeps[i].id;
            if (root.depChosen(id))
                deps.push(id);
        }
        applyProc.installArg = deps.length > 0 ? deps.join(",") : "";
        applyProc.running = true;
    }

    FileView {
        id: manifestFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/update.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.readManifest()
        onFileChanged: reload()
    }

    Process {
        id: checkProc
        command: ["python3", root.engine, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                try {
                    root.ingest(JSON.parse(this.text));
                } catch (e) {
                    root.status = "error";
                    root.errorText = "The updater returned something unexpected.";
                }
            }
        }
    }

    Process {
        id: applyProc
        property string takeArg: ""
        property string installArg: ""
        command: {
            var c = ["python3", root.engine, "apply"];
            if (takeArg.length > 0)
                c = c.concat(["--take", takeArg]);
            if (installArg.length > 0)
                c = c.concat(["--install-deps", installArg]);
            return c;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.applying = false;
                try {
                    root.ingest(JSON.parse(this.text));
                } catch (e) {
                    root.resetResult();
                    root.status = "error";
                    root.errorText = "The updater returned something unexpected.";
                }
                /**
                 * No auto-restart while an install failed: the restart would hide what did not install.
                 */
                if (root.restartNeeded && root.depFailures.length === 0) {
                    markerProc.body = root.updatedBody();
                    markerProc.running = true;
                    root.clearPending();
                    restartTimer.start();
                }
            }
        }
    }

    /**
     * The shell reloads itself after a short delay so the "Updated" line registers first.
     */
    Timer {
        id: restartTimer
        interval: 1200
        onTriggered: restartProc.running = true
    }

    /**
     * setsid lets the relaunch outlive the instance it kills; it only spawns one when no watchdog will.
     */
    Process {
        id: restartProc
        command: ["setsid", "sh", "-c",
            "qs -c pill kill; sleep 0.4; pgrep -f 'watchdog[.]sh pill' >/dev/null || qs -c pill -d"]
    }

    /**
     * One-shot marker the restarted shell toasts; the body rides as a positional arg so the shell never re-parses it.
     */
    Process {
        id: markerProc
        property string body: ""
        command: ["sh", "-c",
            "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/ricelin\"; mkdir -p \"$d\"; printf '%s' \"$1\" > \"$d/updated\"",
            "sh", body]
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            s: root.s
            glyph: "更"
            title: "UPDATES"
            canBack: true
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            spacing: Theme.sp.m * root.s

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34 * root.s
                height: 34 * root.s
                radius: width / 2
                color: Qt.alpha(root.badgeTint, 0.16)

                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !root.spinning
                    width: 17 * root.s
                    height: 17 * root.s
                    name: root.badgeIcon
                    color: root.badgeTint
                    stroke: 2.2
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    visible: root.spinning
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "reboot"
                    color: root.badgeTint
                    stroke: 2

                    RotationAnimation on rotation {
                        running: root.spinning && !Motion.calm
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34 * root.s - Theme.sp.m * root.s
                spacing: Theme.sp.xxs * root.s

                Text {
                    text: root.headline
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.title * root.s
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    visible: root.subline.length > 0
                    text: root.subline
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    font.features: { "tnum": 1 }
                }

                Text {
                    visible: root.version.length > 0
                    text: root.behind && root.installedShort.length > 0 && root.installedShort !== root.targetShort
                        ? root.installedShort + " → " + root.targetShort
                        : root.version.replace(" ", " · ")
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.features: { "tnum": 1 }
                }
            }
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        /**
         * The changelog leads when an update waits and hides otherwise, so calm states stay calm.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            spacing: Theme.sp.s * root.s
            visible: root.behind

            SettingsLabel {
                s: root.s
                topPadding: 0
                bottomPadding: 0
                text: "What's new"
            }

            Text {
                width: parent.width
                visible: root.changelog.length === 0
                text: "No highlights noted"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.italic: true
            }

            ListView {
                id: logList
                width: parent.width
                height: visible ? Math.min(contentHeight, 168 * root.s) : 0
                visible: root.changelog.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.changelog

                delegate: Row {
                    required property var modelData
                    width: ListView.view.width
                    spacing: Theme.sp.s * root.s
                    topPadding: Theme.sp.xxs * root.s
                    bottomPadding: Theme.sp.xxs * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: Theme.sp.s * root.s
                        width: 4 * root.s
                        height: 4 * root.s
                        radius: width / 2
                        color: Theme.vermLit
                    }

                    Text {
                        width: parent.width - 12 * root.s
                        text: parent.modelData
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                    }
                }

                WheelScroller {
                    anchors.fill: parent
                    s: root.s
                    flick: logList
                }
            }
        }

        Item { width: 1; height: root.behind ? Theme.sp.m * root.s : 0 }

        /**
         * Files whose local edits clash with upstream: Keep mine by default, Take new overwrites on apply.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            spacing: Theme.sp.s * root.s
            visible: root.conflicts.length > 0

            SettingsLabel {
                width: parent.width
                s: root.s
                topPadding: 0
                bottomPadding: 0
                wrapMode: Text.WordWrap
                text: "Your edits clash with " + root.conflicts.length + " file" + (root.conflicts.length === 1 ? "" : "s")
            }

            Repeater {
                model: root.conflicts

                Item {
                    id: confRow
                    required property var modelData
                    readonly property string rel: modelData
                    readonly property bool takeNew: root.takePaths[rel] === true

                    width: parent.width
                    height: 32 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.right: choice.left
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.labelFor(confRow.rel)
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        font.weight: Font.Medium
                    }

                    SettingsSeg {
                        id: choice
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Keep mine", value: false }, { label: "Take new", value: true }]
                        value: confRow.takeNew
                        onPicked: (v) => root.takePaths = Object.assign({}, root.takePaths, { [confRow.rel]: v })
                    }
                }
            }
        }

        Item { width: 1; height: root.conflicts.length > 0 ? Theme.sp.m * root.s : 0 }

        /**
         * Missing core packages, each on by default, so Update now brings the rice and its packages together.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            spacing: Theme.sp.s * root.s
            visible: root.behind && root.missingDeps.length > 0

            SettingsLabel {
                width: parent.width
                s: root.s
                topPadding: 0
                bottomPadding: 0
                wrapMode: Text.WordWrap
                text: "Needs " + root.missingDeps.length + " package" + (root.missingDeps.length === 1 ? "" : "s")
            }

            Repeater {
                model: root.missingDeps

                Item {
                    id: depRow
                    required property var modelData
                    readonly property string depId: modelData.id

                    width: parent.width
                    height: depCol.implicitHeight + Theme.sp.m * root.s

                    Column {
                        id: depCol
                        anchors.left: parent.left
                        anchors.right: depToggle.left
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp.xxs * root.s

                        Text {
                            text: root.prettyDep(depRow.depId)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            visible: depRow.modelData.desc.length > 0
                            text: depRow.modelData.desc
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }

                    LinkToggle {
                        id: depToggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        on: root.depChosen(depRow.depId)
                        onToggled: root.installDeps = Object.assign({}, root.installDeps, { [depRow.depId]: !root.depChosen(depRow.depId) })
                    }
                }
            }
        }

        Item { width: 1; height: (root.behind && root.missingDeps.length > 0) ? Theme.sp.m * root.s : 0 }

        /**
         * Packages the last apply couldn't install, each with the engine's reason, shown until the next check.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            spacing: Theme.sp.s * root.s
            visible: root.depFailures.length > 0

            Text {
                width: parent.width
                text: "Couldn't install " + root.depFailures.length + " package" + (root.depFailures.length === 1 ? "" : "s")
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.depFailures

                Row {
                    id: failRow
                    required property var modelData
                    width: parent.width
                    spacing: Theme.sp.s * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: Theme.sp.s * root.s
                        width: 4 * root.s
                        height: 4 * root.s
                        radius: width / 2
                        color: Theme.danger
                    }

                    Column {
                        width: parent.width - 12 * root.s
                        spacing: Theme.sp.xxs * root.s

                        Text {
                            text: root.prettyDep(failRow.modelData.id)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            text: failRow.modelData.error
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }
                }
            }
        }

        Item { width: 1; height: root.depFailures.length > 0 ? Theme.sp.m * root.s : 0 }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            visible: root.statusKind !== "devmode"
            height: visible ? 1 : 0
            color: Theme.hairSoft
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            visible: root.statusKind !== "devmode"
            height: visible ? 28 * root.s + Theme.sp.m * root.s : 0

            Text {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Theme.sp.m * root.s
                anchors.verticalCenter: actions.verticalCenter
                visible: root.restartNeeded && root.depFailures.length === 0
                text: "Updated, restarting the shell"
                color: Theme.subtle
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.sp.s * root.s

                Button {
                    s: root.s
                    kind: root.behind ? "secondary" : "primary"
                    enabled: !root.busy
                    text: root.checking ? "Checking…" : root.statusKind === "offline" ? "Retry" : "Check for updates"
                    onClicked: root.startCheck()
                }

                Button {
                    s: root.s
                    visible: root.behind
                    kind: "primary"
                    enabled: !root.applying
                    text: root.applying ? "Updating…" : "Update now"
                    onClicked: root.startApply()
                }
            }
        }
    }
}
