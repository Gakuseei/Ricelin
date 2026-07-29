pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/monitors.js" as Mon
import "Singletons"

/**
 * 画 DISPLAY sub-surface. A proportional mini-map of the monitor layout sits on
 * top: one tile per output (scaled from logical size, placed by real x/y), the
 * main monitor wears a star, clicking a tile selects it and dragging one snaps
 * it left/right/above/below the other monitor as a pending move. Below the map
 * a single card edits the selected output: resolution, refresh and scale from
 * availableModes, plus a Set as main toggle on non-main outputs.
 *
 * Apply hands mode/position/scale to display-apply.sh, which snapshots the old
 * spec, evals the new one through `hl.monitor` and arms a detached 12s watchdog
 * that reverts if the change is not confirmed — so a mode that blanks the
 * screen heals itself even if the pill dies. A confirmed Keep clears the
 * watchdog and persists by rewriting that output's block in monitors.lua, or
 * appending one when the file does not know the output yet (port swaps rename
 * outputs, so a stale file must never swallow a save). Leaving the surface
 * with a change still pending reverts it right away instead of letting the
 * watchdog fire later with no countdown visible. A main swap needs no revert:
 * on Apply it points the two workspace_rule loops at the two real outputs
 * (ground truth for who is main: the loop that carries workspace 1), drags
 * the live workspaces to their new monitors and marks the output primary for
 * XWayland via xrandr.
 *
 * monitors.lua is held as in-memory text after the first read and every rewrite
 * goes through it, so a main swap and a later Keep in the same session never
 * clobber each other through a stale FileView cache. The card rows join the
 * surface row registry, so hover, the soul seam and keyboard focus behave like
 * the other settings surfaces.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property string monitorsPath: Quickshell.env("HOME") + "/.config/hypr/modules/monitors.lua"
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/display-apply.sh"

    property var monitors: []
    property string pendingOut: ""
    property string openPicker: ""
    property int countdown: 0
    property string note: ""
    property bool quietRead: false

    property string selName: ""
    property string mainName: ""
    property string luaText: ""

    /** Pending arrangement from a map drag: `{ name, side }`, or null. */
    property var pendingMove: null

    readonly property var selMon: monitorByName(selName)
    readonly property bool selIsMain: selMon !== null && selMon.name === mainName

    readonly property var scaleOptions: [
        { label: "1.0", value: 1 },
        { label: "1.25", value: 1.25 },
        { label: "1.5", value: 1.5 },
        { label: "2.0", value: 2 }
    ]

    onActiveChanged: {
        if (active) {
            cancelCountdown();
            readProc.running = true;
        } else {
            if (root.pendingOut.length > 0) {
                revertProc.out = root.pendingOut;
                revertProc.running = true;
            }
            cancelCountdown();
            openPicker = "";
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    onSelMonChanged: if (selMon) card.syncToCurrent()

    rows: {
        void root.selMon;
        void root.mainName;
        var e = [
            { item: resRow, kind: "scrub", bump: function (d) { card.bumpRes(d); } },
            { item: rateRow, kind: "scrub", bump: function (d) { card.bumpRate(d); } },
            { item: scaleRow, kind: "seg", vals: root.scaleOptions.map(function (o) { return o.value; }), get: function () { return card.pickScale; }, set: function (v) { card.pickScale = v; } }
        ];
        if (root.selMon && !root.selIsMain)
            e.push({ item: mainRow, kind: "toggle", get: function () { return card.pendingMain; }, set: function (v) { card.pendingMain = v; } });
        return e;
    }

    /**
     * Reduces a monitor's parsed modes to the list of distinct WxH, each carrying
     * the descending list of whole-number Hz offered for that resolution. The
     * native (current width/height) resolution sorts first, then the rest by
     * pixel count descending, so the default selection lands on the panel's real
     * mode.
     */
    function resolutionsFor(mon) {
        var byRes = {};
        for (var i = 0; i < mon.modes.length; i++) {
            var m = mon.modes[i];
            var key = m.w + "x" + m.h;
            if (!byRes[key])
                byRes[key] = { w: m.w, h: m.h, key: key, rates: [] };
            if (byRes[key].rates.indexOf(m.hz) === -1)
                byRes[key].rates.push(m.hz);
        }
        var list = [];
        for (var k in byRes) {
            byRes[k].rates.sort(function (a, b) { return b - a; });
            list.push(byRes[k]);
        }
        list.sort(function (a, b) {
            if (a.w === mon.width && a.h === mon.height) return -1;
            if (b.w === mon.width && b.h === mon.height) return 1;
            return (b.w * b.h) - (a.w * a.h);
        });
        return list;
    }

    function monitorByName(name) {
        for (var i = 0; i < monitors.length; i++)
            if (monitors[i].name === name)
                return monitors[i];
        return null;
    }

    /** The first monitor that is not `name`; the anchor for placement moves. */
    function otherMonitor(name) {
        for (var i = 0; i < monitors.length; i++)
            if (monitors[i].name !== name)
                return monitors[i];
        return null;
    }

    /**
     * Logical x/y of a monitor of `myW`x`myH` placed on `side` of `other`, top
     * or left edge aligned with the anchor. Negative coordinates are fine for
     * Hyprland, so left/above of an origin monitor need no re-anchoring.
     */
    function placementXY(other, side, myW, myH) {
        var oW = Math.round(other.width / other.scale);
        var oH = Math.round(other.height / other.scale);
        if (side === "left")
            return { x: other.x - myW, y: other.y };
        if (side === "above")
            return { x: other.x, y: other.y - myH };
        if (side === "below")
            return { x: other.x, y: other.y + oH };
        return { x: other.x + oW, y: other.y };
    }

    /** The pending-move x/y for `mon` using the card's current size picks, or null. */
    function pendingXY(mon) {
        if (!pendingMove || pendingMove.name !== mon.name)
            return null;
        var other = otherMonitor(mon.name);
        if (!other || card.resolutions.length === 0)
            return null;
        var res = card.resolutions[Math.min(card.resIndex, card.resolutions.length - 1)];
        return placementXY(other, pendingMove.side,
            Math.round(res.w / card.pickScale), Math.round(res.h / card.pickScale));
    }

    /**
     * A dropped tile snaps to whichever side of the other monitor its centre
     * ended on, judged in tile-normalised offsets so flat and tall layouts bias
     * the same. A drop that lands the monitor back on its current x/y clears
     * the pending move instead of arming a no-op.
     */
    function dropTile(name, cx, cy) {
        var mon = monitorByName(name);
        var other = otherMonitor(name);
        if (!mon || !other)
            return;
        var oT = null;
        var tiles = mapLayout.tiles;
        for (var i = 0; i < tiles.length; i++)
            if (tiles[i].name !== name) { oT = tiles[i]; break; }
        if (!oT)
            return;
        var nx = (cx - (oT.x + oT.w / 2)) / oT.w;
        var ny = (cy - (oT.y + oT.h / 2)) / oT.h;
        var side = Math.abs(nx) >= Math.abs(ny) ? (nx < 0 ? "left" : "right") : (ny < 0 ? "above" : "below");
        var res = card.resolutions.length > 0 ? card.resolutions[Math.min(card.resIndex, card.resolutions.length - 1)] : null;
        var myW = res ? Math.round(res.w / card.pickScale) : Math.round(mon.width / mon.scale);
        var myH = res ? Math.round(res.h / card.pickScale) : Math.round(mon.height / mon.scale);
        var p = placementXY(other, side, myW, myH);
        pendingMove = (p.x === mon.x && p.y === mon.y) ? null : { name: name, side: side };
    }

    /**
     * Scaled tile geometry for the mini-map: logical rects (mode over scale,
     * pending move substituted for its monitor) fitted into the map width and a
     * capped height, centred horizontally. Selection and main state stay out of
     * the entries on purpose — they are read per-tile from root, so clicking a
     * tile never rebuilds the Repeater under an active press.
     */
    readonly property var mapLayout: {
        var mons = root.monitors;
        if (mons.length === 0 || mapBox.width <= 0)
            return { h: 0, tiles: [] };
        var rects = [];
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            var r = { name: m.name, hz: m.refresh, x: m.x, y: m.y, w: Math.round(m.width / m.scale), h: Math.round(m.height / m.scale) };
            var p = root.pendingXY(m);
            if (p) {
                var res = card.resolutions[Math.min(card.resIndex, card.resolutions.length - 1)];
                r.x = p.x;
                r.y = p.y;
                r.w = Math.round(res.w / card.pickScale);
                r.h = Math.round(res.h / card.pickScale);
            }
            rects.push(r);
            minX = Math.min(minX, r.x);
            minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.w);
            maxY = Math.max(maxY, r.y + r.h);
        }
        var k = Math.min(mapBox.width / (maxX - minX), (96 * root.s) / (maxY - minY));
        var ox = (mapBox.width - (maxX - minX) * k) / 2;
        var tiles = rects.map(function (t) {
            return { name: t.name, hz: t.hz, x: ox + (t.x - minX) * k, y: (t.y - minY) * k, w: t.w * k, h: t.h * k };
        });
        return { h: (maxY - minY) * k, tiles: tiles };
    }

    /**
     * monitors.lua as in-memory text: read once, then every rewrite updates it
     * before hitting disk, so back-to-back edits never read a stale file cache.
     */
    function luaNow() {
        if (luaText.length === 0)
            luaText = monitorsFile.text();
        return luaText;
    }

    /** The main monitor is whichever one the workspace-1 rule loop points at. */
    function mainFromLua(text) {
        var re = /for\s+i\s*=\s*(\d+)\s*,\s*(\d+)\s+do\s*\n\s*hl\.workspace_rule\(\{[^}]*monitor\s*=\s*"([^"]+)"/g;
        var m;
        while ((m = re.exec(text)) !== null)
            if (parseInt(m[1], 10) <= 1 && parseInt(m[2], 10) >= 1)
                return m[3];
        return "";
    }

    function applyMainSwap(name) {
        var other = otherMonitor(name);
        if (!other) {
            note = "Set as main needs two connected monitors.";
            return;
        }
        var res = Mon.setWorkspaceLoops(luaNow(), name, other.name);
        card.pendingMain = false;
        if (!res.ok) {
            note = "Could not rewrite the workspace rules in monitors.lua.";
            return;
        }
        luaText = res.text;
        writer.setText(res.text);
        mainName = mainFromLua(res.text);
        xrandrProc.out = name;
        xrandrProc.running = true;
        wsMoveProc.mainOut = name;
        wsMoveProc.otherOut = other.name;
        wsMoveProc.mainRange = res.mainRange;
        wsMoveProc.otherRange = res.otherRange;
        wsMoveProc.running = true;
        if (!card.dirty)
            note = "Saved. " + name + " is the main monitor now.";
    }

    Process {
        id: readProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monitors = Mon.parse(this.text);
                root.mainName = root.mainFromLua(root.luaNow());
                if (!root.monitorByName(root.selName)) {
                    var main = root.monitorByName(root.mainName);
                    root.selName = main ? main.name : (root.monitors.length > 0 ? root.monitors[0].name : "");
                }
                if (!root.quietRead)
                    root.note = "Changes apply live, no reload. If a mode looks wrong, it reverts on its own after 12s.";
                root.quietRead = false;
            }
        }
    }

    Process {
        id: applyProc
        property string out: ""
        property string mode: ""
        property string position: ""
        property real scale: 1
        command: ["sh", "-c",
            "sh \"$1\" apply \"$2\" \"$3\" \"$4\" \"$5\"",
            "sh", root.helper, out, mode, position, String(scale)]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.startCountdown();
            } else {
                root.pendingOut = "";
                root.note = "Apply failed — the helper could not snapshot the current mode.";
            }
        }
    }

    Process {
        id: keepProc
        property string out: ""
        command: ["sh", "-c", "sh \"$1\" keep \"$2\"", "sh", root.helper, out]
    }

    Process {
        id: revertProc
        property string out: ""
        command: ["sh", "-c", "sh \"$1\" revert \"$2\"", "sh", root.helper, out]
    }

    /** Drags each live workspace onto its new monitor after a main swap. */
    Process {
        id: wsMoveProc
        property string mainOut: ""
        property string otherOut: ""
        property var mainRange: [1, 5]
        property var otherRange: [6, 10]
        command: ["sh", "-c",
            "for i in $(seq \"$1\" \"$2\"); do hyprctl dispatch moveworkspacetomonitor \"$i\" \"$3\" >/dev/null 2>&1; done; " +
            "for i in $(seq \"$4\" \"$5\"); do hyprctl dispatch moveworkspacetomonitor \"$i\" \"$6\" >/dev/null 2>&1; done",
            "sh", String(mainRange[0]), String(mainRange[1]), mainOut,
            String(otherRange[0]), String(otherRange[1]), otherOut]
    }

    /** XWayland primary flag; runs only when a main swap is applied. */
    Process {
        id: xrandrProc
        property string out: ""
        command: ["xrandr", "--output", out, "--primary"]
    }

    /**
     * Applies whatever is pending on the selected monitor. A main swap persists
     * at once (it is not a mode change, nothing to revert); mode, scale or a
     * dragged move go to the helper's apply verb and its 12s watchdog. Only
     * availableModes Hz reach the mode string, so an unsupported mode can never
     * be requested.
     */
    function apply() {
        var mon = root.selMon;
        if (!mon || root.pendingOut.length > 0)
            return;
        if (card.pendingMain && !root.selIsMain)
            applyMainSwap(mon.name);
        if (!card.dirty)
            return;
        var res = card.resolutions[Math.min(card.resIndex, card.resolutions.length - 1)];
        var hz = res.rates[Math.min(card.rateIndex, res.rates.length - 1)];
        var p = pendingXY(mon);
        applyProc.out = mon.name;
        applyProc.mode = res.w + "x" + res.h + "@" + hz;
        applyProc.position = p ? p.x + "x" + p.y : mon.x + "x" + mon.y;
        applyProc.scale = card.pickScale;
        root.pendingOut = mon.name;
        applyProc.running = true;
    }

    function startCountdown() {
        root.countdown = 12;
        countTimer.start();
    }

    /**
     * Confirm the pending change: clear the helper's watchdog so it will not
     * revert, persist by rewriting that output's block in monitors.lua, then
     * quietly re-read the live layout so the map lands on ground truth.
     */
    function keep() {
        if (root.pendingOut.length === 0)
            return;
        keepProc.out = root.pendingOut;
        keepProc.running = true;
        var res = Mon.setMonitor(luaNow(), applyProc.out, applyProc.mode, applyProc.position, applyProc.scale);
        cancelCountdown();
        if (!res.ok) {
            root.note = "Live for now, but monitors.lua was not written: " + res.error;
            return;
        }
        luaText = res.text;
        writer.setText(res.text);
        root.quietRead = true;
        readProc.running = true;
        root.note = "Saved. " + applyProc.out + " set to " + applyProc.mode + " · scale " + applyProc.scale;
    }

    /**
     * Stop the countdown and forget the pending output. Called on Keep, on the
     * watchdog-driven timeout (the helper has already reverted the live mode), and
     * when the surface closes.
     */
    function cancelCountdown() {
        countTimer.stop();
        root.countdown = 0;
        root.pendingOut = "";
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                root.cancelCountdown();
                root.quietRead = true;
                readProc.running = true;
                root.note = "Reverted — the change was not confirmed in time.";
            }
        }
    }

    FileView {
        id: monitorsFile
        path: root.monitorsPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: writer
        path: root.monitorsPath
        atomicWrites: true
        printErrors: false
        onSaveFailed: (err) => {
            root.note = "Live mode kept, but writing monitors.lua failed.";
            console.log("display: write failed: " + err);
        }
    }

    /**
     * One registry row inside the monitor card: a leading line icon (or a text
     * glyph for the star), the shared hover/focus treatment, and hover and
     * clicks routed through reportRowHover/activateRow so the soul seam and
     * keyboard focus track these rows like SettingsRow lines. The highlight
     * hugs only the head line, so an open dropdown grows past it.
     */
    component CardRow: Item {
        id: crow

        property string icon: ""
        property string glyphText: ""
        default property alias content: crowInner.data

        readonly property bool focused: root.focusRowItem === crow

        width: parent ? parent.width : 0
        implicitHeight: crowInner.childrenRect.height

        HoverHandler {
            id: crowHover
            onHoveredChanged: root.reportRowHover(crow, hovered)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: -3 * root.s
            anchors.leftMargin: -7 * root.s
            anchors.rightMargin: -7 * root.s
            height: 32 * root.s
            radius: 8 * root.s
            color: (crowHover.hovered || crow.focused) ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateRow(crow)
        }

        GlyphIcon {
            id: crowIcon
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 5 * root.s
            width: 16 * root.s
            height: 16 * root.s
            name: crow.icon
            visible: crow.icon.length > 0
            color: crow.focused ? Theme.cream : Theme.subtle
            stroke: 1.8
        }

        Text {
            anchors.centerIn: crowIcon
            visible: crow.glyphText.length > 0
            text: crow.glyphText
            color: crow.focused ? Theme.cream : Theme.subtle
            font.family: Theme.fontJp
            font.pixelSize: 13 * root.s
        }

        Item {
            id: crowInner
            anchors.left: crowIcon.right
            anchors.leftMargin: 9 * root.s
            anchors.right: parent.right
            anchors.top: parent.top
            height: childrenRect.height
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "画"
            title: "DISPLAY"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 12 * root.s

            Item {
                id: mapBox
                width: parent.width
                height: root.mapLayout.h
                Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

                Repeater {
                    model: root.mapLayout.tiles

                    Rectangle {
                        id: tile
                        required property var modelData

                        readonly property bool sel: tile.modelData.name === root.selName
                        readonly property bool isMain: tile.modelData.name === root.mainName
                        readonly property bool moved: root.pendingMove !== null && root.pendingMove.name === tile.modelData.name
                        property real dx: 0
                        property real dy: 0

                        x: tile.modelData.x + 1.5 * root.s + dx
                        y: tile.modelData.y + 1.5 * root.s + dy
                        width: Math.max(2, tile.modelData.w - 3 * root.s)
                        height: Math.max(2, tile.modelData.h - 3 * root.s)
                        z: tileMA.pressed ? 10 : (tile.sel ? 5 : 0)
                        radius: 7 * root.s
                        color: tile.sel ? Qt.alpha(Theme.onGlow, 0.13) : Theme.cardTop
                        border.width: 1
                        border.color: tile.moved ? Qt.alpha(Theme.vermLit, 0.7) : (tile.sel ? Theme.cream : Theme.hairSoft)

                        Behavior on x { enabled: !tileMA.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                        Behavior on y { enabled: !tileMA.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2 * root.s

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.name
                                color: tile.sel ? Theme.cream : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.hz + "Hz"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 8.5 * root.s
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }

                        Text {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 3 * root.s
                            anchors.rightMargin: 5 * root.s
                            visible: tile.isMain
                            text: "★"
                            color: Theme.vermLit
                            font.family: Theme.fontJp
                            font.pixelSize: 9.5 * root.s
                        }

                        /**
                         * Manual drag: local deltas accumulate onto the layout
                         * position, so the binding keeps owning x/y and the snap
                         * animation plays the moment the deltas reset on release.
                         */
                        MouseArea {
                            id: tileMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : (root.monitors.length >= 2 ? Qt.OpenHandCursor : Qt.PointingHandCursor)
                            property real sx: 0
                            property real sy: 0
                            onPressed: (mouse) => {
                                if (root.pendingOut.length === 0)
                                    root.selName = tile.modelData.name;
                                sx = mouse.x;
                                sy = mouse.y;
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed || root.monitors.length < 2 || root.pendingOut.length > 0)
                                    return;
                                tile.dx += mouse.x - sx;
                                tile.dy += mouse.y - sy;
                            }
                            onReleased: {
                                if (tile.dx !== 0 || tile.dy !== 0)
                                    root.dropTile(tile.modelData.name, tile.x + tile.width / 2, tile.y + tile.height / 2);
                                tile.dx = 0;
                                tile.dy = 0;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: card
                visible: root.selMon !== null
                width: parent.width
                radius: Motion.rTile * root.s
                color: Theme.cardTop
                border.width: 1
                border.color: card.pending ? Qt.alpha(Theme.vermLit, 0.55) : Theme.hairSoft
                implicitHeight: cardCol.implicitHeight + 22 * root.s
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                property int resIndex: 0
                property int rateIndex: 0
                property real pickScale: 1
                property bool pendingMain: false

                readonly property var resolutions: root.selMon ? root.resolutionsFor(root.selMon) : []
                readonly property var rates: resolutions.length > 0 ? resolutions[Math.min(resIndex, resolutions.length - 1)].rates : []
                readonly property bool pending: root.selMon !== null && root.pendingOut === root.selMon.name

                /** Anything the helper flow would change: mode, scale or a dragged move. */
                readonly property bool dirty: {
                    var mon = root.selMon;
                    if (!mon || card.resolutions.length === 0)
                        return false;
                    var res = card.resolutions[Math.min(card.resIndex, card.resolutions.length - 1)];
                    var hz = res.rates[Math.min(card.rateIndex, res.rates.length - 1)];
                    if (res.w !== mon.width || res.h !== mon.height || hz !== mon.refresh)
                        return true;
                    if (card.pickScale !== mon.scale)
                        return true;
                    var p = root.pendingXY(mon);
                    return p !== null && (p.x !== mon.x || p.y !== mon.y);
                }
                readonly property bool applyReady: dirty || (pendingMain && !root.selIsMain)

                /**
                 * Seed the pickers from the selected monitor's live mode: the
                 * resolution whose WxH matches the current width/height, then the
                 * Hz nearest the current refresh within that resolution. Switching
                 * selection lands here too, dropping any un-applied edits.
                 */
                /**
                 * Seeds from locally computed lists, never from `card.rates`: inside
                 * onSelMonChanged the dependent bindings can still hold the previous
                 * monitor's values (handler order vs binding invalidation), which
                 * seeded HDMI's rate index against DP-1's rate list.
                 */
                function syncToCurrent() {
                    var mon = root.selMon;
                    if (!mon)
                        return;
                    var resos = root.resolutionsFor(mon);
                    var ri = 0;
                    for (var i = 0; i < resos.length; i++) {
                        if (resos[i].w === mon.width && resos[i].h === mon.height) {
                            ri = i;
                            break;
                        }
                    }
                    card.resIndex = ri;
                    card.rateIndex = card.nearestIn(resos.length > 0 ? resos[ri].rates : [], mon.refresh);
                    card.pickScale = mon.scale;
                    card.pendingMain = false;
                    if (root.pendingMove)
                        root.pendingMove = null;
                    root.openPicker = "";
                }

                function nearestIn(rates, hz) {
                    var best = 0;
                    var bestDiff = 1e9;
                    for (var i = 0; i < rates.length; i++) {
                        var d = Math.abs(rates[i] - hz);
                        if (d < bestDiff) { bestDiff = d; best = i; }
                    }
                    return best;
                }

                function nearestRateIndex(hz) {
                    return nearestIn(card.rates, hz);
                }

                function bumpRes(d) {
                    var i = Math.max(0, Math.min(card.resolutions.length - 1, card.resIndex + d));
                    if (i === card.resIndex)
                        return;
                    card.resIndex = i;
                    card.rateIndex = card.nearestRateIndex(card.rates.length > 0 ? card.rates[0] : 60);
                }

                function bumpRate(d) {
                    var cur = Math.min(card.rateIndex, Math.max(0, card.rates.length - 1));
                    card.rateIndex = Math.max(0, Math.min(card.rates.length - 1, cur + d));
                }

                Column {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 13 * root.s
                    anchors.rightMargin: 13 * root.s
                    anchors.topMargin: 11 * root.s
                    spacing: 9 * root.s

                    Text {
                        text: root.selMon ? root.selMon.name + (root.selIsMain ? "  ·  Main" : "") : ""
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }

                    CardRow {
                        id: resRow
                        icon: "monitor"

                        DisplayPicker {
                            width: parent.width
                            s: root.s
                            label: "Resolution"
                            options: card.resolutions.map(function (r, i) { return { label: r.w + "×" + r.h, value: i }; })
                            value: card.resIndex
                            open: root.openPicker === root.selName + ":res"
                            onRequestToggle: root.openPicker = (root.openPicker === root.selName + ":res" ? "" : root.selName + ":res")
                            onPicked: (v) => {
                                card.resIndex = v;
                                card.rateIndex = card.nearestRateIndex(card.rates.length > 0 ? card.rates[0] : 60);
                                root.openPicker = "";
                            }
                        }
                    }

                    CardRow {
                        id: rateRow
                        icon: "reboot"

                        DisplayPicker {
                            width: parent.width
                            s: root.s
                            label: "Refresh"
                            options: card.rates.map(function (hz, i) { return { label: hz + "Hz", value: i }; })
                            value: Math.min(card.rateIndex, Math.max(0, card.rates.length - 1))
                            open: root.openPicker === root.selName + ":rate"
                            onRequestToggle: root.openPicker = (root.openPicker === root.selName + ":rate" ? "" : root.selName + ":rate")
                            onPicked: (v) => {
                                card.rateIndex = v;
                                root.openPicker = "";
                            }
                        }
                    }

                    CardRow {
                        id: scaleRow
                        icon: "scaling"

                        Row {
                            width: parent.width
                            spacing: 8 * root.s

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64 * root.s
                                text: "Scale"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: Font.Medium
                            }

                            SettingsSeg {
                                anchors.verticalCenter: parent.verticalCenter
                                s: root.s
                                options: root.scaleOptions
                                value: card.pickScale
                                onPicked: (v) => card.pickScale = v
                            }
                        }
                    }

                    CardRow {
                        id: mainRow
                        glyphText: "★"
                        visible: root.selMon !== null && !root.selIsMain

                        Item {
                            width: parent.width
                            height: 26 * root.s

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Set as main"
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                font.weight: Font.DemiBold
                            }

                            LinkToggle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                s: root.s
                                on: card.pendingMain
                                onToggled: card.pendingMain = !card.pendingMain
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 30 * root.s

                        Rectangle {
                            id: applyBtn
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !card.pending && root.pendingOut.length === 0
                            width: applyLabel.implicitWidth + 28 * root.s
                            height: 28 * root.s
                            radius: 9 * root.s
                            color: !card.applyReady ? Qt.alpha(Theme.onGlow, 0.10)
                                : (applyArea.containsMouse ? Qt.alpha(Theme.onGlow, 0.34) : Qt.alpha(Theme.onGlow, 0.20))
                            border.width: 1
                            border.color: Qt.alpha(Theme.onGlow, !card.applyReady ? 0.22 : (applyArea.containsMouse ? 0.6 : 0.4))
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                            Text {
                                id: applyLabel
                                anchors.centerIn: parent
                                text: "Apply"
                                color: card.applyReady ? Theme.cream : Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.3 * root.s
                            }

                            MouseArea {
                                id: applyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: card.applyReady ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (card.applyReady) root.apply()
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.pending
                            spacing: 9 * root.s

                            Rectangle {
                                id: keepBtn
                                anchors.verticalCenter: parent.verticalCenter
                                width: keepLabel.implicitWidth + 28 * root.s
                                height: 28 * root.s
                                radius: 9 * root.s
                                color: keepArea.containsMouse ? Theme.vermLit : Theme.verm
                                Behavior on color { ColorAnimation { duration: Motion.fast } }

                                Text {
                                    id: keepLabel
                                    anchors.centerIn: parent
                                    text: "Keep (" + root.countdown + ")"
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: 10.5 * root.s
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.3 * root.s
                                }

                                MouseArea {
                                    id: keepArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.keep()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "reverts automatically if not kept"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 9.5 * root.s
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.note.length > 0
                text: root.note
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }
        }

        Item { width: 1; height: 4 * root.s }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.pendingOut.length > 0
        z: 50
        onClicked: {}
    }
}
