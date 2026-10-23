//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Washi pill top shell with one Overlay layer per monitor, masked to the pill rect while collapsed so the rest of the screen clicks through.
 */
ShellRoot {
    id: root

    /**
     * Heartbeat for watchdog.sh, which restarts this shell when it stops beating.
     */
    FileView {
        id: heartbeat
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-pill-alive"
        printErrors: false
        blockLoading: false
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: heartbeat.setText(String(Date.now()))
    }

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
        Devices.detect();
        void GameMode.active;
        void Sound.eq;
    }

    /**
     * Shows a one-shot toast after an update relaunch, delayed so the notification server owns the bus first.
     */
    Timer {
        interval: 2500
        running: true
        onTriggered: updatedToast.running = true
    }
    Process {
        id: updatedToast
        command: ["sh", "-c",
            "m=\"${XDG_STATE_HOME:-$HOME/.local/state}/ricelin/updated\"; [ -f \"$m\" ] || exit 0; "
            + "b=$(cat \"$m\"); rm -f \"$m\"; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "Ricelin 0 '' 'Ricelin updated' \"$b\" '[]' '{}' 5000 >/dev/null 2>&1"]
    }

    /**
     * hypridle ignores the Wayland IdleInhibitor, so a logind idle inhibitor is held while keep-awake is on.
     */
    Process {
        running: Flags.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Ricelin",
                  "--why=keep awake", "--mode=block", "sleep", "infinity"]
    }

    /**
     * Only these events can change what the pill shows, since each model refresh costs three Hyprland IPC round-trips.
     */
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    /**
     * An empty monitor resolves to the focused one here so keybind scripts skip their own hyprctl+jq lookup.
     */
    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function sound(mon: string): void { root.toggleSurface(mon, "sound"); }
        function eq(): void { Sound.setEq(!Sound.eq); }
        function eqMode(name: string): void { Sound.pick(name); }
        function micFilter(): void { Sound.setDenoise(!Sound.denoise); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function settings(mon: string): void { root.toggleSurface(mon, "settings"); }
        function keybinds(mon: string): void { root.toggleSurface(mon, "keybinds"); }
        function recorder(mon: string): void { root.toggleSurface(mon, "recorder"); }

        /**
         * SUPER+D quick record that stops, cancels or dismisses whatever is running, else opens the source chooser on `mon` only.
         */
        function quickRecord(mon: string): void {
            if (ScreenRec.recording) {
                ScreenRec.stop();
            } else if (ScreenRec.counting) {
                ScreenRec.cancel();
            } else if (ScreenRec.quickChoosing) {
                ScreenRec.quickChoosing = false;
                ScreenRec.quickScreenChoosing = false;
            } else {
                ScreenRec.quickMon = mon;
                ScreenRec.quickScreenChoosing = false;
                ScreenRec.quickChoosing = true;
            }
        }
        function gameMode(mon: string): void { Flags.gameMode = !Flags.gameMode; }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
        function media(mon: string): void {
            if (Players.list.length > 0)
                root.toggleSurface(mon, "media");
        }
        function peek(mon: string): void { root.peek(mon); }
        function timer(minutes: int): void { minutes > 0 ? Countdown.start(minutes * 60) : Countdown.cancel(); }
        function hide(): void { root.close(); }

        /** Opens any surface by name, settings sub-pages included; dev and scripting door. */
        function page(mon: string, name: string): void { root.toggleSurface(mon, name); }

        /**
         * SUPER+M minimize toggle halves, which target the window by address so they act on the one pressed on and not whatever is active afterwards.
         */
        function minimizeWindow(addr: string): void {
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + addr + '" })');
        }
        function restoreWindow(arg: string): void {
            var p = arg.split("|");
            if (p.length < 2 || p[0].length === 0)
                return;
            Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + p[1] + ', window = "address:' + p[0] + '" })');
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: pill.authPending ? false : (surfaceOpen || pill.held || pill.quickChoosing)

            /**
             * True while this monitor's workspace has a fullscreen client, which retracts the pill and makes the layer click-through.
             */
            readonly property var hyprMon: Hyprland.monitorFor(modelData)
            readonly property bool monFullscreen: {
                const ws = hyprMon ? hyprMon.activeWorkspace : null;
                return ws && ws.lastIpcObject ? !!ws.lastIpcObject.hasfullscreen : false;
            }
            readonly property bool summoned: modal || root.peekMon === modelData.name
            readonly property bool pillHidden: monFullscreen && !summoned

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                pill.pinned = false;
            }

            /** Trimming the reserved band below the pill's bottom lets windows climb, so App gap sets the pill-to-window air without touching the desktop gaps_out. */
            readonly property real reservedH: Math.max(0, pill.restH + topGap - 12 * (1 - Flags.appGap) * s)

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Flags.gameMode ? 34 * s : reservedH
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: ((surfaceOpen || pill.quickChoosing) && !pill.authPending) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true }
            /**
             * Always screen tall: a layer resize shows the old buffer stretched into the new size for one frame, which flickered every open and close.
             */
            implicitHeight: modelData.height

            mask: modal ? fullRegion : (pillHidden ? hiddenRegion : pillRegion)
            Region { id: hiddenRegion }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: slot.x + pill.x + (pill.width - baseW) / 2
                y: slot.y + pill.y
                width: baseW + pill.inputPadRight
                height: Math.max(pill.height, pill.targetH)
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            IdleInhibitor { window: overlay; enabled: Flags.keepAwake }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else if (overlay.surfaceOpen) {
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside)
                            root.close();
                        else if (mouse.y <= pillRegion.y + 40 * pill.s)
                            pill.surfaceBack();
                    } else {
                        pill.pinned = false;
                        root.peekMon = "";
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.surfaceOpen || pill.quickChoosing

                HoverHandler {
                    onHoveredChanged: pill.hovered = hovered
                }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape) {
                        if (pill.quickChoosing) {
                            ScreenRec.quickChoosing = false;
                            ScreenRec.quickScreenChoosing = false;
                        } else {
                            pill.surfaceBack();
                        }
                        e.accepted = true;
                        return;
                    }
                    e.accepted = pill.current !== null && pill.current.handleKey(e) === true;
                }
                Keys.onReleased: (e) => {
                    e.accepted = pill.current !== null && pill.current.handleRelease(e) === true;
                }

                /**
                 * While a toast is dragged the slot becomes a soft-edged mask in the padding outside the pill, so an unmoved pill is never faded.
                 */
                Item {
                    id: slot
                    readonly property real pad: 56 * overlay.s
                    readonly property bool swiping: pill.swipeX !== 0 || pill.swipeY !== 0
                    anchors.top: parent.top
                    anchors.topMargin: (pill.mode === "game" ? 0 : overlay.topGap) - pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: pill.width + 2 * pad
                    height: pill.height + 2 * pad

                    Behavior on anchors.topMargin {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }

                    layer.enabled: swiping
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: wall
                    }

                    Item {
                        id: wall
                        width: slot.width
                        height: slot.height
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            id: wallRect
                            anchors.fill: parent
                            readonly property bool sideways: pill.swipeX !== 0
                            readonly property bool leftward: pill.swipeX < 0
                            readonly property real edge: slot.pad / (sideways ? slot.width : slot.height)
                            gradient: Gradient {
                                orientation: wallRect.sideways ? Gradient.Horizontal : Gradient.Vertical
                                GradientStop { position: 0.0; color: wallRect.sideways && !wallRect.leftward ? "white" : "transparent" }
                                GradientStop { position: wallRect.edge; color: "white" }
                                GradientStop { position: 1 - wallRect.edge; color: "white" }
                                GradientStop { position: 1.0; color: wallRect.sideways && wallRect.leftward ? "white" : "transparent" }
                            }
                        }
                    }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: slot.pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    monitor: overlay.hyprMon
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: root.peekMon === overlay.modelData.name

                    opacity: overlay.pillHidden ? 0 : pill.swipeFade
                    Behavior on opacity {
                        enabled: !slot.swiping
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    transform: [
                        Translate { x: pill.swipeX; y: pill.swipeY },
                        Translate {
                            y: overlay.pillHidden ? -(pill.height + overlay.topGap) : 0
                            Behavior on y {
                                NumberAnimation {
                                    duration: Motion.morph
                                    easing.type: Motion.easeMorph
                                    easing.bezierCurve: Motion.morphCurve
                                }
                            }
                        }
                    ]

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.close()
                }
                }
            }

            onSurfaceOpenChanged: if (surfaceOpen) focusScope.forceActiveFocus()

            Connections {
                target: pill
                function onQuickChoosingChanged() {
                    if (pill.quickChoosing)
                        focusScope.forceActiveFocus();
                }
            }
            Connections {
                target: pill.current
                function onHoldsFocusChanged() {
                    if (!pill.current.holdsFocus && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
            }
        }
    }
}
