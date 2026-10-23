import QtQuick
import "Singletons"

/**
 * Base of every morphing surface: the pill sets s, open, morphCloseness and screenName, and routes keys, Esc and focus through the hooks below.
 */
Item {
    id: surface

    property real s: 1
    property bool open: false
    property real morphCloseness: 1
    property string screenName: ""

    /**
     * True while a field inside owns the keyboard; the shell takes focus back when it drops.
     */
    property bool holdsFocus: false

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()
    signal requestSurface(string name)

    /**
     * Esc and the header step back through these: return true when a nested form closed.
     */
    function back() { return false; }
    function handleKey(e) { return false; }
    function handleRelease(e) { return false; }

    /**
     * Where Ame docks while this surface is open, in surface coordinates; off at the centre by default.
     */
    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open

    /**
     * Holds full opacity once the open morph has settled, so a relayout inside never dims the surface.
     */
    property bool settled: false
    onMorphClosenessChanged: if (open && morphCloseness > 0.92) settled = true

    readonly property real enter: settled ? 1 : Math.min(gate, Motion.reveal(morphCloseness))
    readonly property real lift: open ? enter : 1
    property real exitFade: 0
    property real lastShown: 0

    /**
     * Set by the pill on every switch: slide is the side content moves toward, gate holds a swap-in until the old one is mostly gone.
     */
    property real slide: 0
    property real gate: 1
    function arrive(dir, swap) {
        slide = dir;
        gateIn.stop();
        gate = swap ? 0 : 1;
        if (swap)
            gateIn.start();
    }

    SequentialAnimation {
        id: gateIn
        PauseAnimation { duration: 90 }
        NumberAnimation { target: surface; property: "gate"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    enabled: open

    /**
     * Visible for as long as it is open: sizes inside read visibility, and tying it to the fade loops the morph.
     */
    opacity: open ? enter : exitFade
    visible: open || opacity > 0.01

    onOpacityChanged: if (open) lastShown = opacity
    onOpenChanged: {
        if (open) {
            fadeOut.stop();
        } else {
            settled = false;
            exitFade = lastShown;
            fadeOut.restart();
        }
    }

    transform: [
        Scale {
            readonly property bool closing: !surface.open && surface.slide === 0 && !Motion.calm
            origin.x: surface.width / 2
            origin.y: closing ? 0 : surface.height / 2
            xScale: closing ? 0.95 + 0.05 * surface.exitFade / Math.max(0.01, surface.lastShown) : 0.97 + 0.03 * surface.lift
            yScale: xScale
        },
        Translate {
            x: Motion.calm ? 0 : 12 * surface.s * surface.slide * (surface.open ? 1 - surface.lift : 1 - surface.exitFade / Math.max(0.01, surface.lastShown))
            y: Motion.calm ? 0 : -6 * surface.s * (1 - surface.lift)
        }
    ]

    NumberAnimation {
        id: fadeOut
        target: surface
        property: "exitFade"
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
    }
}
