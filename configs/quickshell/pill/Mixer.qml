import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Singletons"

/**
 * Mixer surface content: header with DND / Keep-Awake chips and a row of four
 * vertical ink-faders wired to real hardware (brightness via ddcutil, vibrance
 * via nvibrant, volume and mic via Pipewire). Designed to fill the lower body
 * of the morphing pill.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    property int brightness: 75
    property int vibrance: 40

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/nvibrant-value"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property int focusIndex: -1
    readonly property var faders: [brFader, vibFader, volFader, micFader]
    readonly property bool surfaceHovered: hoverTracker.hovered

    /**
     * Tick centres of the four faders, mapped to this mixer's root. Snapshotted
     * on demand (at mixer open) for the flame's spark scatter — not live-bound.
     */
    function tickPoints() {
        return faders.map(function (f) {
            return f.mapToItem(root, f.tickCenter.x, f.tickCenter.y);
        });
    }

    /**
     * Pointer-driven fader targeting. MouseArea hover delivery is unreliable on
     * this layer-shell surface, so a non-blocking HoverHandler is the single
     * hover source: its pointer x maps to a fader column, which drives keyboard
     * focus directly.
     */
    readonly property int hoverIndex: surfaceHovered && width > 0
        ? Math.max(0, Math.min(faders.length - 1, Math.floor(hoverTracker.point.position.x / (width / faders.length))))
        : -1
    onHoverIndexChanged: if (hoverIndex >= 0) focusIndex = hoverIndex

    HoverHandler {
        id: hoverTracker
    }

    onActiveChanged: focusIndex = active ? 0 : -1

    /**
     * Nudge the focused fader by `deltaPct` percent. Returns true when a fader
     * handled the step.
     */
    function stepFocused(deltaPct) {
        if (focusIndex < 0)
            return false;
        faders[focusIndex].step(deltaPct);
        return true;
    }

    /**
     * Move keyboard focus across the fader row, wrapping at the ends. `dir` is +1
     * (right) or -1 (left); a fresh focus lands on the first or last fader.
     */
    function moveFocus(dir) {
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
    }

    function applyBrightness(pct) {
        var p = Math.max(5, Math.min(100, Math.round(pct)));
        Quickshell.execDetached(["bash", "-c", "timeout 3 ddcutil setvcp 10 " + p + " --bus 3 --noverify & timeout 3 ddcutil setvcp 10 " + p + " --bus 4 --noverify & wait"]);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        Quickshell.execDetached(["nvibrant", String(raw), "0", String(raw)]);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname '" + root.stateFile + "')\" && echo " + Math.round(pct) + " > '" + root.stateFile + "'"]);
    }

    Component.onCompleted: {
        var v = parseInt((vibState.text() || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
        brRead.running = true;
    }

    property real pendingBrightness: -1
    property real pendingVibrance: -1

    Timer {
        id: brDebounce
        interval: 160
        onTriggered: if (root.pendingBrightness >= 0) {
            root.applyBrightness(root.pendingBrightness);
            root.pendingBrightness = -1;
        }
    }
    Timer {
        id: vibDebounce
        interval: 160
        onTriggered: if (root.pendingVibrance >= 0) {
            root.applyVibrance(root.pendingVibrance);
            root.saveVibrance(root.pendingVibrance);
            root.pendingVibrance = -1;
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    Process {
        id: brRead
        command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", "3", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/C\s+(\d+)\s+/);
                if (m)
                    root.brightness = parseInt(m[1]);
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    component IconChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        signal toggled()

        width: 26 * root.s
        height: 26 * root.s
        radius: 8 * root.s
        color: chip.on ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: chip.on ? Theme.frameBorder : Theme.border

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: chip.glyph
            color: chip.on ? Theme.vermLit : Theme.iconDim
            stroke: 1.7
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "調"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MIXER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s
            IconChip {
                glyph: "dnd"
                on: Flags.dnd
                onToggled: Flags.dnd = !Flags.dnd
            }
            IconChip {
                glyph: "awake"
                on: Flags.keepAwake
                onToggled: Flags.keepAwake = !Flags.keepAwake
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Row {
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 130 * root.s
        spacing: 0

        VFader {
            id: brFader
            width: parent.width / 4
            s: root.s
            icon: "sun"
            focused: root.focusIndex === 0
            value: root.brightness / 100
            valueLabel: root.brightness + "%"
            onMoved: (v) => root.brightness = Math.round(v * 100)
            onCommitted: (v) => { root.pendingBrightness = v * 100; brDebounce.restart(); }
        }
        VFader {
            id: vibFader
            width: parent.width / 4
            s: root.s
            icon: "monitor"
            focused: root.focusIndex === 1
            value: root.vibrance / 100
            valueLabel: root.vibrance + "%"
            onMoved: (v) => root.vibrance = Math.round(v * 100)
            onCommitted: (v) => { root.pendingVibrance = v * 100; vibDebounce.restart(); }
        }
        VFader {
            id: volFader
            width: parent.width / 4
            s: root.s
            icon: "speaker"
            focused: root.focusIndex === 2
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueLabel: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
            onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
        }
        VFader {
            id: micFader
            width: parent.width / 4
            s: root.s
            icon: (root.source && root.source.audio && root.source.audio.muted) ? "mic-off" : "mic"
            focused: root.focusIndex === 3
            value: root.source && root.source.audio ? root.source.audio.volume : 0
            valueLabel: (root.source && root.source.audio && root.source.audio.muted)
                ? "off"
                : (Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%")
            onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }

            MouseArea {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * root.s
                height: 22 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
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
            if (notches !== 0 && root.stepFocused(notches))
                acc -= notches;
            event.accepted = true;
        }
    }
}
