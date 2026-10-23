pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Singletons"

/**
 * Wallpaper filmstrip: click or Enter applies, holding the focused thumb trashes it, typing searches DuckDuckGo images.
 */
PillSurface {
    id: root

    property int focusIndex: 0

    /**
     * While on, the search field holds focus and the strip shows remote results for `query`, otherwise bare keys are watched for the first printable character.
     */
    property bool searching: false
    property string query: ""
    property var ddgResults: []

    /** Inline folder edit in the header: true while the path field holds focus. */
    property bool editingDir: false

    /**
     * Kind filter "all", "still" or "motion", splitting local files by extension and steering the DDG gif filter in search mode.
     */
    property string kindFilter: "all"

    function isMotion(path) {
        return /\.(gif|mp4|webm|mkv|mov)$/i.test(path);
    }

    readonly property string home: Quickshell.env("HOME")

    /** "/home/erik/Ricelin/wallpapers/" reads "~/Ricelin/wallpapers". */
    function shortPath(p) {
        var out = String(p);
        if (home.length > 0 && out.indexOf(home) === 0)
            out = "~" + out.slice(home.length);
        return out.length > 1 ? out.replace(/\/+$/, "") : out;
    }

    /** Monitor layout in miniature for the focused tile (2+ screens); a rect sets that output only. */
    readonly property var monMap: {
        var scr = Quickshell.screens;
        if (scr.length < 2)
            return { w: 0, h: 0, tiles: [] };
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < scr.length; i++) {
            minX = Math.min(minX, scr[i].x);
            minY = Math.min(minY, scr[i].y);
            maxX = Math.max(maxX, scr[i].x + scr[i].width);
            maxY = Math.max(maxY, scr[i].y + scr[i].height);
        }
        var k = Math.min(Math.min(26 * scr.length, 120) * s / (maxX - minX), (22 * s) / (maxY - minY));
        var tiles = [];
        for (i = 0; i < scr.length; i++)
            tiles.push({
                name: scr[i].name,
                x: (scr[i].x - minX) * k,
                y: (scr[i].y - minY) * k,
                w: scr[i].width * k,
                h: scr[i].height * k
            });
        return { w: (maxX - minX) * k, h: (maxY - minY) * k, tiles: tiles };
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
     * Re-centring is deferred with callLater because this handler fires before dependent bindings refresh.
     */
    onKindFilterChanged: {
        if (searching && query.length > 0)
            debounce.restart();
        else
            Qt.callLater(centerOnCurrent);
    }

    /**
     * Active model shared by strip, navigation and empty states: remote results for a non-empty search, else the local snapshot.
     */
    readonly property var items: (searching && query.length > 0) ? ddgResults : localItems
    readonly property int itemCount: items.length

    /**
     * Gesture hint, hidden while focus moves and revealed by the dwell timer once the pick is held still.
     */
    property bool hintShown: false

    /** Output name under the pointer in the focused tile's screen picker, "" when none. */
    property string monHover: ""

    /**
     * Playback and the dimension probe wait until focus rests, so wheeling through the strip never churns decoders or processes.
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
     * Single continuous position chasing focusIndex, so fast input (40Hz key repeat, wheel bursts) stays bounded by one chase instead of piling up per-tile animations.
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

    holdsFocus: searching

    function handleKey(e) {
        if (!searching && e.text.length === 1 && e.text > " ")
            startSearch(e.text);
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right)
            move(e.key === Qt.Key_Left ? -1 : 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (!e.isAutoRepeat)
                activate();
        } else
            return false;
        return true;
    }

    function move(delta) {
        if (itemCount === 0)
            return;
        focusIndex = Math.max(0, Math.min(itemCount - 1, focusIndex + delta));
    }

    FrameAnimation {
        running: root.active && root.pos !== root.focusIndex
        onTriggered: {
            if (Motion.calm) {
                root.pos = root.focusIndex;
                return;
            }
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
     * Leaves search and re-centres on the wallpaper on screen, used by Escape, an emptied query and a finished download.
     */
    function exitSearch() {
        searching = false;
        query = "";
        ddgResults = [];
        searchField.text = "";
        centerOnCurrent();
    }

    /**
     * shell.qml routes the opening keystroke here, so focus moves to the field for the rest of the query and returns when search ends.
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
        editingDir = false;
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
     * Qt's MediaPlayer chokes on streaming https, so curl pulls the focused result's webm preview into /tmp, keyed by url hash.
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
     * Resolution badge dims, probed with ffprobe for the focused tile only and cached per path.
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
        anchors.leftMargin: Theme.inset.side * root.s
        anchors.right: filterRow.left
        anchors.rightMargin: Theme.sp.m * root.s
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

    SettingsSeg {
        id: filterRow
        anchors.top: parent.top
        anchors.topMargin: 7 * root.s
        anchors.right: parent.right
        anchors.rightMargin: Theme.inset.side * root.s
        z: 40
        s: root.s
        options: [
            { label: "All", value: "all" },
            { label: "Still", value: "still" },
            { label: "Live", value: "motion" }
        ]
        value: root.kindFilter
        onPicked: (v) => root.kindFilter = v
    }

    SurfaceHeader {
        id: header
        anchors.top: parent.top
        anchors.topMargin: filterRow.anchors.topMargin + (filterRow.height - height) / 2
        anchors.left: parent.left
        anchors.leftMargin: Theme.inset.side * root.s
        width: childrenRect.width
        visible: !root.searching
        z: 30
        s: root.s
        glyph: "壁"
        title: "Wallpaper"
    }

    /** Folder caption beside the title; a click edits it in place (Enter saves, empty restores autodetect, Esc cancels). */
    Item {
        id: folderRow
        anchors.verticalCenter: header.verticalCenter
        anchors.left: header.left
        anchors.leftMargin: header.childrenRect.width + Theme.sp.m * root.s
        anchors.right: filterRow.left
        anchors.rightMargin: Theme.sp.m * root.s
        height: 22 * root.s
        visible: !root.searching
        z: 30

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !root.editingDir
            text: root.shortPath(Walls.wpDir)
            elide: Text.ElideMiddle
            color: folderHover.hovered ? Theme.subtle : Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        TextInput {
            id: dirField
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.editingDir
            enabled: root.editingDir
            clip: true
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            selectByMouse: true
            selectionColor: Theme.verm
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    Flags.wallpaperDir = dirField.text.trim();
                    root.editingDir = false;
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    root.editingDir = false;
                    e.accepted = true;
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: dirField.text.length === 0
                text: root.shortPath(Walls.wpDir)
                elide: Text.ElideMiddle
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
            }
        }

        HoverHandler {
            id: folderHover
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.editingDir
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.editingDir = true;
                dirField.text = Flags.wallpaperDir;
                Qt.callLater(dirField.forceActiveFocus);
            }
        }
    }

    /**
     * Only tiles within six of the focus or the gliding view exist; every other slot stays an empty Loader.
     */
    readonly property int winLo: Math.floor(Math.min(pos, focusIndex)) - 6
    readonly property int winHi: Math.ceil(Math.max(pos, focusIndex)) + 6

    Repeater {
        model: root.items

        delegate: Loader {
            required property int index
            required property var modelData

            active: index >= root.winLo && index <= root.winHi
            z: item ? item.z : 0
            sourceComponent: tileComp
        }
    }

    Component {
        id: tileComp

        Item {
            id: tile

            readonly property int index: parent ? parent.index : -1
            readonly property var modelData: parent ? parent.modelData : ({})

            readonly property string thumb: modelData.thumb !== undefined ? modelData.thumb : ""
            readonly property bool remote: modelData.image !== undefined
            readonly property string thumbSource: remote ? thumb : ("file://" + thumb)

            /**
             * Only the focused, settled tile plays (gifs in place, videos muted via ffmpeg), while the static thumb stays underneath as the loading frame.
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
             * Fades a tile near the clipped strip edge so the ends soften instead of hard-cutting at the pill's clip.
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
                    shadowColor: Qt.alpha(Theme.shadow, Theme.shadowOpacity)
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
                    color: Qt.alpha(Theme.shadow, 1)
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
                    width: 18 * root.s
                    height: 14 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.shadow, 0.55)

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 8 * root.s
                        height: 8 * root.s
                        name: "play"
                        color: Theme.cream
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: tile.focused && tile.remote && dlProc.running && dlProc.target === tile.modelData.image
                    text: "Saving…"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 6 * root.s
                    visible: tile.focused && tile.resLabel.length > 0 && !(tile.remote && dlProc.running && dlProc.target === tile.modelData.image)
                    width: resText.implicitWidth + 12 * root.s
                    height: resText.implicitHeight + 5 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.shadow, 0.55)
                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: tile.resLabel.replace("x", "×")
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
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
                Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
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

            /** Per-screen picker on the focused tile; sits above the press area so a click never reaches the trash hold. */
            Rectangle {
                id: monPick

                property string hoverOut: ""

                onHoverOutChanged: if (tile.focused) root.monHover = hoverOut

                visible: tile.focused && !tile.remote && root.monMap.tiles.length > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5 * root.s
                width: hoverLabel.width + screenRects.width + 12 * root.s
                height: screenRects.height + 8 * root.s
                radius: Theme.r.s * root.s
                color: Qt.alpha(Theme.shadow, 0.62)

                Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                Text {
                    id: hoverLabel
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: screenRects.left
                    anchors.rightMargin: monPick.hoverOut.length > 0 ? 6 * root.s : 0
                    width: monPick.hoverOut.length > 0 ? implicitWidth : 0
                    clip: true
                    text: monPick.hoverOut
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.DemiBold
                }

                Item {
                    id: screenRects
                    anchors.right: parent.right
                    anchors.rightMargin: 5 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.monMap.w
                    height: root.monMap.h

                    Repeater {
                        model: root.monMap.tiles

                        delegate: Rectangle {
                            id: mrect
                            required property var modelData

                            x: mrect.modelData.x + 0.75 * root.s
                            y: mrect.modelData.y + 0.75 * root.s
                            width: Math.max(2, mrect.modelData.w - 1.5 * root.s)
                            height: Math.max(2, mrect.modelData.h - 1.5 * root.s)
                            radius: Theme.r.xs * root.s
                            color: monArea.pressed ? Theme.vermLit : (monHover.hovered ? Qt.alpha(Theme.vermLit, 0.45) : Qt.alpha(Theme.bright, 0.10))
                            border.width: 1
                            border.color: monHover.hovered ? Theme.vermLit : Qt.alpha(Theme.bright, 0.35)

                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                            HoverHandler {
                                id: monHover
                                onHoveredChanged: monPick.hoverOut = hovered ? mrect.modelData.name : (monPick.hoverOut === mrect.modelData.name ? "" : monPick.hoverOut)
                            }

                            MouseArea {
                                id: monArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Walls.apply(tile.modelData.path, mrect.modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: root.itemCount === 0 && !searchProc.running
        s: root.s
        glyph: root.searching && root.query.length ? "" : "palette"
        text: {
            if (root.searching && root.query.length)
                return "No results";
            if (root.kindFilter === "motion")
                return "No live wallpapers yet";
            if (root.kindFilter === "still")
                return "No still wallpapers";
            return "No wallpapers in " + root.shortPath(Walls.wpDir);
        }
    }

    Text {
        anchors.centerIn: parent
        visible: searchProc.running
        text: "Searching…"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
    }

    component HintKey: Row {
        id: hk

        property string key: ""
        property string caption: ""

        spacing: 6 * root.s

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            combo: hk.key
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: hk.caption
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.Medium
        }
    }

    /** Gesture legend; hovering a screen rect swaps it for "Set on <output> only". */
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.sp.s * root.s
        width: hintLegend.width
        height: hintLegend.height
        visible: root.itemCount > 0 && !root.searching
        opacity: (root.hintShown || root.monHover.length > 0) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

        Row {
            id: hintLegend
            spacing: Theme.sp.l * root.s
            visible: root.monHover.length === 0

            HintKey { key: "Click"; caption: root.monMap.tiles.length > 0 ? "Set on all" : "Set" }
            HintKey { visible: root.monMap.tiles.length > 0; key: "Corner"; caption: "One screen" }
            HintKey { key: "Hold"; caption: "Delete" }
        }

        Text {
            anchors.centerIn: parent
            visible: root.monHover.length > 0
            text: "Set on " + root.monHover + " only"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
        }
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
