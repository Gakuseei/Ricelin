pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "lib/monitors.js" as Mon
import "Singletons"

/**
 * 画 DISPLAY: a draggable mini-map of the outputs, then mode, scale and main for the picked one; Apply goes through display-apply.sh, which reverts after 12 s unless kept.
 */
SettingsSurface {
    id: root

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

    /**
     * Pending arrangement from a map drag: `{ name, side }`, or null.
     */
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
            { item: resPick.row, kind: "scrub", bump: function (d) { card.bumpRes(d); }, activate: function () { root.togglePicker("res"); } },
            { item: ratePick.row, kind: "scrub", bump: function (d) { card.bumpRate(d); }, activate: function () { root.togglePicker("rate"); } },
            { item: scaleRow, kind: "seg", vals: root.scaleOptions.map(function (o) { return o.value; }), get: function () { return card.pickScale; }, set: function (v) { card.pickScale = v; } }
        ];
        if (root.selMon && !root.selIsMain)
            e.push({ item: mainRow, kind: "toggle", get: function () { return card.pendingMain; }, set: function (v) { card.pendingMain = v; } });
        return e;
    }

    /**
     * Distinct WxH modes, each with its Hz descending; the native resolution sorts first, then by pixel count.
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

    /**
     * The first monitor that is not `name`; the anchor for placement moves.
     */
    function otherMonitor(name) {
        for (var i = 0; i < monitors.length; i++)
            if (monitors[i].name !== name)
                return monitors[i];
        return null;
    }

    /**
     * Logical x/y for a `myW`x`myH` monitor on `side` of `other`, edges aligned; negative coordinates are fine.
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

    /**
     * The pending-move x/y for `mon` using the card's current size picks, or null.
     */
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
     * A dropped tile snaps to the side of the other monitor its centre landed on; a drop back home clears the move.
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
     * Mini-map tile rects; selection stays out of the entries so a click never rebuilds the Repeater mid-press.
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
     * monitors.lua held in memory after the first read, so back-to-back rewrites never see a stale cache.
     */
    function luaNow() {
        if (luaText.length === 0)
            luaText = monitorsFile.text();
        return luaText;
    }

    /**
     * The main monitor is whichever one the workspace-1 rule loop points at.
     */
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
        moveWorkspaces(res.mainRange, name);
        moveWorkspaces(res.otherRange, other.name);
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
                root.note = "Apply failed. The current mode could not be saved first.";
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

    function moveWorkspaces(range, monitor) {
        for (var i = range[0]; i <= range[1]; i++)
            Hyprland.dispatch("hl.dsp.workspace.move({ workspace = " + i + ", monitor = '" + monitor + "' })");
    }

    /**
     * XWayland primary flag; runs only when a main swap is applied.
     */
    Process {
        id: xrandrProc
        property string out: ""
        command: ["xrandr", "--output", out, "--primary"]
    }

    /**
     * A main swap persists at once; mode, scale or a move go to the helper and its 12 s watchdog.
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
     * Clears the watchdog, persists the output block and quietly re-reads the live layout.
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
     * Called on Keep, on the watchdog timeout (the helper already reverted) and on close.
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
                root.note = "Reverted. The change was not kept in time.";
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
     * Pending picks for the selected output.
     */
    QtObject {
        id: card

        property int resIndex: 0
        property int rateIndex: 0
        property real pickScale: 1
        property bool pendingMain: false

        readonly property var resolutions: root.selMon ? root.resolutionsFor(root.selMon) : []
        readonly property var rates: resolutions.length > 0 ? resolutions[Math.min(resIndex, resolutions.length - 1)].rates : []
        readonly property bool pending: root.selMon !== null && root.pendingOut === root.selMon.name

        /**
         * Anything the helper flow would change: mode, scale or a dragged move.
         */
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
         * Seeds from locally computed lists, never `card.rates`, which can still hold the previous monitor's values here.
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
    }

    function togglePicker(which) {
        var key = root.selName + ":" + which;
        root.openPicker = root.openPicker === key ? "" : key;
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

        SurfaceHeader {
            s: root.s
            glyph: "画"
            title: "DISPLAY"
            canBack: true
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Item {
            id: mapBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
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
                    radius: Theme.r.s * root.s
                    color: tile.sel ? Qt.alpha(Theme.onGlow, 0.13) : (tileMA.containsMouse ? Theme.cardTop : Theme.frameBg)
                    border.width: 1
                    border.color: tile.moved ? Qt.alpha(Theme.vermLit, 0.7) : (tile.sel ? Theme.cream : Theme.hairSoft)
                    scale: tileMA.pressed && !Motion.calm ? 0.97 : 1

                    Behavior on x { enabled: !tileMA.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    Behavior on y { enabled: !tileMA.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp.xxs * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.name
                            color: tile.sel ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.hz + " Hz"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: Theme.sp.xs * root.s
                        anchors.rightMargin: Theme.sp.s * root.s
                        visible: tile.isMain
                        text: "★"
                        color: Theme.vermLit
                        font.family: Theme.fontJp
                        font.pixelSize: Theme.fs.meta * root.s
                    }

                    /**
                     * Local drag deltas ride on the layout position, so the snap animation plays when they reset on release.
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

        SettingsLabel {
            s: root.s
            leftPadding: Theme.sp.m * root.s
            visible: root.selMon !== null
            text: root.selMon ? root.selMon.name + (root.selIsMain ? "  ·  Main" : "") : ""
        }

        DisplayPicker {
            id: resPick
            surface: root
            icon: "monitor"
            name: "Resolution"
            options: card.resolutions.map(function (r, i) { return { label: r.w + "×" + r.h, value: i }; })
            value: card.resIndex
            open: root.openPicker === root.selName + ":res"
            onRequestToggle: root.togglePicker("res")
            onPicked: (v) => {
                card.resIndex = v;
                card.rateIndex = card.nearestRateIndex(card.rates.length > 0 ? card.rates[0] : 60);
                root.openPicker = "";
            }
        }

        DisplayPicker {
            id: ratePick
            surface: root
            icon: "reboot"
            name: "Refresh rate"
            options: card.rates.map(function (hz, i) { return { label: hz + " Hz", value: i }; })
            value: Math.min(card.rateIndex, Math.max(0, card.rates.length - 1))
            open: root.openPicker === root.selName + ":rate"
            onRequestToggle: root.togglePicker("rate")
            onPicked: (v) => {
                card.rateIndex = v;
                root.openPicker = "";
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            icon: "scaling"
            name: "Scale"
            last: root.selIsMain

            SettingsSeg {
                s: root.s
                options: root.scaleOptions
                value: card.pickScale
                onPicked: (v) => card.pickScale = v
            }
        }

        SettingsRow {
            id: mainRow
            surface: root
            icon: "layers"
            name: "Set as main"
            sub: "Moves the main workspaces here"
            collapsed: root.selMon === null || root.selIsMain
            last: true

            LinkToggle {
                s: root.s
                on: card.pendingMain
                onToggled: card.pendingMain = !card.pendingMain
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            height: 28 * root.s + Theme.sp.m * root.s

            Text {
                anchors.left: parent.left
                anchors.right: actionBtn.left
                anchors.rightMargin: Theme.sp.m * root.s
                anchors.verticalCenter: actionBtn.verticalCenter
                visible: card.pending
                text: "Reverts in " + root.countdown + " s unless you keep it"
                color: Theme.subtle
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.features: { "tnum": 1 }
            }

            Button {
                id: actionBtn
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                s: root.s
                kind: "primary"
                text: card.pending ? "Keep" : "Apply"
                enabled: card.pending || (card.applyReady && root.pendingOut.length === 0)
                onClicked: card.pending ? root.keep() : root.apply()
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.rightMargin: Theme.sp.m * root.s
            topPadding: Theme.sp.m * root.s
            visible: root.note.length > 0
            text: root.note
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.pendingOut.length > 0
        z: 50
        onClicked: {}
    }
}
