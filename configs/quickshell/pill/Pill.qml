pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * The pill body: one shape that morphs between its own faces and every surface, picked by `mode`.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var monitor: null
    property var barWindow
    property string surface: ""

    /**
     * Toast swipe offset and fade, written by Toast while dragging and applied by the host in shell.qml.
     */
    property real swipeX: 0
    property real swipeY: 0
    property real swipeFade: 1
    Behavior on swipeFade {
        enabled: !toastLoader.active
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
    onToastActiveChanged: if (!toastActive) { swipeX = 0; swipeY = 0; swipeFade = 1; }

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool hasMedia: Players.list.length > 0
    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false

    /**
     * Hyprland hands a freshly mapped layer the pointer, which would latch hover on boot (issue #20).
     */
    property bool bootSettled: false

    Timer {
        interval: 3000
        running: true
        onTriggered: pill.bootSettled = true
    }

    readonly property bool expanded: surfaceOpen || held || hoverLatch

    /**
     * The special workspace on this monitor, named in place of the clock; empty normally.
     */
    readonly property string specialView: {
        const o = monitor ? monitor.lastIpcObject : null;
        const sw = (o && o.specialWorkspace) ? o.specialWorkspace.name : "";
        if (!sw || sw.indexOf("special:") !== 0)
            return "";
        const id = sw.slice("special:".length);
        const named = Spaces.list.find(sp => sp && sp.id === id);
        if (named)
            return named.name;
        return ({ minimized: "Minimized", private: "Private", stash: "Stash" })[id] || id.charAt(0).toUpperCase() + id.slice(1);
    }
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    /**
     * Quick record belongs to the monitor its keybind targeted and yields to the recorder surface.
     */
    readonly property bool quickHere: ScreenRec.quickMon === screenName
    readonly property bool quickChoosing: quickHere && ScreenRec.quickChoosing && !surfaceOpen
    readonly property bool quickCounting: quickHere && ScreenRec.counting && surface !== "recorder"

    PillMetrics {
        id: metrics
        s: pill.s
    }

    readonly property real restW: metrics.restW
    readonly property real restH: metrics.restH
    readonly property real hoverPad: metrics.hoverPad
    readonly property real hoverW: metrics.hoverWidth(hoverFace.rowWidth)
    readonly property real hoverH: metrics.hoverH
    readonly property real toastW: 342 * s
    readonly property real gameH: 34 * s
    readonly property real gameW: barWindow ? barWindow.width : 1920
    readonly property real restCorner: metrics.restCorner
    readonly property real openCorner: metrics.openCorner

    /**
     * Surface registry with each file, size, hover preload and whether Ame stays out.
     */
    readonly property var surfaceDefs: ({
        calendar:   { file: "Calendar.qml", size: it => Qt.size((it.implicitWidth > 0 ? it.implicitWidth : 282 * s) + 36 * s, it.implicitHeight + 32 * s) },
        launcher:   { file: "Launcher.qml", size: () => Qt.size(360 * s, 332 * s) },
        clipboard:  { file: "Clipboard.qml", size: () => Qt.size(360 * s, 332 * s) },
        wallpaper:  { file: "Wallpaper.qml", size: () => Qt.size(720 * s, 172 * s), noAme: true },
        power:      { file: "Power.qml", size: () => Qt.size(330 * s, 150 * s) },
        media:      { file: "Media.qml", size: () => Qt.size((Players.pickable.length > 1 ? 460 : 390) * s, 150 * s), warm: true },
        mixer:      { file: "Mixer.qml", size: it => Qt.size(93 * Math.max(4, it.faderCount) * s, 214 * s), warm: true },
        link:       { file: "Link.qml", size: it => Qt.size(it.desiredW, it.implicitHeight + (it.mTop + it.mBottom) * s), warm: true },
        wifi:       { file: "WifiSurface.qml", w: 272 },
        sound:      { file: "SoundSurface.qml", w: 400, extra: 6 },
        bt:         { file: "BtSurface.qml", w: 286 },
        battery:    { file: "BatterySurface.qml", w: 316, extra: -6 },
        recorder:   { file: "Recorder.qml", w: 384, extra: 7 },
        sysmon:     { file: "SysmonSurface.qml", w: 392, extra: 3 }
    })
    readonly property var surfaceNames: Object.keys(surfaceDefs)

    /**
     * The write comes before any read so the calling binding never depends on the loader it flips, and forcing it synchronous completes a warm preload in flight.
     */
    function surfaceItem(name) {
        const ld = slots.itemAt(surfaceNames.indexOf(name));
        if (!ld)
            return null;
        ld.asynchronous = false;
        ld.active = true;
        return ld.item;
    }

    function surfaceSize(name) {
        const it = surfaceItem(name);
        return it ? sizeFor(surfaceDefs[name], it) : Qt.size(restW, restH);
    }

    function sizeFor(d, it) {
        if (d.size)
            return d.size(it);
        return Qt.size(d.w * s, it.implicitHeight + (it.mTop + it.mBottom + (d.extra || 0)) * s);
    }

    readonly property Item current: (surfaceOpen && surfaceDefs[surface] !== undefined) ? surfaceItem(surface) : null

    readonly property string mode: dropFace.active ? "dragOver"
        : current ? surface
        : Flags.gameMode ? "game"
        : quickChoosing ? "quickChoose"
        : quickCounting ? "quickCount"
        : osdActive && !held ? "osd"
        : toastActive && !held ? "toast"
        : expanded ? "hover" : "rest"

    signal requestSurface(string name)
    signal requestClose()

    /**
     * One level back: a nested form closes, anything else dismisses.
     */
    function surfaceBack() {
        if (current && current.back())
            return;
        requestClose();
    }

    /**
     * Tells the arriving surface whether it swaps in for another one, so it waits until the old one has mostly faded.
     */
    property string lastSurface: ""
    onSurfaceChanged: {
        const prev = lastSurface;
        lastSurface = surface;
        const d = surfaceDefs;
        const old = d[prev] ? slots.itemAt(surfaceNames.indexOf(prev)).item : null;
        if (old)
            old.slide = 0;
        const now = d[surface] ? surfaceItem(surface) : null;
        if (now)
            now.arrive(0, old !== null);
    }

    onSurfaceOpenChanged: if (surfaceOpen) {
        unloadIdle.stop();
        pinned = false;
        if (quickHere && ScreenRec.quickChoosing) {
            ScreenRec.quickChoosing = false;
            ScreenRec.quickScreenChoosing = false;
        }
    } else {
        unloadIdle.restart();
    }

    /**
     * Closed surfaces unload after two idle minutes; the warm ones and a busy surface stay.
     */
    Timer {
        id: unloadIdle
        interval: 120000
        onTriggered: {
            for (let i = 0; i < slots.count; i++) {
                const ld = slots.itemAt(i);
                if (ld.active && !ld.def.warm && !(ld.item && ld.item.busy === true))
                    ld.active = false;
            }
        }
    }

    /**
     * The surfaces that must look right on their first open load in the background on the first hover.
     */
    function warm() {
        for (let i = 0; i < slots.count; i++) {
            const ld = slots.itemAt(i);
            if (ld.def.warm && !ld.active) {
                ld.asynchronous = true;
                ld.active = true;
            }
        }
    }

    readonly property real targetRadius: (mode === "rest" || mode === "hover" || mode === "game") ? restCorner : openCorner
    readonly property real morphRadius: springR.value

    /**
     * Target size of the pill's own faces; surfaces size themselves through surfaceDefs.
     */
    readonly property var modeSize: ({
        osd:   () => Qt.size(osd.desiredW, osd.desiredH),
        toast: () => Qt.size(toastW, toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH),
        hover: () => Qt.size(hoverW, hoverH),
        quickChoose: () => Qt.size(344 * s, 76 * s),
        quickCount:  () => Qt.size(150 * s, 64 * s),
        dragOver:    () => Qt.size(300 * s, 126 * s),
        game:        () => Qt.size(gameW, gameH)
    })

    readonly property size targetSize: {
        if (current)
            return surfaceSize(surface);
        const f = modeSize[mode];
        if (f)
            return f();
        return Qt.size(metrics.restWidth(restFace.rowWidth), restH);
    }
    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: springW.value
    height: springH.value

    /**
     * Shape springs: growing overshoots a hair, shrinking and the rest-hover hop settle without; "snappy" is quicker and firmer.
     */
    readonly property var feel: Flags.springFeel === "snappy"
        ? ({ hop: 0.19, shrink: 0.25, grow: 0.29, growDamping: 0.9 })
        : ({ hop: 0.26, shrink: 0.34, grow: 0.4, growDamping: 0.82 })

    Spring {
        id: springW
        target: pill.targetW
        response: pill.hoverHop ? pill.feel.hop : pill.feel.shrink
        growResponse: pill.hoverHop ? pill.feel.hop : pill.feel.grow
        growDamping: pill.hoverHop ? 1 : pill.feel.growDamping
    }
    Spring {
        id: springH
        target: pill.targetH
        response: springW.response
        growResponse: springW.growResponse
        growDamping: springW.growDamping
    }
    Spring {
        id: springR
        target: pill.targetRadius
        response: springW.response
    }
    Component.onCompleted: {
        springW.snap(targetW);
        springH.snap(targetH);
        springR.snap(targetRadius);
        ameBox = targetSize;
    }

    /**
     * How settled the pill is into its target size, 0 far away to 1 arrived; content fades key off it.
     */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    /**
     * Ame waits for the hover morph to arrive before aiming at icons; latched so small width changes don't flicker it.
     */
    property bool hoverSoulGate: false
    readonly property bool hoverArrived: mode === "hover" && morphCloseness > 0.55
    onHoverArrivedChanged: if (hoverArrived) {
        hoverSoulGate = true;
        Qt.callLater(warm);
    }

    /**
     * Rest and hover sit close, so that hop takes the shorter glide instead of the full morph.
     */
    property string lastMode: "rest"
    property bool hoverHop: false

    onModeChanged: {
        hoverHop = (mode === "hover" || mode === "rest") && (lastMode === "hover" || lastMode === "rest");
        lastMode = mode;
        if (mode !== "hover") {
            hoverSoulGate = false;
            soulItem = null;
            soulWsIndex = -1;
        }
    }
    onHoverSoulGateChanged: if (hoverSoulGate) kanjiFlashAnim.restart()

    property Item soulItem: null
    property int soulWsIndex: -1

    property real kanjiFlash: 0

    SequentialAnimation {
        id: kanjiFlashAnim
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: bud
        readonly property bool shown: pill.mode === "hover" && pill.hasMedia
        property real budR: (budArea.containsMouse ? 15 : 12) * pill.s
        width: budR * 2
        height: budR * 2
        radius: budR
        x: pill.width - budR
        anchors.verticalCenter: parent.verticalCenter
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        border.width: Flags.pillBorder ? 1 : 0
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }
        Behavior on budR { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

        Canvas {
            id: budBead
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3 * pill.s
            width: 18 * pill.s
            height: 18 * pill.s
            readonly property var inks: [Theme.flameInk, Theme.vermLit, Theme.verm, Theme.flameEmber]
            onInksChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const R = (budArea.containsMouse ? 5.2 : 4) * pill.s;
                const hg = ctx.createRadialGradient(c - R * 0.32, c - R * 0.38, 0, c, c, R);
                hg.addColorStop(0, inks[0]);
                hg.addColorStop(0.55, inks[1]);
                hg.addColorStop(0.92, inks[2]);
                hg.addColorStop(1, inks[3]);
                ctx.beginPath();
                ctx.arc(c, c, R, 0, 7);
                ctx.fillStyle = hg;
                ctx.fill();
                ctx.beginPath();
                ctx.ellipse(c - R * 0.62, c - R * 0.66, R * 0.6, R * 0.36);
                ctx.fillStyle = "rgba(255,246,240,0.6)";
                ctx.fill();
            }
        }

        MouseArea {
            id: budArea
            anchors.fill: parent
            enabled: bud.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.requestSurface("media")
            onContainsMouseChanged: budBead.requestPaint()
        }
    }

    /**
     * Corner flatness rides the morph curve, so docking into the game bar squares the corners smoothly.
     */
    property real gameFlat: mode === "game" ? 1 : 0
    Behavior on gameFlat { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    PillBody {
        id: body
        anchors.fill: parent
        s: pill.s
        radius: pill.morphRadius
        flat: pill.gameFlat
    }

    /**
     * The open surface Ame docks to, or null so Ame falls back to the hover and rest anchors.
     */
    readonly property var ameSurface: (current && !surfaceDefs[surface].noAme) ? current : null

    /**
     * Ame's canvas covers both ends of the running morph plus room for the glow and the arc, and only resizes once it settles.
     */
    property size ameBox: Qt.size(0, 0)
    readonly property real ameMargin: 28 * s
    onTargetSizeChanged: ameBox = Qt.size(Math.max(targetSize.width, width), Math.max(targetSize.height, height))
    readonly property bool settledShape: !springW.running && !springH.running
    onSettledShapeChanged: {
        if (!settledShape)
            return;
        ameBox = targetSize;
        writeRest();
    }
    onRestCornerChanged: Qt.callLater(writeRest)

    function writeRest() {
        if (mode !== "rest" || !settledShape)
            return;
        const rest = (width / s).toFixed(1) + " " + (height / s).toFixed(1) + " " + (restCorner / s).toFixed(1);
        if (rest !== restFile.written) {
            restFile.written = rest;
            restFile.setText(rest);
        }
    }

    /**
     * The lock screen grows its reveal out of this monitor's resting pill: "width height corner" in unscaled px.
     */
    FileView {
        id: restFile
        property string written: ""
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-pill-" + pill.screenName
        printErrors: false
        blockLoading: false
    }

    Ame {
        id: ame
        anchors.top: parent.top
        anchors.topMargin: -pill.ameMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: pill.ameBox.width + 2 * pill.ameMargin
        height: pill.ameBox.height + 2 * pill.ameMargin
        s: pill.s

        /**
         * The canvas stays centred on the pill, so a new width moves its origin; shifting the bead keeps it on the same screen spot.
         */
        property real lastW: 0
        onWidthChanged: {
            if (lastW > 0)
                shift((width - lastW) / 2);
            lastW = width;
        }

        heat: (pill.surface === "power" && pill.current) ? (pill.current.holdProgress || 0) : 0
        wake: Qt.point(restFace.wakePoint.x - x, restFace.wakePoint.y - y)
        wickDir: pill.surface === "power" ? 1 : -1
        form: pill.ameSurface ? pill.ameSurface.ameForm
            : (pill.mode === "hover" && pill.hoverSoulGate ? "soul" : "off")
        point: pill.ameSurface
            ? Qt.point(pill.ameSurface.parent.x + pill.ameSurface.x + pill.ameSurface.amePoint.x - x,
                       pill.ameSurface.parent.y + pill.ameSurface.y + pill.ameSurface.amePoint.y - y)
            : (pill.mode === "hover" ? Qt.point(hoverFace.soulPoint.x - x, hoverFace.soulPoint.y - y)
                                      : Qt.point(restFace.wakePoint.x - x, restFace.wakePoint.y - y))
    }

    /**
     * Extra input width past the right edge while the media bud sticks out there.
     */
    readonly property real inputPadRight: bud.shown ? bud.budR + 2 * s : 0

    /**
     * "click" opens the hover state only on a click on free pill space; pointer entry alone never latches it.
     */
    readonly property bool clickMode: Flags.expandMode === "click"

    onHoveredChanged: {
        if (hovered) {
            graceTimer.stop();
            if (bootSettled && !clickMode) {
                if (Flags.openDelay > 0)
                    openTimer.restart();
                else
                    hoverLatch = true;
            }
        } else {
            openTimer.stop();
            graceTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: Math.max(0, Flags.openDelay)
        onTriggered: if (pill.hovered && !pill.clickMode) pill.hoverLatch = true
    }

    Timer {
        id: graceTimer
        interval: Math.max(16, Flags.closeDelay)
        onTriggered: {
            if (pill.morphCloseness < 0.95) {
                graceTimer.restart();
                return;
            }
            pill.hoverLatch = false;
        }
    }

    /**
     * Hover mode: a tap pins the open pill. Click mode: a tap opens it, the next one closes it.
     */
    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: {
            if (!pill.clickMode) {
                pill.pinned = !pill.pinned;
            } else if (pill.hoverLatch || pill.pinned) {
                pill.pinned = false;
                pill.hoverLatch = false;
            } else {
                pill.hoverLatch = true;
            }
        }
    }

    DropFace {
        id: dropFace
        host: pill
    }

    GameFace {
        host: pill
        osd: osd
    }

    RestFace {
        id: restFace
        host: pill
    }

    HoverFace {
        id: hoverFace
        host: pill
    }

    /**
     * Surfaces lay out at their final size and the growing shape reveals them, so text never re-wraps mid-morph.
     */
    Item {
        id: stage
        anchors.fill: parent
        clip: true

        Repeater {
            id: slots
            model: pill.surfaceNames

            Loader {
                id: slot
                required property string modelData
                readonly property var def: pill.surfaceDefs[modelData]
                readonly property size box: item ? pill.sizeFor(def, item) : Qt.size(0, 0)
                active: false
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: box.width
                height: box.height
                source: def.file

                onLoaded: {
                    item.s = Qt.binding(() => pill.s);
                    item.screenName = Qt.binding(() => pill.screenName);
                    item.morphCloseness = Qt.binding(() => pill.morphCloseness);
                    item.open = Qt.binding(() => pill.surface === slot.modelData);
                    item.requestClose.connect(pill.requestClose);
                    item.requestSurface.connect(pill.requestSurface);
                }
            }
        }
    }

    Face {
        host: pill
        mode: "osd"

        Osd {
            id: osd
            anchors.top: parent.top
            anchors.topMargin: 12 * pill.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: desiredW - 36 * pill.s
            height: desiredH - 24 * pill.s
            s: pill.s
            screenName: pill.screenName
            suppressed: pill.surfaceOpen || pill.held
            expanded: pill.expanded
        }
    }

    Face {
        id: toastFace
        host: pill
        mode: "toast"

        /**
         * The last card stays drawn while it fades out instead of vanishing with its notification.
         */
        property var lastNotif: null
        Connections {
            target: Notifs
            function onPopupsChanged() {
                if (Notifs.popups.length > 0)
                    toastFace.lastNotif = Notifs.popups[Notifs.popups.length - 1];
            }
        }

        Loader {
            id: toastLoader
            active: toastFace.lastNotif !== null && (pill.toastActive || toastFace.visible)
            anchors.top: parent.top
            anchors.topMargin: 12 * pill.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: pill.toastW - 32 * pill.s

            sourceComponent: Item {
                implicitHeight: toastContent.implicitHeight

                Toast {
                    id: toastContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    s: pill.s
                    live: pill.mode === "toast"
                    host: pill
                    notif: toastFace.lastNotif
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: Notifs.popups.length > 1
                    text: "+" + (Notifs.popups.length - 1)
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.label * pill.s
                    font.features: { "tnum": 1 }
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    QuickRecord {
        host: pill
    }
}
