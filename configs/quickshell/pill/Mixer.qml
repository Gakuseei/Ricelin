import QtQuick
import Quickshell.Services.Pipewire
import "Singletons"

/**
 * Mixer surface: quick toggles in the header and a row of vertical faders for brightness, vibrance, volume and mic.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    /** Which device dropdown is open: "out", "in", or "" for none. */
    property string openPicker: ""

    property int focusIndex: -1
    readonly property int faderCount: faders.length
    readonly property var faders: {
        void brRep.count;
        void blLoader.item;
        var out = [];
        for (var i = 0; i < brRep.count; i++) {
            var f = brRep.itemAt(i);
            if (f)
                out.push(f);
        }
        if (blLoader.item)
            out.push(blLoader.item);
        out.push(vibFader, volFader, micFader);
        return out;
    }
    readonly property bool surfaceHovered: hoverTracker.hovered
    readonly property bool multiMonitor: Devices.ddcMonitors.length > 1

    /** Tick centre of the focused fader in this surface; size deps are voided so it follows a resize. */
    readonly property point focusTickPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        const i = Math.max(0, Math.min(faders.length - 1, root.focusIndex));
        const f = faders[i];
        if (!f)
            return Qt.point(0, 0);
        return f.mapToItem(root, f.tickCenter.x, f.tickCenter.y);
    }

    ameForm: "tick"
    amePoint: focusTickPoint

    /** MouseArea hover is flaky on this layer, so one HoverHandler maps the pointer x to a fader column. */
    readonly property int hoverIndex: surfaceHovered && width > 0 && faders.length > 0
        && hoverTracker.point.position.y >= faderRow.y
        ? Math.max(0, Math.min(faders.length - 1, Math.floor(hoverTracker.point.position.x / (width / faders.length))))
        : -1
    onHoverIndexChanged: if (hoverIndex >= 0 && !keyLatch.running) focusIndex = hoverIndex

    HoverHandler {
        id: hoverTracker
    }

    /** An arrow key holds focus briefly so a stray pointer move can't yank it mid-navigation. */
    Timer {
        id: keyLatch
        interval: Motion.standard
    }

    onActiveChanged: {
        focusIndex = active ? 0 : -1;
        if (!active)
            openPicker = "";
    }

    function back() {
        if (openPicker.length) {
            openPicker = "";
            return true;
        }
        return false;
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down)
            return stepFocused(e.key === Qt.Key_Up ? 1 : -1);
        if (e.key !== Qt.Key_Left && e.key !== Qt.Key_Right)
            return false;
        moveFocus(e.key === Qt.Key_Left ? -1 : 1);
        return true;
    }

    function stepFocused(deltaPct) {
        if (focusIndex < 0)
            return false;
        faders[focusIndex].step(deltaPct);
        keyLatch.restart();
        return true;
    }

    function moveFocus(dir) {
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
        keyLatch.restart();
    }

    Component.onCompleted: Devices.detect()

    property real pendingVibrance: -1
    property int pendingBacklight: -1

    Timer {
        id: vibDebounce
        interval: 160
        onTriggered: if (root.pendingVibrance >= 0) {
            Devices.setVibrance(root.pendingVibrance);
            root.pendingVibrance = -1;
        }
    }

    Timer {
        id: blDebounce
        interval: 160
        onTriggered: if (root.pendingBacklight >= 0) {
            Devices.setBacklight(root.pendingBacklight);
            root.pendingBacklight = -1;
        }
    }

    PwObjectTracker {
        objects: Sound.outputs.concat(Sound.inputs)
    }

    /** Header toggle or device picker; a picker reads as an open field while its list shows. */
    component HeadChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        property bool picker: false
        property string tipTitle: ""
        property string tipDesc: ""
        signal clicked()

        width: 26 * root.s
        height: width
        radius: Theme.r.s * root.s
        color: chipArea.pressed ? Theme.pressBg
            : chip.on ? (chip.picker ? Qt.alpha(Theme.onGlow, 0.14) : Theme.frameBg)
            : (chipHover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: chip.on ? (chip.picker ? Qt.alpha(Theme.onGlow, 0.5) : Theme.frameBorder)
            : (chipHover.hovered ? Theme.vermDim : Theme.border)
        scale: chipArea.pressed && !Motion.calm ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: chip.glyph
            color: chip.on ? Theme.vermLit : (chipHover.hovered ? Theme.cream : Theme.iconDim)
            stroke: 1.7
        }

        HoverHandler {
            id: chipHover
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: chip.tipTitle
            desc: chip.tipDesc
            show: chipHover.hovered && !(chip.picker && chip.on)
        }
    }

    SurfaceHeader {
        id: header
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s
        s: root.s
        glyph: "調"
        title: "Mixer"

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp.xs * root.s

            HeadChip {
                glyph: "speaker"
                picker: true
                on: root.openPicker === "out"
                tipTitle: "Output device"
                tipDesc: Sound.label(Sound.sink)
                onClicked: root.openPicker = root.openPicker === "out" ? "" : "out"
            }
            HeadChip {
                glyph: "mic"
                picker: true
                on: root.openPicker === "in"
                tipTitle: "Input device"
                tipDesc: Sound.label(Sound.source)
                onClicked: root.openPicker = root.openPicker === "in" ? "" : "in"
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16 * root.s
                color: Theme.hair
            }

            HeadChip {
                glyph: "dnd"
                on: Flags.dnd
                tipTitle: "Do not disturb"
                tipDesc: "Silences notifications"
                onClicked: Flags.dnd = !Flags.dnd
            }
            HeadChip {
                glyph: "awake"
                on: Flags.keepAwake
                tipTitle: "Keep awake"
                tipDesc: "Blocks sleep and screen-off"
                onClicked: Flags.keepAwake = !Flags.keepAwake
            }
            HeadChip {
                glyph: "moon"
                on: Flags.nightLightMode !== "off"
                tipTitle: "Night light"
                tipDesc: "Warms the screen"
                onClicked: NightLight.setMode(Flags.nightLightMode === "off" ? "on" : "off")
            }
            HeadChip {
                glyph: "gamepad"
                on: Flags.gameMode
                tipTitle: "Game mode"
                tipDesc: "Strips effects and quiets the desktop"
                onClicked: Flags.gameMode = !Flags.gameMode
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: Theme.sp.s * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    DeviceMenu {
        s: root.s
        open: root.openPicker === "out"
        anchors.top: divider.bottom
        anchors.topMargin: Theme.sp.xs * root.s
        anchors.right: parent.right
        model: Sound.outputs
        current: Sound.sink
        onPick: (node) => {
            Pipewire.preferredDefaultAudioSink = node;
            root.openPicker = "";
        }
    }

    DeviceMenu {
        s: root.s
        open: root.openPicker === "in"
        anchors.top: divider.bottom
        anchors.topMargin: Theme.sp.xs * root.s
        anchors.right: parent.right
        model: Sound.inputs
        current: Sound.source
        onPick: (node) => {
            Pipewire.preferredDefaultAudioSource = node;
            root.openPicker = "";
        }
    }

    Row {
        id: faderRow
        anchors.top: divider.bottom
        anchors.topMargin: Theme.sp.s * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 142 * root.s
        spacing: 0

        readonly property real colW: width / Math.max(1, root.faderCount)

        Repeater {
            id: brRep
            model: Devices.ddcMonitors

            VFader {
                id: brFader

                required property var modelData
                required property int index

                property int pct: Devices.ddcPct[modelData.bus] !== undefined ? Devices.ddcPct[modelData.bus] : 75
                property real pendingPct: -1

                width: faderRow.colW
                s: root.s
                icon: "sun"
                subLabel: root.multiMonitor ? modelData.label : "Brightness"
                focused: root.focusIndex === index
                value: pct / 100
                valueLabel: pct + "%"
                onMoved: (v) => pct = Math.max(5, Math.min(100, Math.round(v * 100)))
                onCommitted: (v) => {
                    pendingPct = Math.max(5, Math.min(100, Math.round(v * 100)));
                    brCommit.restart();
                }

                Timer {
                    id: brCommit
                    interval: 160
                    onTriggered: if (brFader.pendingPct >= 0) {
                        Devices.setBrightness(brFader.modelData.bus, brFader.pendingPct);
                        brFader.pendingPct = -1;
                    }
                }
            }
        }

        Loader {
            id: blLoader
            active: Devices.backlightPresent
            visible: active
            width: active ? faderRow.colW : 0

            sourceComponent: VFader {
                width: faderRow.colW
                s: root.s
                icon: "sun"
                subLabel: brRep.count > 0 ? "Built-in" : "Brightness"
                focused: root.focusIndex === brRep.count
                value: Devices.backlightPct / 100
                valueLabel: Devices.backlightPct + "%"
                onMoved: (v) => Devices.backlightPct = Math.max(1, Math.min(100, Math.round(v * 100)))
                onCommitted: (v) => { root.pendingBacklight = Math.max(1, Math.min(100, Math.round(v * 100))); blDebounce.restart(); }
            }
        }

        VFader {
            id: vibFader
            width: faderRow.colW
            s: root.s
            icon: "monitor"
            subLabel: "Vibrance"
            focused: root.focusIndex === root.faderCount - 3
            value: Devices.vibrance / 100
            valueLabel: Devices.vibrance + "%"
            onMoved: (v) => Devices.vibrance = Math.round(v * 100)
            onCommitted: (v) => { root.pendingVibrance = v * 100; vibDebounce.restart(); }
        }
        VFader {
            id: volFader
            readonly property var sink: Sound.sink && Sound.sink.audio ? Sound.sink : null
            width: faderRow.colW
            s: root.s
            icon: "speaker"
            subLabel: "Volume"
            focused: root.focusIndex === root.faderCount - 2
            value: volFader.sink ? volFader.sink.audio.volume / Sound.limit : 0
            valueLabel: Math.round((volFader.sink ? volFader.sink.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (volFader.sink) volFader.sink.audio.volume = v * Sound.limit; }
        }
        VFader {
            id: micFader
            readonly property var source: Sound.source && Sound.source.audio ? Sound.source : null
            readonly property bool muted: micFader.source ? micFader.source.audio.muted : false
            width: faderRow.colW
            s: root.s
            icon: micFader.muted ? "mic-off" : "mic"
            subLabel: "Microphone"
            focused: root.focusIndex === root.faderCount - 1
            value: micFader.source ? micFader.source.audio.volume : 0
            valueLabel: micFader.muted ? "Muted" : Math.round((micFader.source ? micFader.source.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (micFader.source) micFader.source.audio.volume = v; }

            MouseArea {
                id: micMute
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * root.s
                height: 22 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (micFader.source) micFader.source.audio.muted = !micFader.muted; }
            }
        }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0 && root.stepFocused(notches * 5))
                acc -= notches;
            event.accepted = true;
        }
    }
}
