pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Quickshell.Hyprland
import "Singletons"

Item {
    id: root

    property real s: 1
    property string screenName: ""
    property bool suppressed: false
    property bool expanded: false
    property bool flashing: false
    property string kind: "volume"
    property bool armed: false
    property bool dirty: false
    property bool cooling: false
    property int holdExtends: 0

    /**
     * The player this flash speaks for: an announce can point it at a newly started player without stealing the surface.
     */
    property var pendingSubject: null
    readonly property var subject: pendingSubject ? pendingSubject : Players.active
    readonly property bool subjectHas: subject !== null
    readonly property bool subjectPlaying: subjectHas && subject.isPlaying
    readonly property string subjectTitle: subjectHas ? Players.refineTitle(subject, subject.trackTitle || Players.labelOf(subject)) : ""
    readonly property string subjectArtist: subjectHas ? Theme.joinArtists(subject.trackArtists, subject.trackArtist) : ""
    readonly property string subjectIcon: subjectHas ? Players.appIconFor(subject) : ""

    /**
     * Live so a cover that lands after the title still resolves; the key reloads a browser's reused file path.
     */
    readonly property string liveArt: {
        if (!subjectHas)
            return "";
        var u = Players.artUrlFor(subject);
        if (!u)
            return "";
        return u.indexOf("file:") === 0 ? u + "#" + Players.keyFor(subject) : u;
    }

    readonly property real brightness: Backlight.brightness
    property bool recordStarted: false

    readonly property var sink: Sound.sink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(Sound.limit, sink.audio.volume)) : 0

    readonly property real desiredW: kind === "workspace" ? Math.max(120 * s, wsWidth + 40 * s)
        : (kind === "track" ? 344 * s : (kind === "record" ? 256 * s : 248 * s))
    readonly property real desiredH: kind === "track" ? 64 * s : 44 * s

    readonly property int leaveMs: 100
    readonly property int swapDelay: 60
    readonly property int clockGap: 80

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || null
    readonly property string activeWsName: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""

    /**
     * Skipped while expanded: the hover pill already shows the live dots.
     */
    onActiveWsNameChanged: if (activeWsName.length > 0 && !expanded) flash("workspace");

    /**
     * This monitor's rule-assigned workspaces plus the ones Hyprland has on it, as in Workspaces.qml.
     */
    readonly property var wsRange: {
        const seen = {};
        const out = [];
        const add = id => {
            if (id >= 1 && !seen[id]) {
                seen[id] = true;
                out.push(id);
            }
        };
        (Workspacerules.byMonitor[screenName] || []).forEach(add);
        Hyprland.workspaces.values.forEach(w => {
            if (w.monitor && w.monitor.name === screenName)
                add(w.id);
        });
        add(parseInt(activeWsName));
        return out.sort((a, b) => a - b);
    }
    readonly property int wsActive: wsRange.indexOf(parseInt(activeWsName))
    readonly property real dotW: 5 * s
    readonly property real stickW: 17 * s
    readonly property real wsPitch: dotW + Theme.sp.s * s
    readonly property real wsWidth: wsRange.length > 0 ? wsRange.length * wsPitch - Theme.sp.s * s + stickW - dotW : 0

    /**
     * The stick waits for the clock to clear on a fresh flash, then travels from where it last sat.
     */
    property bool stickHeld: false
    onWsActiveChanged: Qt.callLater(moveStick)
    function moveStick() {
        const x = Math.max(0, wsActive) * wsPitch;
        if (!flashing || kind !== "workspace" || Motion.calm) {
            stick.target = x;
            stick.snap(x);
        } else if (!stickHeld) {
            stick.target = x;
        }
    }

    Spring {
        id: stick
        response: 0.28
        damping: 0.9
    }

    /**
     * Leading-edge throttle: the first track change flashes at once, a burst during the cooldown or suppression replays once the gate opens.
     */
    function tryShow() {
        if (cooling)
            return;
        if (flash("track")) {
            dirty = false;
            cooling = true;
            cooldownTimer.restart();
        }
    }

    /**
     * Global signals flash only the focused monitor; workspace flashes are already keyed to this screen.
     */
    readonly property bool onFocusedMonitor: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName

    readonly property var views: [volView, brightView, battView, trackView, wsView, recView]

    function flash(which) {
        if (!armed || suppressed)
            return false;
        if (which !== "workspace" && !onFocusedMonitor)
            return false;
        if (which === "track" && flashing && (kind === "volume" || kind === "brightness"))
            return false;
        if (which === "track")
            holdExtends = 0;
        const fresh = !flashing;
        if (fresh || which !== kind)
            present(which, fresh);
        kind = which;
        flashing = true;
        hideTimer.interval = (which === "battery" || which === "record") ? 2000 : (which === "workspace" ? 1000 : 1800);
        hideTimer.restart();
        return true;
    }

    /**
     * Old content leaves fast and the new starts entering only once it is mostly gone, so two rows never sit at half strength.
     */
    function present(which, fresh) {
        stickHeld = which === "workspace" && fresh;
        for (const v of views) {
            if (v.k !== which)
                v.hide(!fresh);
            else if (!fresh)
                v.show(swapDelay);
            else
                v.show(which === "workspace" ? clockGap : -1);
        }
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop();
            flashing = false;
        } else if (dirty) {
            tryShow();
        }
    }

    /**
     * A track announce that lost to live hardware feedback replays once the bar clears.
     */
    onFlashingChanged: if (!flashing && dirty) tryShow()

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: cooldownTimer
        interval: 1500
        onTriggered: {
            root.cooling = false;
            if (root.dirty)
                root.tryShow();
        }
    }

    /**
     * Holds a track flash until its cover decodes, capped so a dead art url never pins the OSD.
     */
    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: {
            if (root.kind === "track" && cover.status !== Image.Ready && root.liveArt.length > 0 && root.holdExtends < 5) {
                root.holdExtends++;
                hideTimer.interval = 350;
                hideTimer.restart();
            } else {
                root.flashing = false;
            }
        }
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumesChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
    }

    Connections {
        target: Players
        function onAnnounce(player) {
            root.pendingSubject = player;
            root.dirty = true;
            root.tryShow();
        }
    }

    Connections {
        target: Battery
        enabled: Battery.present
        function onChargingChanged() {
            if (Battery.charging)
                root.flash("battery");
        }
    }

    Connections {
        target: ScreenRec
        function onRecordingChanged() {
            root.recordStarted = ScreenRec.recording;
            root.flash("record");
        }
    }

    Connections {
        target: Backlight
        function onChanged() {
            root.flash("brightness");
        }
    }

    OsdSlide {
        id: volView
        k: "volume"
        current: root.kind === "volume"
        leaveMs: root.leaveMs

        OsdLevel {
            s: root.s
            icon: root.muted ? "speaker-off" : "speaker"
            iconColor: root.muted ? Theme.dim : Theme.iconDim
            frac: root.volume / Sound.limit
            readout: Math.round(root.volume * 100) + "%"
            muted: root.muted
        }
    }

    OsdSlide {
        id: brightView
        k: "brightness"
        current: root.kind === "brightness"
        leaveMs: root.leaveMs

        OsdLevel {
            s: root.s
            icon: "sun"
            frac: root.brightness
            readout: Math.round(root.brightness * 100) + "%"
        }
    }

    OsdSlide {
        id: battView
        k: "battery"
        current: root.kind === "battery"
        leaveMs: root.leaveMs

        OsdLevel {
            s: root.s
            icon: "bolt"
            iconColor: Theme.flameGlow
            frac: Battery.frac
            readout: Battery.pct + "%"
            ember: true
            shimmer: Battery.charging
        }
    }

    OsdSlide {
        id: trackView
        k: "track"
        current: root.kind === "track"
        leaveMs: root.leaveMs

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 44 * root.s
            height: 44 * root.s
            radius: Theme.r.m * root.s
            color: Theme.tileBg

            Image {
                id: cover
                anchors.fill: parent
                source: root.liveArt
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: String(source).indexOf("file:") !== 0
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                /**
                 * Art decoded near the end of the flash still earns a moment on screen.
                 */
                onStatusChanged: if (status === Image.Ready && root.flashing && root.kind === "track") {
                    hideTimer.interval = 1300;
                    hideTimer.restart();
                }
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width
                name: "music"
                color: Theme.subtle
                visible: cover.status !== Image.Ready
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.sp.xxs * root.s
                width: 18 * root.s
                height: 18 * root.s
                radius: width / 2
                color: Qt.alpha(Theme.cardBot, 0.8)
                visible: srcIcon.status === Image.Ready

                Image {
                    id: srcIcon
                    anchors.centerIn: parent
                    width: 12 * root.s
                    height: 12 * root.s
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    source: root.subjectIcon
                }
            }
        }

        GlyphIcon {
            id: trackCtrl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: root.subjectPlaying ? "play" : "pause"
            color: root.subjectPlaying ? Theme.vermLit : Theme.iconDim
        }

        Column {
            anchors.left: coverBox.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.right: trackCtrl.left
            anchors.rightMargin: Theme.sp.m * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp.xxs * root.s

            Text {
                width: parent.width
                text: root.subjectHas ? root.subjectTitle : "Nothing playing"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.title * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.subjectArtist
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                maximumLineCount: 1
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    OsdSlide {
        id: wsView
        k: "workspace"
        current: root.kind === "workspace"
        leaveMs: root.leaveMs
        onEntering: {
            root.stickHeld = false;
            root.moveStick();
        }

        /**
         * One stick travels between the dots on a spring and stretches with its speed; its neighbours make room as it passes.
         */
        Item {
            id: strip
            anchors.centerIn: parent
            width: root.wsWidth
            height: root.dotW

            readonly property real p: stick.value / root.wsPitch
            readonly property real extra: root.stickW - root.dotW

            Repeater {
                model: root.wsRange.length

                Rectangle {
                    required property int index
                    readonly property real weight: Math.max(0, 1 - Math.abs(strip.p - index))
                    x: index * root.wsPitch + strip.extra * (Math.max(0, Math.min(1, index - strip.p)) + weight / 2)
                    width: root.dotW
                    height: root.dotW
                    radius: height / 2
                    color: Theme.cream
                    opacity: 0.3 * (1 - weight)
                }
            }

            Rectangle {
                readonly property real stretch: Math.min(0.3 * root.stickW, Math.abs(stick.velocity) * 0.05)
                visible: root.wsActive >= 0
                x: stick.value - stretch / 2
                width: root.stickW + stretch
                height: root.dotW
                radius: height / 2
                color: Theme.vermLit
            }
        }
    }

    OsdSlide {
        id: recView
        k: "record"
        current: root.kind === "record"
        leaveMs: root.leaveMs

        Rectangle {
            id: recGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * root.s
            height: 13 * root.s
            radius: width / 2
            color: root.recordStarted ? Theme.verm : Theme.dim

            SequentialAnimation on opacity {
                running: root.visible && recView.visible && root.recordStarted && !Motion.calm
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: Motion.pulse; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.left: recGlyph.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordStarted ? "Recording started" : "Recording stopped"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
