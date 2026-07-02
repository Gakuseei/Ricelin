pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Hyprland
import "Singletons"

/**
 * The pill body. One element carries every state. Width/height driven by `state`
 * (rest, hover/pinned, mixer, calendar) with a no-overshoot easing so surfaces
 * grow out of the pill in place. Surfaces are stacked absolutely and cross-fade.
 *
 * Hover comes from a passive HoverHandler, pin from a passive TapHandler, so
 * neither swallows pointer events from the surfaces stacked above: workspace
 * dots, the clock target, tray icons and the mixer faders get their own clicks
 * and drags.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool powerOpen: surface === "power"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool batteryOpen: surface === "battery"
    readonly property bool settingsOpen: surface === "settings"
    readonly property bool keybindsOpen: surface === "keybinds"
    readonly property bool workspacesOpen: surface === "workspaces"
    readonly property bool stashOpen: surface === "stash"
    readonly property bool spaceappsOpen: surface === "spaceapps"
    readonly property bool recorderOpen: surface === "recorder"
    readonly property bool sysmonOpen: surface === "sysmon"
    readonly property bool appearanceOpen: surface === "appearance"
    readonly property bool updatesOpen: surface === "updates"
    readonly property bool displayOpen: surface === "display"
    readonly property bool inputOpen: surface === "input"
    readonly property bool lookOpen: surface === "look"
    readonly property bool idlelockOpen: surface === "idlelock"
    readonly property bool animationOpen: surface === "animation"
    readonly property bool fontpickerOpen: surface === "fontpicker"
    readonly property bool settingsLike: settingsOpen || appearanceOpen || updatesOpen
        || lookOpen || inputOpen || displayOpen || animationOpen || idlelockOpen || fontpickerOpen
    readonly property bool hasMedia: Players.list.length > 0

    /**
     * Subview the link surface should land on when next opened. The wifi glance
     * sets "wifi" to drill straight to the network list; the inbox glance and
     * toast set "main". Reset once the surface closes so IPC opens land on main.
     */
    property string linkInitialView: "main"

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0
    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false
    readonly property bool expanded: surfaceOpen || held || hoverLatch

    /**
     * True while the open surface is waiting on an external auth dialog (the
     * updater's pkexec password prompt). The shell drops its modal grab for this
     * so the polkit window underneath is clickable and typeable, instead of the
     * backdrop swallowing the reach for it and dismissing the whole pill.
     */
    readonly property bool authPending: updatesOpen && ldUpdates.item !== null && ldUpdates.item.applying

    /**
     * The special workspace shown on this pill's monitor, surfaced as a plain word
     * in place of the clock so it is obvious you are looking at the minimized stash
     * or the private space rather than your real desktop. Empty in the normal case.
     */
    readonly property string specialView: {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++) {
            if (ms[i] && ms[i].name === pill.screenName) {
                var o = ms[i].lastIpcObject;
                var sw = (o && o.specialWorkspace) ? o.specialWorkspace.name : "";
                if (sw === "special:minimized") return "Minimized";
                if (sw === "special:private") return "Private";
                if (sw === "special:stash") return "Stash";
                if (sw && sw.indexOf("special:") === 0) {
                    var id = sw.slice("special:".length);
                    var sl = Spaces.list;
                    for (var j = 0; j < sl.length; j++)
                        if (sl[j] && sl[j].id === id)
                            return sl[j].name;
                    return id.charAt(0).toUpperCase() + id.slice(1);
                }
                return "";
            }
        }
        return "";
    }
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    /**
     * Quick-record overlays belong only to the focused monitor the keybind
     * targeted, so a single chooser and a single countdown toast appear. The
     * standalone chooser is suppressed while the morphing recorder surface owns the
     * pill; the countdown toast yields to the surface too (the surface shows its
     * own in-bar countdown there).
     */
    readonly property bool quickHere: ScreenRec.quickMon === screenName
    readonly property bool quickChoosing: quickHere && ScreenRec.quickChoosing && !surfaceOpen
    readonly property bool quickCounting: quickHere && ScreenRec.counting && !recorderOpen

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverPad: 20 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 58 * s
    readonly property real mixerH: 214 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real wallpaperW: 720 * s
    readonly property real wallpaperH: 172 * s
    readonly property real powerW: 330 * s
    readonly property real powerH: 150 * s
    readonly property real mediaW: (Players.pickable.length > 1 ? 460 : 390) * s
    readonly property real mediaH: 150 * s
    readonly property real batteryW: 316 * s
    readonly property real settingsW: 392 * s
    readonly property real keybindsW: 460 * s
    readonly property real workspacesW: 392 * s
    readonly property real stashW: 392 * s
    readonly property real spaceappsW: 392 * s
    readonly property real recorderW: 384 * s
    readonly property real sysmonW: 392 * s
    readonly property real appearanceW: 392 * s
    readonly property real updatesW: 360 * s
    readonly property real displayW: 392 * s
    readonly property real inputW: 392 * s
    readonly property real lookW: 392 * s
    readonly property real idlelockW: 392 * s
    readonly property real animationW: 392 * s
    readonly property real fontpickerW: 360 * s
    readonly property real toastW: 342 * s
    readonly property real quickChooseW: 344 * s
    readonly property real quickChooseH: 76 * s
    readonly property real quickCountW: 150 * s
    readonly property real quickCountH: 64 * s
    readonly property real dragOverW: 300 * s
    readonly property real dragOverH: 126 * s
    readonly property real gameH: 34 * s
    readonly property real gameW: barWindow ? barWindow.width : 1920
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    /**
     * Latch-once lazy load. Every surface sleeps in an inactive Loader until its
     * first open; the size and ame thunks below resolve items through here. The
     * ordering is the trick: flip `active` before any read of the loader, so the
     * calling binding never has the loader registered as a dep when the flip
     * fires mid-evaluation (that read-then-write would be a binding loop). The
     * write is idempotent and the Loader loads synchronously, so a first open
     * reads the real implicitHeight in the same evaluation and the morph target
     * is exact. Nothing ever deactivates a loaded surface.
     */
    function surfaceItem(ld) {
        ld.active = true;
        return ld.item;
    }

    /**
     * Single source of truth for every morphing surface, keyed by its `surface`
     * string. Each entry owns the surface's target size (a thunk so the geometry
     * it reads registers as a live dep of targetSize) and a thunk resolving the
     * surface item Ame anchors to while it is open (null = Ame falls back to the
     * pill's own hover or wake anchor). `mode`, `targetSize` and `ameSurface` all
     * derive from this, so adding a surface is one entry here plus its Loader —
     * no parallel ternary chains to keep in lockstep.
     */
    readonly property var surfaces: ({
        calendar:  { size: () => { const it = surfaceItem(ldCalendar); return Qt.size((it.implicitWidth > 0 ? it.implicitWidth : 282 * s) + 36 * s, it.implicitHeight + 32 * s); }, ame: () => surfaceItem(ldCalendar) },
        launcher:  { size: () => { surfaceItem(ldLauncher); return Qt.size(launcherW, launcherH); }, ame: () => surfaceItem(ldLauncher) },
        clipboard: { size: () => { surfaceItem(ldClip); return Qt.size(clipboardW, clipboardH); }, ame: () => surfaceItem(ldClip) },
        wallpaper: { size: () => { surfaceItem(ldWall); return Qt.size(wallpaperW, wallpaperH); }, ame: () => null },
        power:     { size: () => { surfaceItem(ldPower); return Qt.size(powerW, powerH); }, ame: () => surfaceItem(ldPower) },
        media:     { size: () => { surfaceItem(ldMedia); return Qt.size(mediaW, mediaH); }, ame: () => surfaceItem(ldMedia) },
        mixer:     { size: () => Qt.size(93 * Math.max(4, surfaceItem(ldMixer).faderCount) * s, mixerH), ame: () => surfaceItem(ldMixer) },
        link:      { size: () => { const it = surfaceItem(ldLink); return Qt.size(it.desiredW, it.implicitHeight + 26 * s); }, ame: () => surfaceItem(ldLink) },
        battery:   { size: () => Qt.size(batteryW, surfaceItem(ldBattery).implicitHeight + 26 * s), ame: () => surfaceItem(ldBattery) },
        settings:  { size: () => Qt.size(settingsW, surfaceItem(ldSettings).implicitHeight + 29 * s), ame: () => surfaceItem(ldSettings) },
        keybinds:  { size: () => Qt.size(keybindsW, surfaceItem(ldKeybinds).implicitHeight + 29 * s), ame: () => surfaceItem(ldKeybinds) },
        workspaces: { size: () => Qt.size(workspacesW, surfaceItem(ldWorkspaces).implicitHeight + 29 * s), ame: () => surfaceItem(ldWorkspaces) },
        stash:     { size: () => Qt.size(stashW, surfaceItem(ldStash).implicitHeight + 29 * s), ame: () => surfaceItem(ldStash) },
        spaceapps: { size: () => Qt.size(spaceappsW, surfaceItem(ldSpaceapps).implicitHeight + 29 * s), ame: () => surfaceItem(ldSpaceapps) },
        recorder:  { size: () => Qt.size(recorderW, surfaceItem(ldRecorder).implicitHeight + 33 * s), ame: () => surfaceItem(ldRecorder) },
        sysmon:    { size: () => Qt.size(sysmonW, surfaceItem(ldSysmon).implicitHeight + 33 * s), ame: () => surfaceItem(ldSysmon) },
        appearance: { size: () => Qt.size(appearanceW, surfaceItem(ldAppearance).implicitHeight + 29 * s), ame: () => surfaceItem(ldAppearance) },
        updates:    { size: () => Qt.size(updatesW, surfaceItem(ldUpdates).implicitHeight + 29 * s), ame: () => surfaceItem(ldUpdates) },
        display:    { size: () => Qt.size(displayW, surfaceItem(ldDisplay).implicitHeight + 29 * s), ame: () => surfaceItem(ldDisplay) },
        input:      { size: () => Qt.size(inputW, surfaceItem(ldInput).implicitHeight + 29 * s), ame: () => surfaceItem(ldInput) },
        look:       { size: () => Qt.size(lookW, surfaceItem(ldLook).implicitHeight + 29 * s), ame: () => surfaceItem(ldLook) },
        idlelock:   { size: () => Qt.size(idlelockW, surfaceItem(ldIdlelock).implicitHeight + 29 * s), ame: () => surfaceItem(ldIdlelock) },
        animation:  { size: () => Qt.size(animationW, surfaceItem(ldAnimation).implicitHeight + 29 * s), ame: () => surfaceItem(ldAnimation) },
        fontpicker: { size: () => Qt.size(fontpickerW, surfaceItem(ldFontpicker).implicitHeight + 29 * s), ame: () => surfaceItem(ldFontpicker) }
    })

    readonly property string mode: dragActive ? "dragOver"
        : (surfaceOpen && surfaces[surface] !== undefined ? surface
        : (Flags.gameMode ? "game"
        : (quickChoosing ? "quickChoose"
        : (quickCounting ? "quickCount"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest")))))))

    /**
     * AppImage drag-install state, live only while a file hovers the resting pill.
     * `dragStage` walks hover -> installing -> done, or bad for a non-AppImage drop.
     */
    property bool dragActive: false
    property string dragName: ""
    property string dragStage: ""

    signal requestSurface(string name)
    signal requestClose()

    /**
     * Forward an arrow-key nudge to the open mixer's targeted fader. Returns true
     * when the mixer is open and a fader consumed the step.
     */
    function mixerStep(deltaPct) {
        return (pill.mixerOpen && ldMixer.item) ? ldMixer.item.stepFocused(deltaPct) : false;
    }

    /**
     * Move the open mixer's keyboard focus across the fader row; `dir` is +1
     * (right) or -1 (left). No-op unless the mixer is open.
     */
    function mixerFocusMove(dir) {
        if (pill.mixerOpen && ldMixer.item)
            ldMixer.item.moveFocus(dir);
    }

    /**
     * Forward an arrow-key nudge to the open recorder's focused audio fader.
     * Returns true when the recorder is open and a revealed fader consumed it.
     */
    function recorderStep(deltaPct) {
        return (pill.recorderOpen && ldRecorder.item) ? ldRecorder.item.stepFocused(deltaPct) : false;
    }

    /**
     * Resolve which settings-family surface owns keyboard row navigation right
     * now: the category index or one of its morphing sub-surfaces. Returns null
     * when none of them is open.
     */
    function rowNavSurface() {
        if (pill.settingsOpen)
            return ldSettings.item;
        if (pill.appearanceOpen)
            return ldAppearance.item;
        if (pill.lookOpen)
            return ldLook.item;
        if (pill.inputOpen)
            return ldInput.item;
        if (pill.displayOpen)
            return ldDisplay.item;
        if (pill.animationOpen)
            return ldAnimation.item;
        if (pill.idlelockOpen)
            return ldIdlelock.item;
        if (pill.fontpickerOpen)
            return ldFontpicker.item;
        return null;
    }

    /**
     * Move the focused settings row by `dir` (+1 down, -1 up), carrying the soul
     * seam. Returns true when a settings-family surface is open and consumed it.
     */
    function settingsMove(dir) {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbMove(dir);
        return true;
    }

    /**
     * Step the focused settings row's control: a segmented choice cycles by
     * `dir`, a toggle is set on (dir > 0) or off. Returns true when consumed.
     */
    function settingsAdjust(dir) {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbAdjust(dir);
        return true;
    }

    /**
     * Activate the focused settings row: a toggle flips, a nav row opens its
     * sub-surface. Returns true when a settings-family surface is open.
     */
    function settingsActivate() {
        var nav = pill.rowNavSurface();
        if (!nav)
            return false;
        nav.kbActivate();
        return true;
    }

    /**
     * Slide the open keybinds list's focused row by `dir` (+1 down, -1 up),
     * carrying the soul seam. No-op unless the keybinds surface is open.
     */
    function keybindsMove(dir) {
        if (pill.keybindsOpen && ldKeybinds.item)
            ldKeybinds.item.move(dir);
    }

    /**
     * Enter on the open keybinds surface: arm chord capture on the focused row.
     * No-op unless the keybinds surface is open.
     */
    function keybindsActivate() {
        if (pill.keybindsOpen && ldKeybinds.item)
            ldKeybinds.item.activate();
    }

    readonly property bool keybindsListening: pill.keybindsOpen && ldKeybinds.item !== null && ldKeybinds.item.listening

    /**
     * A tile was picked in the standalone quick-record chooser. Screen with several
     * monitors flips to the inline sub-choice; otherwise each source kicks off its
     * resolver (which counts down once the target is ready) and the chooser closes.
     */
    function quickChooseSource(kind) {
        if (kind === "screen") {
            if (ScreenRec.monitors.length > 1) {
                ScreenRec.quickScreenChoosing = true;
                return;
            }
            ScreenRec.prepareScreen(pill.screenName);
        } else if (kind === "window") {
            ScreenRec.prepareWindow();
        }
        ScreenRec.quickChoosing = false;
        ScreenRec.quickScreenChoosing = false;
    }

    function quickPickMonitor(name) {
        ScreenRec.quickChoosing = false;
        ScreenRec.quickScreenChoosing = false;
        ScreenRec.prepareScreen(name);
    }

    /**
     * Pop the open link surface one subview back. Returns true when the step was
     * consumed, false when the surface is already at its root (or not open) and
     * Escape should close the surface instead.
     */
    function linkBack() {
        return (pill.linkOpen && ldLink.item) ? ldLink.item.back() : false;
    }

    /**
     * Step the open surface back one level when its header bar is clicked: a
     * settings sub-surface returns to the index, the font picker to appearance,
     * a keybinds form to its list, and any other surface dismisses to the hover
     * pill. Empty space in the body never triggers this.
     */
    function surfaceBack() {
        if (pill.keybindsOpen) {
            if (ldKeybinds.item && ldKeybinds.item.formOpen)
                ldKeybinds.item.closeForm();
            else
                pill.requestSurface("settings");
            return;
        }
        if (pill.fontpickerOpen) {
            pill.requestSurface("appearance");
            return;
        }
        if (pill.stashOpen) {
            if (ldStash.item && ldStash.item.addOpen)
                ldStash.item.closeAdd();
            else
                pill.requestSurface("workspaces");
            return;
        }
        if (pill.spaceappsOpen) {
            if (ldSpaceapps.item && ldSpaceapps.item.addOpen)
                ldSpaceapps.item.closeAdd();
            else
                pill.requestSurface("workspaces");
            return;
        }
        if (pill.workspacesOpen && ldWorkspaces.item && ldWorkspaces.item.formOpen) {
            ldWorkspaces.item.closeForm();
            return;
        }
        if (pill.appearanceOpen || pill.updatesOpen || pill.displayOpen || pill.inputOpen || pill.lookOpen || pill.idlelockOpen || pill.animationOpen || pill.workspacesOpen) {
            pill.requestSurface("settings");
            return;
        }
        pill.requestClose();
    }

    /**
     * Pop the open keybinds editor form back to the bind list. Returns true when a
     * form was open and dismissed, false otherwise so Escape closes the surface.
     */
    function keybindsBack() {
        if (pill.keybindsOpen && ldKeybinds.item && ldKeybinds.item.formOpen) {
            ldKeybinds.item.closeForm();
            return true;
        }
        return false;
    }

    /**
     * Slide the open wallpaper strip's focus by `dir` thumbs; +1 is right (older)
     * and -1 is left (newer). No-op unless the wallpaper surface is open.
     */
    function wallpaperMove(dir) {
        if (pill.wallpaperOpen && ldWall.item)
            ldWall.item.move(dir);
    }

    /**
     * Apply the wallpaper strip's focused thumb through wallpaper.sh. The
     * surface stays open so the pick can be iterated. No-op unless the
     * wallpaper surface is open.
     */
    function wallpaperActivate() {
        if (pill.wallpaperOpen && ldWall.item)
            ldWall.item.activate();
    }

    readonly property bool wallpaperSearching: pill.wallpaperOpen && ldWall.item !== null && ldWall.item.searching

    /**
     * Route the first printable keystroke over the open wallpaper strip into a
     * DuckDuckGo search seeded with that character. No-op unless the wallpaper
     * surface is open.
     */
    function wallpaperType(ch) {
        if (pill.wallpaperOpen && ldWall.item)
            ldWall.item.startSearch(ch);
    }

    /**
     * Slide the open power surface's keyboard focus by `dir` tiles; +1 is right
     * and -1 is left. No-op unless the power surface is open.
     */
    function powerMove(dir) {
        if (pill.powerOpen && ldPower.item)
            ldPower.item.move(dir);
    }

    /**
     * Enter pressed on the open power surface's focused tile: fires a safe tile
     * at once, latches a destructive tile's heat hold. Returns true when a tile
     * consumed the key. No-op (false) unless the power surface is open.
     */
    function powerPress() {
        return (pill.powerOpen && ldPower.item) ? ldPower.item.pressFocused() : false;
    }

    /**
     * Enter released on the open power surface: drains an unfinished destructive
     * hold so a key let go before the fill completes never confirms.
     */
    function powerRelease() {
        if (pill.powerOpen && ldPower.item)
            ldPower.item.releaseFocused();
    }

    onSurfaceOpenChanged: if (surfaceOpen) {
        pinned = false;
        if (quickHere && ScreenRec.quickChoosing) {
            ScreenRec.quickChoosing = false;
            ScreenRec.quickScreenChoosing = false;
        }
    }

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string timeFormat: (Flags.time12h ? "h:mm" : "HH:mm")
            + (Flags.clockSeconds ? ":ss" : "")
            + (Flags.time12h ? " AP" : "")
        readonly property string hhmm: Qt.formatTime(now, timeFormat)
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    property real morphRadius: (mode === "rest" || mode === "hover" || mode === "game") ? restCorner : openCorner

    /**
     * Target geometry for the non-surface morph modes. Surface sizes come from
     * the `surfaces` descriptor; these three are the pill's own modes that have no
     * surface item. Thunks so the properties they read register as live deps of
     * targetSize.
     */
    readonly property var modeSize: ({
        osd:   () => Qt.size(osd.desiredW, osd.desiredH),
        toast: () => Qt.size(toastW, toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH),
        hover: () => Qt.size(hoverW, hoverH),
        quickChoose: () => Qt.size(quickChooseW, quickChooseH),
        quickCount:  () => Qt.size(quickCountW, quickCountH),
        dragOver:    () => Qt.size(dragOverW, dragOverH),
        game:        () => Qt.size(gameW, gameH)
    })

    readonly property size targetSize: {
        const sf = surfaces[mode];
        if (sf)
            return sf.size();
        const f = modeSize[mode];
        return f ? f() : Qt.size(Math.max(restW, restRow.implicitWidth + 36 * s), restH);
    }
    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: targetW
    height: targetH

    /**
     * How settled the pill is into its target geometry: 0 while the morph is far
     * away, 1 once it arrives. Content opacities key off this, not their own
     * timers, so a surface fades in as the pill reaches full size, never over a
     * half-grown pill.
     */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    /**
     * Gate the soul bead until the hover morph has arrived and its icons exist.
     * Fire it earlier and the bead aims at anchors that aren't laid out yet.
     * Latched so small width changes inside hover (workspace dot growing, tray
     * icons appearing) don't flicker the bead off.
     */
    property bool hoverSoulGate: false
    readonly property bool hoverArrived: mode === "hover" && morphCloseness > 0.55
    onHoverArrivedChanged: if (hoverArrived) hoverSoulGate = true

    /**
     * Rest and hover sit a few dozen pixels apart, so the 420ms morph is nearly
     * all settle tail on that hop and reads sluggish. Both endpoints in the
     * rest/hover pair get the shorter glide; every real surface morph keeps the
     * full duration.
     */
    property string lastMode: "rest"
    property bool hoverHop: false

    onModeChanged: {
        hoverHop = (mode === "hover" || mode === "rest") && (lastMode === "hover" || lastMode === "rest");
        lastMode = mode;
        if (mode !== "hover") {
            hoverSoulGate = false;
            soulTarget = "";
            soulWsIndex = -1;
        }
    }
    onHoverSoulGateChanged: if (hoverSoulGate) kanjiFlashAnim.restart()

    property string soulTarget: ""
    property int soulWsIndex: -1

    property real kanjiFlash: 0

    SequentialAnimation {
        id: kanjiFlashAnim
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    Behavior on width { NumberAnimation { duration: pill.hoverHop ? Motion.glide : Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: pill.hoverHop ? Motion.glide : Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on morphRadius { NumberAnimation { duration: pill.hoverHop ? Motion.glide : Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

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
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }
        Behavior on budR { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard } }

        Canvas {
            id: budBead
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 3 * pill.s
            width: 18 * pill.s
            height: 18 * pill.s
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const R = (budArea.containsMouse ? 5.2 : 4) * pill.s;
                const hg = ctx.createRadialGradient(c - R * 0.32, c - R * 0.38, 0, c, c, R);
                hg.addColorStop(0, Theme.flameInk);
                hg.addColorStop(0.55, Theme.vermLit);
                hg.addColorStop(0.92, Theme.verm);
                hg.addColorStop(1, Theme.flameEmber);
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

    Rectangle {
        id: body
        anchors.fill: parent

        /**
         * Corner flatness rides the morph curve so docking into the game bar
         * squares the corners as one continuous shape change instead of a snap.
         */
        property real gameFlat: pill.mode === "game" ? 1 : 0
        Behavior on gameFlat { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

        radius: pill.morphRadius
        topLeftRadius: pill.morphRadius * (1 - gameFlat)
        topRightRadius: pill.morphRadius * (1 - gameFlat)
        bottomLeftRadius: pill.morphRadius * (1 - gameFlat)
        bottomRightRadius: pill.morphRadius * (1 - gameFlat)
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * pill.s
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }

    /**
     * Rest anchor for Ame: the 時 kanji centre. The idle outline condenses into
     * the bead here before it moves.
     */
    readonly property point wakePoint: {
        void pill.width;
        void pill.height;
        return restKanji.mapToItem(pill, restKanji.width / 2, restKanji.height / 2);
    }

    /**
     * Bead target while hovered. soulTarget is a sticky key written by the hover
     * sources: the bead parks on the last focused dot or icon and glides to the
     * next, so crossing a gap between targets doesn't snap it back to the active
     * workspace. Pill geometry is voided so the anchor follows the hover morph,
     * the point stays live.
     */
    readonly property point soulPoint: {
        void pill.width;
        void pill.height;
        const drop = 12 * pill.s;
        if (soulTarget === "wifi")
            return wifiIcon.mapToItem(pill, wifiIcon.width / 2, wifiIcon.height + drop * 0.55);
        if (soulTarget === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (soulTarget === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        if (soulTarget === "mixer")
            return mixerIcon.mapToItem(pill, mixerIcon.width / 2, mixerIcon.height + drop * 0.55);
        if (soulTarget === "power")
            return powerIcon.mapToItem(pill, powerIcon.width / 2, powerIcon.height + drop * 0.55);
        if (soulTarget === "settings")
            return settingsIcon.mapToItem(pill, settingsIcon.width / 2, settingsIcon.height + drop * 0.55);
        if (soulTarget === "recorder")
            return recorderIcon.mapToItem(pill, recorderIcon.width / 2, recorderIcon.height + drop * 0.55);
        if (soulTarget === "sysmon")
            return sysmonIcon.mapToItem(pill, sysmonIcon.width / 2, sysmonIcon.height + drop * 0.55);
        if (soulTarget === "ws" && soulWsIndex >= 0) {
            void ws.activeName;
            void ws.width;
            const p = ws.mapToItem(pill, ws.slotCenterX(soulWsIndex), ws.height / 2);
            return Qt.point(p.x, p.y + drop);
        }
        return ws.mapToItem(pill, ws.activeDotPoint.x, ws.activeDotPoint.y + drop);
    }

    /**
     * Which open surface owns Ame's anchor. Each surface exports its own
     * `ameForm`/`amePoint`; the pill picks the open surface's `ame` from the
     * descriptor and maps it. Null = nothing open (or a surface with no anchor,
     * e.g. wallpaper), so Ame falls back to the pill's own hover/wake anchor.
     */
    readonly property var ameSurface: (surfaceOpen && surfaces[surface] !== undefined)
        ? surfaces[surface].ame() : null

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        heat: (pill.powerOpen && ldPower.item) ? ldPower.item.holdProgress : 0
        wake: pill.wakePoint
        wickDir: pill.powerOpen ? 1 : -1
        form: pill.ameSurface ? pill.ameSurface.ameForm
            : (pill.mode === "hover" && pill.hoverSoulGate ? "soul" : "off")
        point: pill.ameSurface
            ? Qt.point(pill.ameSurface.x + pill.ameSurface.amePoint.x,
                       pill.ameSurface.y + pill.ameSurface.amePoint.y)
            : (pill.mode === "hover" ? pill.soulPoint : pill.wakePoint)
    }

    /**
     * Extra input width past the pill's right edge while the media bud sticks
     * out there, so the window mask covers the bud's outer half. pill.hovered is
     * fed by a window-level HoverHandler in shell.qml: pointer events only exist
     * inside the input mask, so "window hovered" means "pointer over the pill (or
     * bud)". That sidesteps the per-item hover flicker the child MouseAreas and
     * the centred width morph would otherwise cause.
     */
    readonly property real inputPadRight: bud.shown ? bud.budR + 2 * s : 0

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
        } else {
            graceTimer.restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 300
        onTriggered: {
            if (pill.morphCloseness < 0.95) {
                graceTimer.restart();
                return;
            }
            pill.hoverLatch = false;
        }
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    property var installQueue: []

    function localPath(url) {
        var s = String(url);
        if (s.indexOf("file://") === 0)
            s = s.substring(7);
        return decodeURIComponent(s);
    }

    function appimagePaths(urls) {
        var out = [];
        for (var i = 0; i < urls.length; i++)
            if (/\.appimage$/i.test(String(urls[i])))
                out.push(pill.localPath(urls[i]));
        return out;
    }

    function dropLabel(urls) {
        var p = pill.localPath(urls.length ? urls[0] : "");
        return p.substring(p.lastIndexOf("/") + 1).replace(/\.appimage$/i, "");
    }

    property bool installedAny: false
    property string installAction: "new"

    function runNextInstall() {
        if (pill.installQueue.length === 0) {
            pill.dragStage = pill.installedAny ? "done" : "fail";
            (pill.installedAny ? dropDoneTimer : dropBadTimer).restart();
            return;
        }
        var next = pill.installQueue.shift();
        pill.dragName = next.substring(next.lastIndexOf("/") + 1).replace(/\.appimage$/i, "");
        installProc.command = ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/appimage-install.sh", "install", next];
        installProc.running = true;
    }

    Process {
        id: installProc
        stdout: StdioCollector { id: installOut }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                pill.installedAny = true;
                var line = installOut.text.trim().split("\n").pop();
                var parts = line.split("\t");
                if (parts.length >= 3)
                    pill.installAction = parts[2];
            }
            pill.runNextInstall();
        }
    }

    Timer {
        id: dropDoneTimer
        interval: 1100
        onTriggered: {
            pill.dragActive = false;
            pill.dragStage = "";
            pill.requestSurface("launcher");
        }
    }

    Timer {
        id: dropBadTimer
        interval: 1300
        onTriggered: {
            pill.dragActive = false;
            pill.dragStage = "";
        }
    }

    /**
     * File drops land only on the resting pill; an open surface turns the pill
     * into a fullscreen modal that swallows the drag before it can start. An
     * AppImage kicks off the install, anything else flashes a rejection.
     */
    DropArea {
        anchors.fill: parent
        enabled: !pill.surfaceOpen && pill.dragStage !== "installing" && pill.dragStage !== "done"
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            drag.acceptProposedAction();
            pill.dragActive = true;
            pill.dragStage = pill.appimagePaths(drag.urls).length > 0 ? "hover" : "bad";
            pill.dragName = pill.dropLabel(drag.urls);
        }
        onExited: {
            if (pill.dragStage === "hover" || pill.dragStage === "bad") {
                pill.dragActive = false;
                pill.dragStage = "";
            }
        }
        onDropped: (drop) => {
            drop.acceptProposedAction();
            var appimages = pill.appimagePaths(drop.urls);
            if (appimages.length === 0) {
                pill.dragActive = true;
                pill.dragStage = "bad";
                pill.dragName = pill.dropLabel(drop.urls);
                dropBadTimer.restart();
                return;
            }
            pill.dragActive = true;
            pill.dragStage = "installing";
            pill.installedAny = false;
            pill.installAction = "new";
            pill.installQueue = appimages;
            pill.runNextInstall();
        }
    }

    /**
     * Drop-zone face: corner brackets frame a stage glyph and label that walk
     * from "drop to install" through the spinner to a checkmark. Shares the morph
     * fade of the other pill faces, so it grows in as the pill reaches its size.
     */
    Item {
        id: dragOverView
        anchors.fill: parent
        anchors.margins: 11 * pill.s
        enabled: pill.mode === "dragOver"
        opacity: pill.mode === "dragOver" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        readonly property color accent: (pill.dragStage === "bad" || pill.dragStage === "fail") ? "#e0533f" : Theme.vermLit
        readonly property real brLen: 15 * pill.s
        readonly property real brThick: 2 * pill.s

        Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            delegate: Item {
                id: corner
                required property var modelData
                readonly property bool rightSide: modelData[0] === 1
                readonly property bool bottomSide: modelData[1] === 1
                x: rightSide ? dragOverView.width - dragOverView.brLen : 0
                y: bottomSide ? dragOverView.height - dragOverView.brLen : 0
                width: dragOverView.brLen
                height: dragOverView.brLen

                Rectangle {
                    width: dragOverView.brLen
                    height: dragOverView.brThick
                    radius: dragOverView.brThick / 2
                    color: dragOverView.accent
                    anchors.top: corner.bottomSide ? undefined : parent.top
                    anchors.bottom: corner.bottomSide ? parent.bottom : undefined
                    anchors.left: corner.rightSide ? undefined : parent.left
                    anchors.right: corner.rightSide ? parent.right : undefined
                }
                Rectangle {
                    width: dragOverView.brThick
                    height: dragOverView.brLen
                    radius: dragOverView.brThick / 2
                    color: dragOverView.accent
                    anchors.top: corner.bottomSide ? undefined : parent.top
                    anchors.bottom: corner.bottomSide ? parent.bottom : undefined
                    anchors.left: corner.rightSide ? undefined : parent.left
                    anchors.right: corner.rightSide ? parent.right : undefined
                }
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 44 * pill.s
            spacing: 7 * pill.s

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26 * pill.s
                height: 26 * pill.s

                GlyphIcon {
                    id: dragGlyph
                    anchors.fill: parent
                    stroke: 2
                    color: dragOverView.accent
                    name: (pill.dragStage === "bad" || pill.dragStage === "fail") ? "close"
                        : (pill.dragStage === "installing" ? "reboot"
                        : (pill.dragStage === "done" ? "check" : "download"))

                    RotationAnimation on rotation {
                        running: pill.dragStage === "installing"
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                    onNameChanged: if (pill.dragStage !== "installing") rotation = 0
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pill.dragStage === "bad" ? "Not an AppImage"
                    : (pill.dragStage === "fail" ? "Install failed"
                    : (pill.dragStage === "installing" ? "Installing"
                    : (pill.dragStage === "done" ? (pill.installAction === "updated" ? "Updated"
                        : (pill.installAction === "reinstalled" ? "Reinstalled" : "Installed"))
                    : "Drop to install")))
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * pill.s
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pill.dragName
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * pill.s
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }

    /**
     * Game-mode face: the pill docks into a flush top bar carrying only the clock
     * and, when something plays, the current track. Everything else the desktop
     * usually shows is deliberately gone.
     */
    Item {
        id: gameBar
        anchors.fill: parent
        enabled: pill.mode === "game"
        opacity: pill.mode === "game" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18 * pill.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9 * pill.s
            opacity: Players.has ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * pill.s
                height: 26 * pill.s
                radius: 7 * pill.s
                color: Theme.tileBg
                clip: true
                Image {
                    anchors.fill: parent
                    source: Players.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Players.title
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12.5 * pill.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220 * pill.s)
                }
                Text {
                    text: Players.artist
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10.5 * pill.s
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220 * pill.s)
                    visible: text.length > 0
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: clock.hhmm
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 16 * pill.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }

        /**
         * Volume/brightness feedback stays visible while gaming as a compact
         * chip on the bar's right, since the full OSD face is parked behind
         * game mode in the mode ladder. Notifications stay suppressed.
         */
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18 * pill.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9 * pill.s
            opacity: osd.flashing && (osd.kind === "volume" || osd.kind === "brightness") ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * pill.s
                height: 14 * pill.s
                name: osd.kind === "brightness" ? "sun" : (osd.muted ? "speaker-off" : "speaker")
                color: osd.kind === "volume" && osd.muted ? Theme.dim : Theme.iconDim
                stroke: 1.7
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 64 * pill.s
                height: 3 * pill.s
                radius: 1.5 * pill.s
                color: Theme.threadBg

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (osd.kind === "brightness" ? osd.brightness : osd.volume)
                    radius: parent.radius
                    color: osd.kind === "volume" && osd.muted ? Theme.vermDim : Theme.vermLit
                    Behavior on width { NumberAnimation { duration: Motion.fast } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((osd.kind === "brightness" ? osd.brightness : osd.volume) * 100) + "%"
                color: osd.kind === "volume" && osd.muted ? Theme.dim : Theme.cream
                font.family: Theme.font
                font.pixelSize: 10.5 * pill.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (pill.expanded || pill.dragActive || pill.mode === "game" || pill.mode === "toast" || pill.mode === "osd" || pill.mode === "quickChoose" || pill.mode === "quickCount") ? 0 : Math.pow(pill.morphCloseness, 1.5)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: pill.mode === "rest" ? Motion.fast : Math.round(260 * Motion.mult) } }

        Row {
            id: restRow
            anchors.centerIn: parent
            spacing: 9 * pill.s
            Item {
                id: restKanji
                visible: pill.specialView === ""
                anchors.verticalCenter: parent.verticalCenter
                width: kanjiFill.implicitWidth
                height: kanjiFill.implicitHeight

                /** Audio leaving the speakers flips the clock glyph over to the live waveform. */
                readonly property bool barsOn: Flags.musicViz && Cava.active

                Text {
                    anchors.fill: parent
                    opacity: (Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                    text: kanjiFill.text
                    color: "transparent"
                    font: kanjiFill.font
                    style: Text.Outline
                    styleColor: Qt.alpha(Theme.vermLit,
                        Math.min(1, (pill.mode === "rest" || !pill.hoverSoulGate ? 0.5 : 0) + pill.kanjiFlash))
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                Text {
                    id: kanjiFill
                    opacity: (Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                    text: "時"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * pill.s
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    opacity: (!Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                    width: 17 * pill.s
                    height: 17 * pill.s
                    name: "clock"
                    color: Theme.cream
                    stroke: 1.7
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                MusicBars {
                    id: musicBars
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: kanjiFill.baseline
                    s: pill.s
                    opacity: restKanji.barsOn ? 1 : 0
                    scale: restKanji.barsOn ? 1 : 0.7
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }
            }
            Text {
                visible: pill.specialView === ""
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Text {
                visible: pill.specialView !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.specialView
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        opacity: pill.mode === "hover" ? Math.pow(pill.morphCloseness, 1.2) : 0
        visible: true
        Behavior on opacity { NumberAnimation { duration: pill.mode === "hover" ? Motion.fast : 40 } }

        readonly property bool live: pill.mode === "hover"

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 20 * pill.s

            Workspaces {
                id: ws
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                screenName: pill.screenName
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
                onHoverIndexChanged: if (hoverIndex >= 0) {
                    pill.soulTarget = "ws";
                    pill.soulWsIndex = hoverIndex;
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: hoverClock.implicitWidth
                height: hoverClock.implicitHeight

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 2 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * pill.s
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * pill.s

                Row {
                    id: weatherGlance
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Weather.ready
                    spacing: 5 * pill.s

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: hover.live
                    }
                    TapHandler {
                        enabled: hover.live
                        onTapped: pill.requestSurface("calendar")
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * pill.s
                        height: 16 * pill.s
                        name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                        color: Theme.subtle
                        stroke: 1.8
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.tempNow + "°"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 12.5 * pill.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }

                MinimizedTray {
                    id: minimized
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    screenName: pill.screenName
                    enabled: hover.live
                    visible: count > 0
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: minimized.count > 0
                    width: 1
                    height: 14 * pill.s
                    color: Theme.hair
                    opacity: 0.7
                }

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                Item {
                    id: dndIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.dnd
                    width: 16 * pill.s
                    height: 16 * pill.s

                    Shape {
                        id: dndShape

                        width: 16
                        height: 16
                        scale: pill.s
                        transformOrigin: Item.TopLeft
                        x: dndShape.boundingRect.width > 0
                           ? dndIcon.width / 2 - (dndShape.boundingRect.x + dndShape.boundingRect.width / 2) * pill.s
                           : (dndIcon.width - 16 * pill.s) / 2
                        y: dndShape.boundingRect.height > 0
                           ? dndIcon.height / 2 - (dndShape.boundingRect.y + dndShape.boundingRect.height / 2) * pill.s
                           : (dndIcon.height - 16 * pill.s) / 2
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 5.2; startY: 12.2
                            PathLine { x: 12.2; y: 12.2 }
                            PathLine { x: 12.2; y: 7.2 }
                            PathCubic {
                                control1X: 12.2; control1Y: 5.4
                                control2X: 11.2; control2Y: 4.0
                                x: 9.5; y: 3.5
                            }
                        }
                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 6.8; startY: 13.6
                            PathLine { x: 9.2; y: 13.6 }
                        }
                        ShapePath {
                            strokeColor: Theme.vermLit
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 3.2; startY: 2.8
                            PathLine { x: 13.0; y: 13.4 }
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (pill.wifiDev !== null && pill.wifiOn) || Battery.present
                    spacing: 12 * pill.s

                    Item {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.wifiDev !== null && pill.wifiOn
                        width: 17 * pill.s
                        height: 17 * pill.s

                        WifiGlyph {
                            anchors.centerIn: parent
                            s: pill.s
                            level: pill.wifiLevel
                            on: pill.wifiOn
                        }

                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pill.linkInitialView = "wifi";
                                pill.requestSurface("link");
                            }
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wifi"
                        }
                    }

                    Item {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Battery.present
                        width: battPct.implicitWidth
                        height: 17 * pill.s

                        Text {
                            id: battPct
                            anchors.centerIn: parent
                            text: Battery.pct + "%"
                            color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                            font.family: Theme.font
                            font.pixelSize: 13 * pill.s
                            font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                            font.features: { "tnum": 1 }
                        }

                        MouseArea {
                            id: batteryArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pill.requestSurface("battery")
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "battery"
                        }
                    }
                }

                Item {
                    id: inboxIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "inbox"
                        color: inboxArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        visible: Notifs.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2 * pill.s
                        anchors.rightMargin: -2 * pill.s
                        width: 5 * pill.s
                        height: 5 * pill.s
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: inboxArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pill.linkInitialView = "main";
                            pill.requestSurface("link");
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
                    }
                }

                Item {
                    id: mixerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "mixer"
                        color: mixerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: mixerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("mixer")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "mixer"
                    }
                }

                Item {
                    id: sysmonIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "monitor"
                        color: sysmonArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: sysmonArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("sysmon")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sysmon"
                    }
                }

                Item {
                    id: recorderIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        visible: !ScreenRec.recording
                        name: "video"
                        color: recorderArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: ScreenRec.recording
                        width: 12 * pill.s
                        height: 12 * pill.s
                        radius: width / 2
                        color: Theme.verm
                        SequentialAnimation on opacity {
                            running: ScreenRec.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: recorderArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (e) => {
                            if (e.button === Qt.RightButton) {
                                if (ScreenRec.recording)
                                    ScreenRec.stop();
                                return;
                            }
                            pill.requestSurface("recorder");
                        }
                        onDoubleClicked: (e) => {
                            if (e.button === Qt.LeftButton && ScreenRec.recording)
                                ScreenRec.stop();
                        }
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "recorder"
                    }
                }

                Item {
                    id: settingsIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "cog"
                        color: settingsArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.6
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("settings")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "settings"
                    }
                }

                Item {
                    id: powerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "shutdown"
                        color: powerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("power")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "power"
                    }
                }
            }
        }
    }

    /**
     * Morphing surfaces, one latch-once Loader each (see surfaceItem). Eager,
     * they dominated startup and per-monitor RAM; now a surface is built
     * synchronously on its first open and kept. Each loader fills the pill so
     * the PillSurface inside anchors exactly as it did as a direct child.
     *
     * The hot trio preloads shortly after startup: the mixer needs its Pipewire
     * trackers bound before it looks right, so a cold first open visibly popped
     * faders in. Startup itself stays light.
     */
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            ldMixer.active = true;
            ldMedia.active = true;
            ldLink.active = true;
        }
    }

    Loader {
        id: ldMixer
        active: false
        anchors.fill: parent
        sourceComponent: Mixer {
            s: pill.s
            open: pill.mixerOpen
            morphCloseness: pill.morphCloseness
        }
    }

    Loader {
        id: ldCalendar
        active: false
        anchors.fill: parent
        sourceComponent: Calendar {
            s: pill.s
            open: pill.calendarOpen
            morphCloseness: pill.morphCloseness
        }
    }

    Loader {
        id: ldLauncher
        active: false
        anchors.fill: parent
        sourceComponent: Launcher {
            s: pill.s
            open: pill.launcherOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldClip
        active: false
        anchors.fill: parent
        sourceComponent: Clipboard {
            s: pill.s
            open: pill.clipboardOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldWall
        active: false
        anchors.fill: parent
        sourceComponent: Wallpaper {
            s: pill.s
            open: pill.wallpaperOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldPower
        active: false
        anchors.fill: parent
        sourceComponent: Power {
            s: pill.s
            open: pill.powerOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldMedia
        active: false
        anchors.fill: parent
        sourceComponent: Media {
            s: pill.s
            open: pill.mediaOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldLink
        active: false
        anchors.fill: parent
        sourceComponent: Link {
            s: pill.s
            open: pill.linkOpen
            initialView: pill.linkInitialView
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    onLinkOpenChanged: if (!linkOpen) linkInitialView = "main"

    Loader {
        id: ldBattery
        active: false
        anchors.fill: parent
        sourceComponent: BatterySurface {
            s: pill.s
            open: pill.batteryOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldSettings
        active: false
        anchors.fill: parent
        sourceComponent: Settings {
            s: pill.s
            open: pill.settingsOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldKeybinds
        active: false
        anchors.fill: parent
        sourceComponent: Keybinds {
            s: pill.s
            open: pill.keybindsOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldWorkspaces
        active: false
        anchors.fill: parent
        sourceComponent: WorkspacesSurface {
            s: pill.s
            open: pill.workspacesOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldStash
        active: false
        anchors.fill: parent
        sourceComponent: Stash {
            s: pill.s
            open: pill.stashOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldSpaceapps
        active: false
        anchors.fill: parent
        sourceComponent: SpaceApps {
            s: pill.s
            open: pill.spaceappsOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldRecorder
        active: false
        anchors.fill: parent
        sourceComponent: Recorder {
            s: pill.s
            screenName: pill.screenName
            open: pill.recorderOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldSysmon
        active: false
        anchors.fill: parent
        sourceComponent: SysmonSurface {
            s: pill.s
            open: pill.sysmonOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
        }
    }

    Loader {
        id: ldAppearance
        active: false
        anchors.fill: parent
        sourceComponent: Appearance {
            s: pill.s
            open: pill.appearanceOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldUpdates
        active: false
        anchors.fill: parent
        sourceComponent: Updates {
            s: pill.s
            open: pill.updatesOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldDisplay
        active: false
        anchors.fill: parent
        sourceComponent: Display {
            s: pill.s
            open: pill.displayOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldInput
        active: false
        anchors.fill: parent
        sourceComponent: Input {
            s: pill.s
            open: pill.inputOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldLook
        active: false
        anchors.fill: parent
        sourceComponent: Look {
            s: pill.s
            open: pill.lookOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldIdlelock
        active: false
        anchors.fill: parent
        sourceComponent: IdleLock {
            s: pill.s
            open: pill.idlelockOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldAnimation
        active: false
        anchors.fill: parent
        sourceComponent: AnimationSurface {
            s: pill.s
            open: pill.animationOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Loader {
        id: ldFontpicker
        active: false
        anchors.fill: parent
        sourceComponent: FontPicker {
            s: pill.s
            open: pill.fontpickerOpen
            morphCloseness: pill.morphCloseness
            onRequestClose: pill.requestClose()
            onRequestSurface: (name) => pill.requestSurface(name)
        }
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s
        screenName: pill.screenName
        suppressed: pill.surfaceOpen || pill.held
        expanded: pill.expanded
        enabled: pill.mode === "osd"
        opacity: pill.mode === "osd" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 12 * pill.s
        enabled: pill.mode === "toast"
        opacity: pill.mode === "toast" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: pill.s
                live: pill.mode === "toast"
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Notifs.popups.length > 1
                text: "+" + (Notifs.popups.length - 1)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * pill.s
                font.weight: Font.DemiBold
            }
        }
    }

    /**
     * Standalone quick-record source chooser. Driven by the SUPER+D keybind with
     * no recorder surface open: it grows the pill on the focused monitor only
     * (mode "quickChoose") and offers the same Screen and Window / Region picks as
     * the surface. Screen with one monitor resolves at once; several monitors flip
     * to the inline sub-choice. A pick fires ScreenRec.prepareScreen / prepareWindow
     * → targetReady → the central countdown, then closes.
     */
    Item {
        id: quickChooser
        anchors.fill: parent
        anchors.margins: 6 * pill.s
        enabled: pill.mode === "quickChoose"
        opacity: pill.mode === "quickChoose" ? Math.pow(pill.morphCloseness, 1.3) : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Row {
            id: quickSources
            anchors.fill: parent
            visible: !ScreenRec.quickScreenChoosing
            spacing: 6 * pill.s

            Repeater {
                model: [
                    { kind: "screen", label: "Screen", glyph: "monitor" },
                    { kind: "window", label: "Window / Region", glyph: "video" }
                ]

                Rectangle {
                    id: qSrcTile
                    required property var modelData
                    width: (quickSources.width - 6 * pill.s) / 2
                    height: parent.height
                    radius: 11 * pill.s
                    color: qSrcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                    border.width: 1
                    border.color: qSrcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8 * pill.s

                        GlyphIcon {
                            width: 16 * pill.s
                            height: 16 * pill.s
                            name: qSrcTile.modelData.glyph
                            color: qSrcArea.containsMouse ? Theme.vermLit : Theme.iconDim
                            stroke: 1.7
                        }
                        Text {
                            height: 16 * pill.s
                            verticalAlignment: Text.AlignVCenter
                            text: qSrcTile.modelData.label
                            color: qSrcArea.containsMouse ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 11 * pill.s
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: qSrcArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.quickChooseSource(qSrcTile.modelData.kind)
                    }
                }
            }
        }

        ListView {
            id: quickScreens
            anchors.fill: parent
            anchors.rightMargin: 22 * pill.s
            visible: ScreenRec.quickScreenChoosing
            orientation: ListView.Horizontal
            spacing: 6 * pill.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ScreenRec.monitors

            delegate: Rectangle {
                id: qMonTile
                required property var modelData
                width: 152 * pill.s
                height: quickScreens.height
                radius: 11 * pill.s
                color: qMonArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                border.width: 1
                border.color: qMonArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 2 * pill.s

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qMonTile.modelData.name
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * pill.s
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qMonTile.modelData.w + " × " + qMonTile.modelData.h
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * pill.s
                        font.features: { "tnum": 1 }
                    }
                }

                MouseArea {
                    id: qMonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.quickPickMonitor(qMonTile.modelData.name)
                }
            }
        }

        WheelScroller {
            flick: quickScreens
            s: pill.s
            anchors.fill: quickScreens
            visible: ScreenRec.quickScreenChoosing
        }

        GlyphIcon {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5 * pill.s
            visible: ScreenRec.quickScreenChoosing
            width: 12 * pill.s
            height: 12 * pill.s
            name: "chevron-left"
            color: qBackArea.containsMouse ? Theme.cream : Theme.faint
            stroke: 2

            MouseArea {
                id: qBackArea
                anchors.fill: parent
                anchors.margins: -7 * pill.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ScreenRec.quickScreenChoosing = false
            }
        }
    }

    /**
     * Standalone pre-roll countdown toast. Shown at the pill top on the focused
     * monitor when the central countdown runs and the recorder surface is closed
     * (mode "quickCount"): a big flame-glow numeral over a small "GET READY" label.
     * Tapping cancels. The surface's own in-bar countdown covers the surface case.
     */
    Item {
        id: quickCount
        anchors.fill: parent
        enabled: pill.mode === "quickCount"
        opacity: pill.mode === "quickCount" ? Math.pow(pill.morphCloseness, 1.3) : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1 * pill.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ScreenRec.countdown
                color: Theme.flameGlow
                font.family: Theme.font
                font.pixelSize: 28 * pill.s
                font.weight: Font.ExtraBold
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GET READY"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 8.5 * pill.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * pill.s
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenRec.cancel()
        }
    }

}
