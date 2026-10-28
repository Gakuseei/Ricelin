pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../lib/monitors.js" as Mon
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "display"
    resettable: false

    readonly property string monitorsPath: Quickshell.env("HOME") + "/.config/hypr/modules/monitors.lua"
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/display-apply.sh"

    property var monitors: []
    property string selName: ""
    property string mainName: ""
    property string luaText: ""
    property bool luaRead: false
    property string pendingOut: ""
    property int countdown: 0
    property string note: ""
    property bool quietRead: false
    property bool loaded: false

    /** A map drag waiting for Apply: `{ name, side }`, or null. */
    property var pendingMove: null

    property int resIndex: 0
    property int rateIndex: 0
    property real pickScale: 1
    property bool pendingMain: false

    readonly property var selMon: monitorByName(selName)
    readonly property bool selIsMain: selMon !== null && selMon.name === mainName
    readonly property bool locked: pendingOut.length > 0
    readonly property var resolutions: selMon ? resolutionsFor(selMon) : []
    readonly property var pickedRes: resolutions.length > 0 ? resolutions[Math.min(resIndex, resolutions.length - 1)] : null
    readonly property var rates: pickedRes ? pickedRes.rates : []
    readonly property int pickedHz: rates.length > 0 ? rates[Math.min(rateIndex, rates.length - 1)] : 0
    readonly property bool pending: selMon !== null && pendingOut === selMon.name
    readonly property var nativeRes: selMon && selMon.modes.length > 0 ? selMon.modes.reduce((a, m) => m.w * m.h > a.w * a.h ? m : a) : null

    readonly property var changes: {
        const mon = selMon;
        const out = [];
        if (!mon || !pickedRes)
            return out;
        if (pickedRes.w !== mon.width || pickedRes.h !== mon.height)
            out.push("resolution");
        if (pickedHz !== mon.refresh)
            out.push("refresh rate");
        if (pickScale !== mon.scale)
            out.push("scale");
        const p = pendingXY(mon);
        if (p !== null && (p.x !== mon.x || p.y !== mon.y))
            out.push("position");
        if (pendingMain && !selIsMain)
            out.push("main monitor");
        return out;
    }
    readonly property bool dirty: changes.some(c => c !== "main monitor")
    readonly property bool applyReady: changes.length > 0

    readonly property var scaleOptions: {
        const base = [1, 1.25, 1.5, 2];
        const list = selMon && base.indexOf(selMon.scale) < 0 ? base.concat([selMon.scale]).sort((a, b) => a - b) : base;
        return list.map(v => ({ label: Math.round(v * 100) + "%", value: v }));
    }

    Component.onCompleted: readProc.running = true

    /** Leaving with an unkept mode puts the old one back, the same as letting the timer run out. */
    Component.onDestruction: {
        if (pendingOut.length > 0)
            Quickshell.execDetached(["sh", "-c", "sh \"$1\" revert \"$2\"", "sh", helper, pendingOut]);
    }

    onSelMonChanged: if (selMon) syncToCurrent()

    function monitorByName(name) {
        for (let i = 0; i < monitors.length; i++)
            if (monitors[i].name === name)
                return monitors[i];
        return null;
    }

    function otherMonitor(name) {
        for (let i = 0; i < monitors.length; i++)
            if (monitors[i].name !== name)
                return monitors[i];
        return null;
    }

    function resolutionsFor(mon) {
        const byRes = {};
        for (let i = 0; i < mon.modes.length; i++) {
            const m = mon.modes[i];
            const key = m.w + "x" + m.h;
            if (!byRes[key])
                byRes[key] = { w: m.w, h: m.h, key: key, rates: [] };
            if (byRes[key].rates.indexOf(m.hz) === -1)
                byRes[key].rates.push(m.hz);
        }
        const list = [];
        for (const k in byRes) {
            byRes[k].rates.sort((a, b) => b - a);
            list.push(byRes[k]);
        }
        list.sort((a, b) => {
            if (a.w === mon.width && a.h === mon.height)
                return -1;
            if (b.w === mon.width && b.h === mon.height)
                return 1;
            return b.w * b.h - a.w * a.h;
        });
        return list;
    }

    function nearestIn(list, hz) {
        let best = 0;
        let bestDiff = 1e9;
        for (let i = 0; i < list.length; i++) {
            const d = Math.abs(list[i] - hz);
            if (d < bestDiff) {
                bestDiff = d;
                best = i;
            }
        }
        return best;
    }

    function syncToCurrent() {
        const mon = selMon;
        if (!mon)
            return;
        const resos = resolutionsFor(mon);
        let ri = 0;
        for (let i = 0; i < resos.length; i++) {
            if (resos[i].w === mon.width && resos[i].h === mon.height) {
                ri = i;
                break;
            }
        }
        resIndex = ri;
        rateIndex = nearestIn(resos.length > 0 ? resos[ri].rates : [], mon.refresh);
        pickScale = mon.scale;
        pendingMain = false;
        pendingMove = null;
    }

    function pickRes(i) {
        resIndex = i;
        rateIndex = 0;
    }

    function placementXY(other, side, w, h) {
        const oW = Math.round(other.width / other.scale);
        const oH = Math.round(other.height / other.scale);
        if (side === "left")
            return { x: other.x - w, y: other.y };
        if (side === "above")
            return { x: other.x, y: other.y - h };
        if (side === "below")
            return { x: other.x, y: other.y + oH };
        return { x: other.x + oW, y: other.y };
    }

    function pendingXY(mon) {
        if (!pendingMove || pendingMove.name !== mon.name || !pickedRes)
            return null;
        const other = otherMonitor(mon.name);
        if (!other)
            return null;
        return placementXY(other, pendingMove.side, Math.round(pickedRes.w / pickScale), Math.round(pickedRes.h / pickScale));
    }

    /** A dropped tile snaps to the side of the other screen its centre landed on; dropping it back home clears the move. */
    function dropTile(name, cx, cy) {
        const mon = monitorByName(name);
        const other = otherMonitor(name);
        if (!mon || !other)
            return;
        const oT = mapLayout.tiles.find(t => t.name !== name);
        if (!oT)
            return;
        const nx = (cx - (oT.x + oT.w / 2)) / oT.w;
        const ny = (cy - (oT.y + oT.h / 2)) / oT.h;
        const side = Math.abs(nx) >= Math.abs(ny) ? (nx < 0 ? "left" : "right") : (ny < 0 ? "above" : "below");
        const isSel = name === selName && pickedRes;
        const w = isSel ? Math.round(pickedRes.w / pickScale) : Math.round(mon.width / mon.scale);
        const h = isSel ? Math.round(pickedRes.h / pickScale) : Math.round(mon.height / mon.scale);
        const p = placementXY(other, side, w, h);
        if (name !== selName)
            selName = name;
        pendingMove = p.x === mon.x && p.y === mon.y ? null : { name: name, side: side };
    }

    /** Tile rects for the map; selection stays out of them so a click never rebuilds the Repeater mid-press. */
    readonly property var mapLayout: {
        const mons = monitors;
        const W = mapArea.width - 2 * mapArea.pad;
        const H = mapArea.maxH;
        if (mons.length === 0 || W <= 0)
            return { h: 0, tiles: [] };
        const rects = [];
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const r = { name: m.name, hz: m.refresh, mode: m.width + " × " + m.height, x: m.x, y: m.y, w: Math.round(m.width / m.scale), h: Math.round(m.height / m.scale) };
            if (m.name === selName && pickedRes && !locked) {
                const p = pendingXY(m);
                if (p) {
                    r.x = p.x;
                    r.y = p.y;
                }
                r.w = Math.round(pickedRes.w / pickScale);
                r.h = Math.round(pickedRes.h / pickScale);
                r.mode = pickedRes.w + " × " + pickedRes.h;
                r.hz = pickedHz;
            }
            rects.push(r);
            minX = Math.min(minX, r.x);
            minY = Math.min(minY, r.y);
            maxX = Math.max(maxX, r.x + r.w);
            maxY = Math.max(maxY, r.y + r.h);
        }
        const k = Math.min(W / (maxX - minX), H / (maxY - minY));
        const ox = mapArea.pad + (W - (maxX - minX) * k) / 2;
        return {
            h: (maxY - minY) * k,
            tiles: rects.map(t => ({ name: t.name, hz: t.hz, mode: t.mode, x: ox + (t.x - minX) * k, y: (t.y - minY) * k, w: t.w * k, h: t.h * k }))
        };
    }

    /** monitors.lua stays in memory after the first read, so back-to-back rewrites never see a stale copy. */
    function luaNow() {
        if (!luaRead) {
            luaText = monitorsFile.text();
            luaRead = true;
        }
        return luaText;
    }

    /** The main screen is whichever one the workspace-1 rule loop points at. */
    function mainFromLua(text) {
        const re = /for\s+i\s*=\s*(\d+)\s*,\s*(\d+)\s+do\s*\n\s*hl\.workspace_rule\(\{[^}]*monitor\s*=\s*"([^"]+)"/g;
        let m;
        while ((m = re.exec(text)) !== null)
            if (parseInt(m[1], 10) <= 1 && parseInt(m[2], 10) >= 1)
                return m[3];
        return "";
    }

    function moveWorkspaces(range, monitor) {
        for (let i = range[0]; i <= range[1]; i++)
            Hyprland.dispatch("hl.dsp.workspace.move({ workspace = " + i + ", monitor = '" + monitor + "' })");
    }

    function applyMainSwap(name) {
        const other = otherMonitor(name);
        pendingMain = false;
        if (!other) {
            note = "Main monitor needs two connected screens.";
            return;
        }
        const r = Mon.setWorkspaceLoops(luaNow(), name, other.name);
        if (!r.ok) {
            note = "Could not rewrite the workspace rules in monitors.lua.";
            return;
        }
        luaText = r.text;
        writer.put(r.text);
        mainName = mainFromLua(r.text);
        xrandrProc.out = name;
        xrandrProc.running = true;
        moveWorkspaces(r.mainRange, name);
        moveWorkspaces(r.otherRange, other.name);
        if (!dirty)
            note = "Saved. " + name + " is the main monitor now.";
    }

    /** A main swap saves at once; mode, scale and position go to the helper and its 12 s watchdog. */
    function apply() {
        const mon = selMon;
        if (!mon || locked)
            return;
        if (pendingMain && !selIsMain)
            applyMainSwap(mon.name);
        if (!dirty)
            return;
        const p = pendingXY(mon);
        applyProc.out = mon.name;
        applyProc.mode = pickedRes.w + "x" + pickedRes.h + "@" + pickedHz;
        applyProc.position = p ? p.x + "x" + p.y : mon.x + "x" + mon.y;
        applyProc.scale = pickScale;
        pendingOut = mon.name;
        note = "";
        applyProc.running = true;
    }

    function keep() {
        if (!locked)
            return;
        keepProc.out = pendingOut;
        keepProc.running = true;
        const r = Mon.setMonitor(luaNow(), applyProc.out, applyProc.mode, applyProc.position, applyProc.scale);
        cancelCountdown();
        if (!r.ok) {
            note = "Live for now, but monitors.lua was not written: " + r.error;
            return;
        }
        luaText = r.text;
        writer.put(r.text);
        quietRead = true;
        readProc.running = true;
        note = "Saved. " + applyProc.out + " runs at " + applyProc.mode.replace("x", " × ").replace("@", " · ") + " Hz, scale " + Math.round(applyProc.scale * 100) + "%.";
        App.toast("Display kept");
    }

    function revert(why) {
        if (!locked)
            return;
        revertProc.out = pendingOut;
        revertProc.running = true;
        cancelCountdown();
        note = why || "Reverted to the previous mode.";
    }

    function cancelCountdown() {
        countTimer.stop();
        countdown = 0;
        pendingOut = "";
    }

    Process {
        id: readProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.monitors = Mon.parse(this.text);
                page.mainName = page.mainFromLua(page.luaNow());
                if (!page.monitorByName(page.selName)) {
                    const main = page.monitorByName(page.mainName);
                    page.selName = main ? main.name : (page.monitors.length > 0 ? page.monitors[0].name : "");
                } else if (page.selMon) {
                    page.syncToCurrent();
                }
                page.quietRead = false;
                page.loaded = true;
            }
        }
    }

    Process {
        id: applyProc
        property string out: ""
        property string mode: ""
        property string position: ""
        property real scale: 1
        command: ["sh", "-c", "sh \"$1\" apply \"$2\" \"$3\" \"$4\" \"$5\"", "sh", page.helper, out, mode, position, String(scale)]
        onExited: (code) => {
            if (code === 0) {
                page.countdown = 12;
                countTimer.start();
            } else {
                page.pendingOut = "";
                page.note = "Apply failed. The current mode could not be saved first.";
            }
        }
    }

    Process {
        id: keepProc
        property string out: ""
        command: ["sh", "-c", "sh \"$1\" keep \"$2\"", "sh", page.helper, out]
    }

    Process {
        id: revertProc
        property string out: ""
        command: ["sh", "-c", "sh \"$1\" revert \"$2\"", "sh", page.helper, out]
        onExited: {
            page.quietRead = true;
            readProc.running = true;
        }
    }

    Process {
        id: xrandrProc
        property string out: ""
        command: ["xrandr", "--output", out, "--primary"]
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown -= 1;
            if (page.countdown <= 0)
                page.revert("Reverted. The change was not kept in time.");
        }
    }

    FileView {
        id: monitorsFile
        path: page.monitorsPath
        blockLoading: true
        printErrors: false
    }

    Writer {
        id: writer
        path: page.monitorsPath
        onFailed: page.note = "The mode is live, but writing monitors.lua failed."
    }

    /** Atomic writer that keeps one write in flight, so a quick second edit can never land before the first. */
    component Writer: FileView {
        property string queued: ""
        property bool busy: false
        property bool more: false
        signal written()
        signal failed()
        preload: false
        atomicWrites: true
        printErrors: false
        function put(t) {
            if (busy) {
                queued = t;
                more = true;
                return;
            }
            busy = true;
            setText(t);
        }
        function settle() {
            busy = false;
            if (more) {
                more = false;
                put(queued);
            } else {
                written();
            }
        }
        onSaved: Qt.callLater(settle)
        onSaveFailed: {
            failed();
            Qt.callLater(settle);
        }
    }

    AppGroup {
        title: "Monitors"
        hint: "Undo does not cover this page; an unkept change reverts on its own"

        AppRow {
            label: "Arrangement"
            sub: page.monitors.length > 1 ? "Drag a screen to move it. It snaps to a side of the other one. Click one to edit it below"
                : "Click the screen to edit it below"
            key: "display.map"
            block: true

            Rectangle {
                id: mapArea
                readonly property real pad: 18 * page.s
                readonly property real maxH: 150 * page.s
                width: parent.width
                height: (page.loaded ? Math.max(60 * page.s, page.mapLayout.h) : 60 * page.s) + 2 * pad
                radius: 12 * page.s
                color: Theme.frameBg
                border.width: 1
                border.color: Theme.hairSoft
                Behavior on height { enabled: !Motion.calm; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    visible: page.loaded && page.monitors.length === 0
                    text: "No screens reported by Hyprland"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12 * page.s
                }

                Repeater {
                    model: page.mapLayout.tiles

                    Rectangle {
                        id: tile
                        required property var modelData

                        readonly property bool sel: modelData.name === page.selName
                        readonly property bool isMain: modelData.name === page.mainName
                        readonly property bool moved: page.pendingMove !== null && page.pendingMove.name === modelData.name
                        property real dx: 0
                        property real dy: 0

                        x: modelData.x + 2 * page.s + dx
                        y: mapArea.pad + modelData.y + 2 * page.s + dy
                        width: Math.max(4, modelData.w - 4 * page.s)
                        height: Math.max(4, modelData.h - 4 * page.s)
                        z: tileArea.pressed ? 10 : (sel ? 5 : 0)
                        radius: 9 * page.s
                        color: sel ? Qt.alpha(Theme.onGlow, 0.12) : (tileArea.containsMouse ? Theme.cardTop : Theme.tileBg)
                        border.width: sel ? Math.max(1, 1.5 * page.s) : 1
                        border.color: moved ? Theme.vermLit : (sel ? Qt.alpha(Theme.vermLit, 0.8) : Theme.hair)
                        scale: tileArea.pressed && !Motion.calm ? 0.98 : 1

                        Behavior on x { enabled: !tileArea.pressed && !Motion.calm; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: !tileArea.pressed && !Motion.calm; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 12 * page.s
                            spacing: 3 * page.s

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.name
                                color: Theme.cream
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 12.5 * page.s
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                visible: tile.height > 54 * page.s
                                text: tile.modelData.mode + " · " + tile.modelData.hz + " Hz"
                                color: Theme.textFaint
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 11 * page.s
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                visible: tile.isMain
                                text: "Main"
                                color: Theme.vermLit
                                font.family: Theme.font
                                font.pixelSize: 11 * page.s
                                font.weight: Font.Medium
                            }
                        }

                        /** Drag deltas ride on the layout position, so the snap animation plays when they reset on release. */
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            enabled: !page.locked
                            cursorShape: pressed ? Qt.ClosedHandCursor : (page.monitors.length >= 2 ? Qt.OpenHandCursor : Qt.PointingHandCursor)
                            property real sx: 0
                            property real sy: 0
                            onPressed: (mouse) => {
                                page.selName = tile.modelData.name;
                                sx = mouse.x;
                                sy = mouse.y;
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed || page.monitors.length < 2)
                                    return;
                                tile.dx += mouse.x - sx;
                                tile.dy += mouse.y - sy;
                            }
                            onReleased: {
                                if (Math.abs(tile.dx) + Math.abs(tile.dy) > 4 * page.s)
                                    page.dropTile(tile.modelData.name, tile.x + tile.width / 2, tile.y - mapArea.pad + tile.height / 2);
                                tile.dx = 0;
                                tile.dy = 0;
                            }
                            onCanceled: {
                                tile.dx = 0;
                                tile.dy = 0;
                            }
                        }
                    }
                }
            }
        }
    }

    AppGroup {
        title: page.selMon ? page.selMon.name + (page.selIsMain ? " · main monitor" : "") : "Selected monitor"
        visible: page.selMon !== null

        AppRow {
            label: "Monitor"
            sub: "The screen the settings below change"
            key: "display.monitor"
            visible: page.monitors.length > 1
            enabled: !page.locked
            opacity: enabled ? 1 : 0.5
            AppSeg {
                small: true
                options: page.monitors.map(m => m.name)
                value: page.selName
                onPicked: (v) => page.selName = v
            }
        }
        AppRow {
            label: "Resolution"
            sub: page.nativeRes ? "The screen's own is " + page.nativeRes.w + " × " + page.nativeRes.h : ""
            key: "display.resolution"
            enabled: !page.locked
            opacity: enabled ? 1 : 0.5
            AppSelect {
                minWidth: 150
                options: page.resolutions.map((r, i) => ({ label: r.w + " × " + r.h, value: i }))
                value: Math.min(page.resIndex, Math.max(0, page.resolutions.length - 1))
                onPicked: (v) => page.pickRes(v)
            }
        }
        AppRow {
            label: "Refresh rate"
            sub: "Higher is smoother"
            key: "display.refresh"
            enabled: !page.locked
            opacity: enabled ? 1 : 0.5
            AppSelect {
                minWidth: 150
                options: page.rates.map((hz, i) => ({ label: hz + " Hz", value: i }))
                value: Math.min(page.rateIndex, Math.max(0, page.rates.length - 1))
                onPicked: (v) => page.rateIndex = v
            }
        }
        AppRow {
            label: "Scale"
            sub: page.pickedRes ? "Things look as big as on a " + Math.round(page.pickedRes.w / page.pickScale) + " × " + Math.round(page.pickedRes.h / page.pickScale) + " screen" : ""
            key: "display.scale"
            enabled: !page.locked
            opacity: enabled ? 1 : 0.5
            AppSeg {
                small: true
                options: page.scaleOptions
                value: page.pickScale
                onPicked: (v) => page.pickScale = v
            }
        }
        AppRow {
            label: "Main monitor"
            sub: page.selIsMain ? "Workspace 1 and its neighbours live here" : "Moves workspace 1 and its neighbours here"
            key: "display.main"
            enabled: !page.locked && !page.selIsMain && page.monitors.length > 1
            opacity: page.locked || page.monitors.length < 2 ? 0.5 : 1
            clickable: enabled
            onClicked: page.pendingMain = !page.pendingMain
            AppToggle {
                checked: page.selIsMain || page.pendingMain
                onToggled: (on) => page.pendingMain = on
            }
        }

        AppRow {
            key: "display.apply"
            block: true

            Column {
                width: parent.width
                spacing: 10 * page.s

                Item {
                    width: parent.width
                    height: Math.max(applyText.implicitHeight, 30 * page.s)

                    Column {
                        id: applyText
                        anchors.left: parent.left
                        anchors.right: buttons.left
                        anchors.rightMargin: 16 * page.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * page.s

                        Text {
                            width: parent.width
                            text: page.locked ? "Keep these settings?"
                                : (page.applyReady ? "Changed: " + page.changes.join(", ") : "Everything shown is live")
                            color: Theme.cream
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 13 * page.s
                            font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            text: page.locked ? "Reverting in " + page.countdown + " s"
                                : (page.dirty ? "Reverts after 12 s unless you keep it" : "Pick a mode, scale or place, then apply")
                            color: Theme.textFaint
                            wrapMode: Text.WordWrap
                            font.family: Theme.font
                            font.pixelSize: 11.5 * page.s
                            font.features: { "tnum": 1 }
                        }
                    }

                    Row {
                        id: buttons
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * page.s

                        AppButton {
                            visible: page.locked
                            text: "Revert"
                            onClicked: page.revert()
                        }
                        AppButton {
                            visible: page.locked
                            kind: "primary"
                            text: "Keep"
                            onClicked: page.keep()
                        }
                        AppButton {
                            visible: !page.locked
                            kind: page.applyReady ? "primary" : "secondary"
                            enabled: page.applyReady && page.pendingOut.length === 0 && !applyProc.running
                            text: "Apply"
                            onClicked: page.apply()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 3 * page.s
                    radius: height / 2
                    visible: page.locked
                    color: Theme.hair

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * page.countdown / 12
                        color: Theme.vermLit
                        Behavior on width { enabled: !Motion.calm; NumberAnimation { duration: 1000 } }
                    }
                }

                Text {
                    width: parent.width
                    visible: page.note.length > 0 && !page.locked
                    text: page.note
                    color: Theme.textFaint
                    wrapMode: Text.WordWrap
                    font.family: Theme.font
                    font.pixelSize: 11.5 * page.s
                }
            }
        }
    }
}
