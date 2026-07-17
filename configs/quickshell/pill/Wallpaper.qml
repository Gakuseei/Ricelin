pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Singletons"

/**
 * Wallpaper surface: a filmstrip over the wallpaper directory, rendered as one
 * of the pill's surfaces. Thumbs come from the Walls singleton snapshot, newest
 * first. The focused thumb is large and fully lit; neighbours shrink, dim and
 * desaturate as they slide under it, so the strip reads as depth. Arrow keys
 * and wheel move focus, clicking a neighbour glides to it, Enter or a tap on
 * the focused thumb applies it via wallpaper.sh (strip stays open so you can
 * keep trying picks). Hold the focused thumb for the heat duration to trash the
 * file (press-and-hold confirm, same as the clipboard wipe); progress sweeps
 * along the thumb's lower edge and drains on early release.
 *
 * Typing any printable character while the strip is open drops it into a
 * DuckDuckGo image search: a search field reveals at the top, the strip swaps
 * its model from local files to remote results (debounced fetch through
 * wallpaper-search.sh), and selecting a result downloads it, applies it and
 * returns to the local strip. Escape, an emptied query or a finished pick all
 * fall back to the local view.
 */
PillSurface {
    id: root

    property int focusIndex: 0

    /**
     * Search mode. While off the strip browses local files and bare keys are
     * watched for the first printable character; while on the search field is
     * shown, holds focus and the strip renders remote results for `query`.
     */
    property bool searching: false
    property string query: ""
    property var ddgResults: []

    /**
     * Kind filter shared by both views: "all", "still" or "motion". Locally it
     * splits the snapshot by extension (gif and video files count as motion);
     * in search mode it steers the DDG request (gif type filter) so the chips
     * act as one control everywhere.
     */
    property string kindFilter: "all"

    function isMotion(path) {
        return /\.(gif|mp4|webm|mkv|mov)$/i.test(path);
    }

    readonly property var localItems: {
        if (kindFilter === "all")
            return Walls.entries;
        var wantMotion = kindFilter === "motion";
        var out = [];
        for (var i = 0; i < Walls.entries.length; i++)
            if (isMotion(Walls.entries[i].path) === wantMotion)
                out.push(Walls.entries[i]);
        return out;
    }

    /**
     * Re-centre after a filter switch. Deferred with callLater because this
     * handler fires before dependent bindings refresh, so a direct call would
     * still see the previous filter's list and park the strip on an index the
     * new list does not have.
     */
    onKindFilterChanged: {
        if (searching && query.length > 0)
            debounce.restart();
        else
            Qt.callLater(centerOnCurrent);
    }

    /**
     * Active model and its select handler. The strip, navigation and empty
     * states all read these so the local and search views share one code path:
     * a populated query in search mode shows remote results, anything else the
     * local snapshot.
     */
    readonly property var items: (searching && query.length > 0) ? ddgResults : localItems
    readonly property int itemCount: items.length

    /**
     * Gesture hint visibility. Hidden while the focus is moving so paging
     * through wallpapers stays clean; the dwell timer reveals it only once the
     * pick has been held still, so it reads as a quiet caption, not a nag.
     */
    property bool hintShown: false

    /**
     * Preview arming: playback and the dimension probe only start once the
     * focus has rested for a beat, so wheeling through the strip never churns
     * decoders or process spawns per step.
     */
    property bool previewArmed: true

    onFocusIndexChanged: {
        hintShown = false;
        hintDwell.restart();
        previewArmed = false;
        previewArm.restart();
    }

    Timer {
        id: previewArm
        interval: 300
        onTriggered: root.previewArmed = true
    }

    onItemsChanged: if (focusIndex >= itemCount) focusIndex = Math.max(0, itemCount - 1);

    Timer {
        id: hintDwell
        interval: 600
        onTriggered: root.hintShown = true
    }

    /**
     * Continuous view position chasing focusIndex. The strip renders from this
     * single value, so any input rate (40Hz key autorepeat, wheel bursts) stays
     * coherent: lag is bounded by the chase time constant, not piled up across
     * per-tile retargeting animations.
     */
    property real pos: 0

    clip: true

    readonly property var slotW:      [196, 126, 104, 88, 74]
    readonly property var slotH:      [110, 71, 59, 50, 42]
    readonly property var slotCX:     [0, 143, 244, 326, 393]
    readonly property var slotBright: [1, 0.56, 0.42, 0.30, 0.22]
    readonly property var slotSat:    [1, 0.65, 0.55, 0.45, 0.40]

    function slotLerp(arr, ao) {
        if (ao >= 4)
            return arr[4];
        var i = Math.floor(ao);
        var f = ao - i;
        return arr[i] + (arr[i + 1] - arr[i]) * f;
    }

    function offsetX(off) {
        var ao = Math.abs(off);
        var cx = ao <= 4 ? slotLerp(slotCX, ao) : slotCX[4] + (ao - 4) * 60;
        return (off < 0 ? -cx : cx) * s;
    }

    function move(delta) {
        if (itemCount === 0)
            return;
        focusIndex = Math.max(0, Math.min(itemCount - 1, focusIndex + delta));
    }

    FrameAnimation {
        running: root.active && root.pos !== root.focusIndex
        onTriggered: {
            var k = 1 - Math.exp(-frameTime / 0.07);
            var next = root.pos + (root.focusIndex - root.pos) * k;
            root.pos = Math.abs(next - root.focusIndex) < 0.001 ? root.focusIndex : next;
        }
    }

    function activate() {
        if (focusIndex < 0 || focusIndex >= itemCount)
            return;
        var entry = items[focusIndex];
        if (entry.image !== undefined) {
            if (dlProc.running)
                return;
            dlProc.target = entry.image;
            dlProc.command = ["bash", root.searchScript, "download", entry.image];
            dlProc.running = true;
        } else {
            Walls.apply(entry.path);
        }
    }

    function centerOnCurrent() {
        var idx = 0;
        for (var i = 0; i < localItems.length; i++)
            if (localItems[i].path === Walls.current) {
                idx = i;
                break;
            }
        focusIndex = idx;
        pos = idx;
    }

    /**
     * Leave search mode and fall back to the local strip, re-centring on the
     * wallpaper currently on screen. Used by Escape, an emptied query and a
     * completed download.
     */
    function exitSearch() {
        searching = false;
        query = "";
        ddgResults = [];
        searchField.text = "";
        centerOnCurrent();
    }

    /**
     * Begin a search seeded with the first typed character and move keyboard
     * focus to the field so the rest of the query lands there. shell.qml routes
     * the opening keystroke here and hands focus back when the search ends.
     */
    function startSearch(ch) {
        searching = true;
        focusIndex = 0;
        pos = 0;
        searchField.text = ch;
        Qt.callLater(searchField.input.forceActiveFocus);
    }

    onActiveChanged: if (active) {
        searching = false;
        query = "";
        ddgResults = [];
        searchField.text = "";
        Walls.refresh();
        centerOnCurrent();
        hintShown = false;
        hintDwell.restart();
    }

    Connections {
        target: Walls
        function onEntriesChanged() {
            if (!root.searching && root.focusIndex >= Walls.count)
                root.focusIndex = Math.max(0, Walls.count - 1);
        }
    }

    readonly property string searchScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-search.sh"

    /**
     * Remote video previews. Qt's MediaPlayer chokes on streaming https, so
     * the focused result's preview clip (small webm) is pulled into /tmp by
     * curl and played from disk. The fetch is debounced behind the focus and
     * keyed by url hash, so paging back to a seen result replays instantly and
     * a stale download can never attach to the wrong tile.
     */
    property string previewFile: ""

    readonly property string focusedPreviewUrl: {
        if (focusIndex < 0 || focusIndex >= itemCount)
            return "";
        var e = items[focusIndex];
        return (e && e.preview !== undefined) ? e.preview : "";
    }

    onFocusedPreviewUrlChanged: {
        previewFile = "";
        prevFetch.running = false;
        prevDebounce.restart();
    }

    Timer {
        id: prevDebounce
        interval: 250
        onTriggered: {
            if (root.focusedPreviewUrl === "")
                return;
            prevFetch.url = root.focusedPreviewUrl;
            prevFetch.command = ["bash", "-c",
                "f=\"/tmp/ricelin-wp-preview-$(printf %s \"$1\" | md5sum | cut -d' ' -f1).webm\"; [ -s \"$f\" ] || curl -fsL --max-time 25 -A 'Mozilla/5.0' -o \"$f\" \"$1\" || { rm -f \"$f\"; exit 1; }; printf %s \"$f\"",
                "_", root.focusedPreviewUrl];
            prevFetch.running = true;
        }
    }

    Process {
        id: prevFetch
        property string url: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.length && prevFetch.url === root.focusedPreviewUrl)
                    root.previewFile = this.text;
            }
        }
    }

    /**
     * Local resolution badge. Dimensions are probed lazily for the focused
     * tile only (ffprobe reads images and videos alike) and cached per path,
     * so browsing stays cheap and revisits are instant.
     */
    property var dimsCache: ({})

    readonly property string focusedLocalPath: {
        if (searching && query.length > 0)
            return "";
        if (focusIndex < 0 || focusIndex >= itemCount)
            return "";
        var e = items[focusIndex];
        return (e && e.path !== undefined) ? e.path : "";
    }

    onFocusedLocalPathChanged: dimsDebounce.restart()

    Timer {
        id: dimsDebounce
        interval: 320
        onTriggered: {
            var p = root.focusedLocalPath;
            if (p === "" || root.dimsCache[p] !== undefined)
                return;
            dimsProc.running = false;
            dimsProc.path = p;
            dimsProc.command = ["sh", "-c",
                "ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 \"$1\" | head -1",
                "_", p];
            dimsProc.running = true;
        }
    }

    Process {
        id: dimsProc
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim();
                if (t.length && dimsProc.path.length) {
                    var c = Object.assign({}, root.dimsCache);
                    c[dimsProc.path] = t;
                    root.dimsCache = c;
                }
            }
        }
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: {
            if (root.query.length === 0) {
                root.ddgResults = [];
                return;
            }
            searchProc.command = ["bash", root.searchScript, "search", root.query, root.kindFilter];
            searchProc.running = true;
        }
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                try {
                    var parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed))
                        out = parsed;
                } catch (e) {
                    out = [];
                }
                root.ddgResults = out;
                root.focusIndex = 0;
                root.pos = 0;
            }
        }
    }

    Process {
        id: dlProc
        property string target: ""
        property string failed: ""
        property string savedPath: ""
        stdout: StdioCollector {
            onStreamFinished: dlProc.savedPath = this.text.trim()
        }
        onExited: function(exitCode) {
            if (exitCode === 0 && savedPath.length) {
                failed = "";
                Walls.refresh();
                Walls.apply(savedPath);
                root.exitSearch();
            } else {
                failed = target;
            }
            savedPath = "";
        }
    }

    SearchField {
        id: searchField
        anchors.top: parent.top
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.leftMargin: 20 * root.s
        anchors.right: parent.right
        anchors.rightMargin: filterRow.width + 30 * root.s
        s: root.s
        kanji: "探"
        placeholder: "Search wallpapers"
        visible: root.searching
        enabled: root.searching
        horizontalNav: true
        z: 30
        onTextChanged: {
            root.query = text;
            debounce.restart();
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.exitSearch()
        onKeyPressed: (e) => {
            if (e.key === Qt.Key_Backspace && root.query.length <= 1 && searchField.input.selectedText.length === 0) {
                root.exitSearch();
                e.accepted = true;
            }
        }
    }

    Row {
        id: filterRow
        anchors.top: parent.top
        anchors.topMargin: 10 * root.s
        anchors.right: parent.right
        anchors.rightMargin: 14 * root.s
        spacing: 5 * root.s
        z: 40

        Repeater {
            model: [
                { kind: "all", label: "all" },
                { kind: "still", label: "still" },
                { kind: "motion", label: "live" }
            ]

            delegate: Rectangle {
                id: chip

                required property var modelData

                readonly property bool on: root.kindFilter === modelData.kind

                width: chipText.implicitWidth + 14 * root.s
                height: chipText.implicitHeight + 7 * root.s
                radius: height / 2
                color: on ? Qt.alpha(Theme.vermLit, 0.16) : "transparent"
                border.width: 1
                border.color: on ? Theme.vermLit : Theme.border

                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.on ? Theme.cream : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: 0.3 * root.s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.kindFilter = chip.modelData.kind
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20 * root.s
        anchors.verticalCenter: parent.verticalCenter
        z: 0
        visible: Flags.showGlyphs && !root.searching
        text: "壁"
        color: Theme.ghost
        opacity: 0.55
        font.family: Theme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 30 * root.s
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: tile

            required property int index
            required property var modelData

            readonly property string thumb: modelData.thumb !== undefined ? modelData.thumb : ""
            readonly property bool remote: modelData.image !== undefined
            readonly property string thumbSource: remote ? thumb : ("file://" + thumb)

            /**
             * Live preview gating: only the focused tile plays, and only once
             * the strip has settled on it, so paging never spins up decoders.
             * Gifs play in place (remote ones stream the full file), videos
             * loop muted through the ffmpeg backend; everything else keeps the
             * static thumb, which also stays underneath as the loading frame.
             */
            readonly property bool isGif: /\.gif(\?|$)/i.test(remote ? (modelData.image || "") : modelData.path)
            readonly property string videoSource: remote
                ? (focused && root.previewFile !== "" ? "file://" + root.previewFile : "")
                : (/\.(mp4|webm|mkv|mov)$/i.test(modelData.path) ? "file://" + modelData.path : "")
            readonly property bool showPreview: focused && root.previewArmed && ao < 0.5
            readonly property string resLabel: remote
                ? (modelData.w > 0 ? modelData.w + "x" + modelData.h : "")
                : (root.dimsCache[modelData.path] !== undefined ? root.dimsCache[modelData.path] : "")
            readonly property bool motion: remote
                ? (modelData.preview !== undefined || isGif)
                : /\.(gif|mp4|webm|mkv|mov)$/i.test(modelData.path)

            readonly property real off: index - root.pos
            readonly property real ao: Math.abs(off)
            readonly property bool focused: index === root.focusIndex
            readonly property real bright: root.slotLerp(root.slotBright, ao)
            readonly property real sat: root.slotLerp(root.slotSat, ao)
            readonly property real corner: (8 + 2 * Math.max(0, 1 - ao)) * root.s

            readonly property real hold: trashHeat.hold
            readonly property bool committing: trashHeat.hold >= trashHeat.tapThreshold
            readonly property real commitProgress: Math.max(0, (trashHeat.hold - trashHeat.tapThreshold) / (1 - trashHeat.tapThreshold))

            /**
             * Fade a tile out as its outer edge nears the clipped strip
             * boundary, so the strip ends soften instead of getting hard-cut by
             * the pill's clip.
             */
            readonly property real edgeFade: {
                var soft = 70 * root.s;
                var gap = Math.min(x, root.width - (x + width));
                return Math.max(0, Math.min(1, gap / soft));
            }

            width: root.slotLerp(root.slotW, ao) * root.s
            height: root.slotLerp(root.slotH, ao) * root.s
            x: root.width / 2 + root.offsetX(off) - width / 2
            y: (root.height - height) / 2
            z: 10 - ao
            visible: ao <= 5
            opacity: edgeFade * (ao <= 4 ? 1 : Math.max(0, 5 - ao))

            onFocusedChanged: if (!focused) trashHeat.cancel()

            ClippingRectangle {
                id: card
                anchors.fill: parent
                radius: tile.corner
                color: Theme.tileBg

                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: tile.sat - 1
                    shadowEnabled: tile.focused
                    shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
                    shadowBlur: 0.7
                    shadowVerticalOffset: 4 * root.s
                }

                Image {
                    id: thumbImage
                    anchors.fill: parent
                    source: tile.ao <= 6 ? tile.thumbSource : ""
                    sourceSize.width: 512
                    sourceSize.height: 220
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.tileBg
                    visible: thumbImage.status === Image.Error
                }

                AnimatedImage {
                    anchors.fill: parent
                    source: tile.showPreview && tile.isGif ? (tile.remote ? tile.modelData.image : "file://" + tile.modelData.path) : ""
                    playing: source != ""
                    visible: status === AnimatedImage.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                Loader {
                    anchors.fill: parent
                    active: tile.showPreview && tile.videoSource !== ""

                    sourceComponent: Item {
                        VideoOutput {
                            id: videoPreview
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                            visible: vidPlayer.playbackState === MediaPlayer.PlayingState
                        }

                        MediaPlayer {
                            id: vidPlayer
                            videoOutput: videoPreview
                            loops: MediaPlayer.Infinite
                            source: tile.videoSource
                            onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia) play()
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 1)
                    opacity: 1 - tile.bright
                }

                Rectangle {
                    id: consume
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: card.height * tile.commitProgress
                    visible: tile.committing
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(Theme.vermBurn, 0.66) }
                        GradientStop { position: 0.74; color: Qt.alpha(Theme.vermLit, 0.30) }
                        GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 2 * root.s
                        opacity: Math.min(1, tile.commitProgress * 3)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                            GradientStop { position: 0.5; color: Theme.flameGlow }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 5 * root.s
                    visible: tile.motion
                    width: motionText.implicitWidth + 9 * root.s
                    height: motionText.implicitHeight + 4 * root.s
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.55)

                    Text {
                        id: motionText
                        anchors.centerIn: parent
                        text: "▶"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 7.5 * root.s
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: tile.focused && tile.remote && dlProc.running && dlProc.target === tile.modelData.image
                    text: "saving…"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 6 * root.s
                    visible: tile.focused && tile.resLabel.length > 0 && !(tile.remote && dlProc.running && dlProc.target === tile.modelData.image)
                    width: resText.implicitWidth + 12 * root.s
                    height: resText.implicitHeight + 5 * root.s
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: tile.resLabel.replace("x", "×")
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: tile.corner
                color: "transparent"
                border.width: 1
                border.color: {
                    if (tile.remote && dlProc.failed.length && dlProc.failed === tile.modelData.image)
                        return Theme.vermLit;
                    return tile.committing ? Theme.vermLit : Theme.border;
                }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            HeatHold {
                id: trashHeat
                tapThreshold: 0.25
                enabled: !tile.remote
                onConfirmed: if (!tile.remote) Walls.trash(tile.modelData.path)
                onTapped: root.activate()
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    if (!tile.focused)
                        return;
                    if (tile.remote)
                        root.activate();
                    else
                        trashHeat.press();
                }
                onReleased: if (tile.focused && !tile.remote) trashHeat.release()
                onExited: trashHeat.cancel()
                onClicked: if (!tile.focused) root.focusIndex = tile.index
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.itemCount === 0 && !searchProc.running
        text: {
            if (root.searching && root.query.length)
                return "no results";
            if (root.kindFilter === "motion")
                return "no live wallpapers yet";
            if (root.kindFilter === "still")
                return "no still wallpapers";
            return "No wallpapers in ~/Ricelin/wallpapers";
        }
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
    }

    Text {
        anchors.centerIn: parent
        visible: searchProc.running
        text: "searching…"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 11 * root.s
        visible: root.itemCount > 0 && !root.searching
        opacity: root.hintShown ? 1 : 0
        text: "tap to set · hold to delete"
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 10 * root.s
        font.weight: Font.Medium
        font.letterSpacing: 0.4 * root.s
        Behavior on opacity { NumberAnimation { duration: Motion.standard } }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        z: 20
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0) {
                root.move(-notches);
                acc -= notches;
            }
            event.accepted = true;
        }
    }
}
