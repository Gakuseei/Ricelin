pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 更 UPDATES sub-surface: a terminal-free face for the Ricelin update engine. It
 * never touches git itself; it shells out to the python engine at
 * ~/.config/hypr/scripts/ricelin-update.py, which prints one JSON object, and
 * renders that. `check` is a safe dry-run that reports how far behind the install
 * is, the changelog, and any protected file whose local edits clash with upstream;
 * `apply` performs the update, taking upstream wholesale only for the conflicting
 * files the user explicitly opted to overwrite.
 *
 * The engine owns every policy decision (devmode detection, on-demand cloning,
 * three-way merges); this surface is a thin reader of its contract. On a dev or
 * symlinked-worktree install the engine answers "devmode" and the surface shows a
 * calm note that updates run through plain git instead, with no buttons. Reached
 * from the settings index and morphs back to it on an empty click or the back
 * chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
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

    /** Target short sha, split off the engine's "<sha> <date>" version string. */
    readonly property string targetShort: version.split(" ")[0]

    /**
     * Short sha of the installed rice, read from the engine's manifest since the
     * check result only names the target. Empty until a first apply recorded one.
     */
    property string installedShort: ""

    function readManifest() {
        try {
            root.installedShort = (JSON.parse(manifestFile.text()).syncedSha || "").slice(0, 7);
        } catch (e) {
            root.installedShort = "";
        }
    }

    /** Conflicting rel-paths the user chose to overwrite with upstream on the next apply. */
    property var takePaths: ({})

    /** Core packages this update needs that aren't installed yet: [{id, name, desc, group}]. */
    property var missingDeps: []

    /**
     * Packages the last apply couldn't bring in: [{id, error}]. A cancelled password
     * prompt, an AUR build that needs a terminal, or a repo miss all land here so a
     * failed or skipped install is never silent. Held until the next check.
     */
    property var depFailures: []

    /** Per-dep install choice, keyed by id. Absent means default ON, false means opted out. */
    property var installDeps: ({})

    /** A dep is installed on apply unless the user explicitly turned its toggle off. */
    function depChosen(id) {
        return root.installDeps[id] !== false;
    }

    /** Title-case the package id into a readable label, e.g. noto-fonts-cjk -> Noto Fonts Cjk. */
    function prettyDep(id) {
        return id.split("-").map(function (w) {
            return w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w;
        }).join(" ");
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

    readonly property color badgeTint: statusKind === "error" || statusKind === "offline" ? Theme.dim
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
        : statusKind === "behind" ? (fromDate.length > 0 ? fromDate + " → " + toDate : "")
        : ""

    onActiveChanged: {
        if (active) {
            startCheck();
        } else {
            checking = false;
            applying = false;
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

    /** Drop the behind-driven sections so they vanish once an apply has landed. */
    function clearPending() {
        behindCount = 0;
        changelog = [];
        conflicts = [];
        missingDeps = [];
        installDeps = ({});
        takePaths = ({});
    }

    /**
     * The body for the post-restart toast, composed before clearPending wipes the
     * changelog. The version line confirms what landed, and the top change names
     * what is new with a count when more rode along.
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
                 * Hold the auto-restart while any install failed: a restart wipes
                 * this surface, so the user would never see what didn't install. The
                 * code is already written to disk and lands on the next manual
                 * restart or check; the failure notice stays put until then.
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
     * New code only takes effect once the shell reloads, so do it for the user
     * instead of asking. The brief delay lets the "Updated" line register first.
     */
    Timer {
        id: restartTimer
        interval: 1200
        onTriggered: restartProc.running = true
    }

    /**
     * Relaunch the pill on its own. setsid detaches the relaunch so it outlives the
     * instance it kills, and the guard skips a second spawn if the watchdog already
     * brought it back. Settings persist through flags.json, so it returns as it was.
     */
    Process {
        id: restartProc
        command: ["setsid", "sh", "-c",
            "qs -c pill kill; sleep 0.4; qs -c pill ipc show >/dev/null 2>&1 || qs -c pill -d"]
    }

    /**
     * Drop a one-shot marker the restarted shell reads to toast what landed, since
     * the relaunch wipes this surface before any inline confirmation can stick. The
     * body rides in as a positional arg so the value is never re-parsed by the shell.
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

        SettingsHeader {
            s: root.s
            glyph: "更"
            title: "UPDATES"
            showBack: true
        }

        Item { width: 1; height: 14 * root.s }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            spacing: 12 * root.s

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
                        running: root.spinning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34 * root.s - 12 * root.s
                spacing: 3 * root.s

                Text {
                    text: root.headline
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 14.5 * root.s
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    visible: root.subline.length > 0
                    text: root.subline
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    font.features: { "tnum": 1 }
                }

                Text {
                    visible: root.version.length > 0
                    text: root.behind && root.installedShort.length > 0 && root.installedShort !== root.targetShort
                        ? root.installedShort + " → " + root.targetShort
                        : root.version.replace(" ", " · ")
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
        }

        Item { width: 1; height: 15 * root.s }

        /**
         * The changelog is the centrepiece when an update waits: each entry is a
         * short row with a small marker, the list scrolls when it outgrows its
         * cap. Hidden in every other state so up-to-date and devmode stay calm.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            spacing: 8 * root.s
            visible: root.behind

            Text {
                text: "WHAT'S NEW"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.4 * root.s
            }

            Text {
                width: parent.width
                visible: root.changelog.length === 0
                text: "No highlights noted"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
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
                    spacing: 9 * root.s
                    topPadding: 3 * root.s
                    bottomPadding: 3 * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 9 * root.s
                        width: 4 * root.s
                        height: 4 * root.s
                        radius: width / 2
                        color: Theme.vermLit
                    }

                    Text {
                        width: parent.width - 13 * root.s
                        text: parent.modelData
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.Medium
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

        Item { width: 1; height: root.behind ? 14 * root.s : 0 }

        /**
         * Conflicts: every protected file whose local edits overlap an upstream
         * change. Each lists by friendly name with a two-way choice, "Keep mine"
         * the default and "Take new" overwriting wholesale on apply.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            spacing: 9 * root.s
            visible: root.conflicts.length > 0

            Text {
                width: parent.width
                text: "Your edits clash with " + root.conflicts.length + " file" + (root.conflicts.length === 1 ? "" : "s")
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.conflicts

                Item {
                    id: confRow
                    required property var modelData
                    readonly property string rel: modelData
                    readonly property bool takeNew: root.takePaths[rel] === true

                    width: parent.width
                    height: 30 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.labelFor(confRow.rel)
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    Row {
                        id: choice
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        component Seg: Rectangle {
                            id: seg
                            property string label: ""
                            property bool on: false
                            property int corner: 0
                            width: segText.implicitWidth + 18 * root.s
                            height: 24 * root.s
                            radius: 7 * root.s
                            topLeftRadius: corner === -1 ? radius : 0
                            bottomLeftRadius: corner === -1 ? radius : 0
                            topRightRadius: corner === 1 ? radius : 0
                            bottomRightRadius: corner === 1 ? radius : 0
                            color: seg.on ? Qt.alpha(Theme.vermLit, 0.20) : Theme.frameBg
                            border.width: 1
                            border.color: seg.on ? Qt.alpha(Theme.vermLit, 0.55) : Theme.hairSoft
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                            Text {
                                id: segText
                                anchors.centerIn: parent
                                text: seg.label
                                color: seg.on ? Theme.bright : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: seg.on ? Font.DemiBold : Font.Medium
                            }
                        }

                        Seg {
                            label: "Keep mine"
                            on: !confRow.takeNew
                            corner: -1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.takePaths = Object.assign({}, root.takePaths, { [confRow.rel]: false })
                            }
                        }

                        Seg {
                            label: "Take new"
                            on: confRow.takeNew
                            corner: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.takePaths = Object.assign({}, root.takePaths, { [confRow.rel]: true })
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: root.conflicts.length > 0 ? 14 * root.s : 0 }

        /**
         * Missing packages: core packages the rice needs that aren't installed yet,
         * whether this update introduced them or they were never there. Each is a row
         * with the package label, its one-line purpose, and a toggle that defaults ON,
         * so a plain "Update now" brings the rice and its packages over together. The
         * chosen ids ride along as --install-deps and the engine batches the repo ones
         * into a single pkexec install.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            spacing: 9 * root.s
            visible: root.behind && root.missingDeps.length > 0

            Text {
                width: parent.width
                text: "Needs " + root.missingDeps.length + " package" + (root.missingDeps.length === 1 ? "" : "s")
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.missingDeps

                Item {
                    id: depRow
                    required property var modelData
                    readonly property string depId: modelData.id

                    width: parent.width
                    height: depCol.implicitHeight + 12 * root.s

                    Column {
                        id: depCol
                        anchors.left: parent.left
                        anchors.right: depToggle.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * root.s

                        Text {
                            text: root.prettyDep(depRow.depId)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11.5 * root.s
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            visible: depRow.modelData.desc.length > 0
                            text: depRow.modelData.desc
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
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

        Item { width: 1; height: (root.behind && root.missingDeps.length > 0) ? 14 * root.s : 0 }

        /**
         * Install failures: any chosen package the last apply couldn't bring in. The
         * engine already folds the manual command into each reason for the deps it
         * can't drive headless (AUR, fallback-only), so a row is package plus the
         * exact why. Shown until the next check, independent of the behind state, so a
         * cancelled prompt or a build that needs a terminal never reads as success.
         */
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            spacing: 9 * root.s
            visible: root.depFailures.length > 0

            Text {
                width: parent.width
                text: "Couldn't install " + root.depFailures.length + " package" + (root.depFailures.length === 1 ? "" : "s")
                color: Theme.verm
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.depFailures

                Row {
                    id: failRow
                    required property var modelData
                    width: parent.width
                    spacing: 9 * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 6 * root.s
                        width: 4 * root.s
                        height: 4 * root.s
                        radius: width / 2
                        color: Theme.verm
                    }

                    Column {
                        width: parent.width - 13 * root.s
                        spacing: 2 * root.s

                        Text {
                            text: root.prettyDep(failRow.modelData.id)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11.5 * root.s
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: failRow.modelData.error
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }
                }
            }
        }

        Item { width: 1; height: root.depFailures.length > 0 ? 14 * root.s : 0 }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            visible: root.behind || root.statusKind !== "devmode"
            height: visible ? 1 : 0
            color: Theme.hair
        }

        Item { width: 1; height: (root.behind || root.statusKind !== "devmode") ? 15 * root.s : 0 }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 9 * root.s

            Rectangle {
                id: updateBtn
                width: parent.width
                height: 38 * root.s
                radius: 10 * root.s
                visible: root.behind
                color: Qt.alpha(Theme.vermLit, updateHover.hovered ? 0.30 : 0.20)
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, 0.55)
                opacity: root.applying ? 0.55 : 1
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                HoverHandler {
                    id: updateHover
                    enabled: !root.applying
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.applying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startApply()
                }

                Text {
                    anchors.centerIn: parent
                    text: root.applying ? "Updating…" : "Update now"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: checkBtn
                width: parent.width
                height: 38 * root.s
                radius: 10 * root.s
                visible: root.statusKind !== "devmode"
                color: checkHover.hovered ? Qt.alpha(Theme.onGlow, 0.34) : Qt.alpha(Theme.onGlow, 0.20)
                border.width: 1
                border.color: Qt.alpha(Theme.onGlow, checkHover.hovered ? 0.6 : 0.4)
                opacity: root.busy ? 0.55 : 1
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                HoverHandler {
                    id: checkHover
                    enabled: !root.busy
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startCheck()
                }

                Text {
                    anchors.centerIn: parent
                    text: root.checking ? "Checking…"
                        : root.statusKind === "offline" ? "Retry"
                        : "Check for updates"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                visible: root.restartNeeded && root.depFailures.length === 0
                text: "Updated · restarting the shell"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }
    }
}
