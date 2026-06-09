pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * The single living flame — the only glowing element in the shell. It orbits the
 * pill's rounded-rectangle edge on a continuous fading trail and flickers. With
 * music it wakes (faster orbit, audio-driven pulse, full brightness); without
 * music it sleeps (slow orbit, dimmed). In "held" mode it parks where it sits and
 * keeps pulsing so the pill can turn it into a click target. "fly" arcs the flame
 * to a target along a quadratic bezier; "off" hides it.
 */
Item {
    id: root

    property real s: 1
    property real pillW: 160
    property real pillH: 38
    property string mode: "orbit"
    property bool musicActive: false
    property real pulse: 0
    property point flyTarget: Qt.point(0, 0)
    signal flightDone()

    readonly property real perim: 2 * (pillW - pillH) + Math.PI * pillH
    property real t: 0.1
    property real px: 0
    property real py: 0
    visible: mode !== "off"

    function pathPoint(tt) {
        const r = pillH / 2;
        const a = pillW - 2 * r;
        let sLen = (((tt % 1) + 1) % 1) * perim;
        if (sLen < a) return Qt.point(r + sLen, 0);
        sLen -= a;
        if (sLen < Math.PI * r) {
            const p = sLen / r;
            return Qt.point((pillW - r) + r * Math.sin(p), r - r * Math.cos(p));
        }
        sLen -= Math.PI * r;
        if (sLen < a) return Qt.point(pillW - r - sLen, pillH);
        const q = (sLen - a) / r;
        return Qt.point(r - r * Math.sin(q), r + r * Math.cos(q));
    }

    property var hist: []
    function pushHistory() {
        hist.unshift(Qt.point(px, py));
        if (hist.length > 24) hist.pop();
        histChanged();
    }

    property real flyT: 0
    property point flyStart: Qt.point(0, 0)
    property point flyCtrl: Qt.point(0, 0)

    onModeChanged: {
        if (mode === "fly") {
            flyStart = Qt.point(px, py);
            flyCtrl = Qt.point((px + flyTarget.x) / 2, Math.min(py, flyTarget.y) - pillH);
            flyT = 0;
            flyAnim.restart();
        }
    }

    NumberAnimation {
        id: flyAnim
        target: root
        property: "flyT"
        from: 0
        to: 1
        duration: Motion.flight
        easing.type: Motion.easeMorph
        onFinished: root.flightDone()
    }

    FrameAnimation {
        running: root.visible && (root.mode === "orbit" || root.mode === "held")
        onTriggered: {
            if (root.mode === "orbit")
                root.t += frameTime * (root.musicActive ? 0.085 : 0.03);
            const p = root.pathPoint(root.t);
            root.px = p.x;
            root.py = p.y;
            root.pushHistory();
        }
    }

    onFlyTChanged: {
        if (mode !== "fly") return;
        const u = 1 - flyT;
        px = u * u * flyStart.x + 2 * u * flyT * flyCtrl.x + flyT * flyT * flyTarget.x;
        py = u * u * flyStart.y + 2 * u * flyT * flyCtrl.y + flyT * flyT * flyTarget.y;
    }

    Repeater {
        model: 6
        delegate: Rectangle {
            id: trailDot
            required property int index

            readonly property int slot: index * 3
            readonly property var pt: root.hist.length > slot ? root.hist[slot] : null
            readonly property real f: index / 6
            readonly property real sz: (5 - 3.4 * f) * root.s

            visible: pt !== null && root.mode !== "fly"
            width: sz
            height: sz
            radius: sz / 2
            antialiasing: true
            x: pt ? pt.x - sz / 2 : 0
            y: pt ? pt.y - sz / 2 : 0
            color: Qt.rgba(Theme.flameGlow.r, Theme.flameGlow.g, Theme.flameGlow.b,
                           Math.pow(1 - f, 1.7) * 0.85)
        }
    }

    Rectangle {
        id: head
        readonly property real sz: (6 + 3 * root.pulse) * root.s
        width: sz
        height: sz
        radius: sz / 2
        antialiasing: true
        x: root.px - sz / 2
        y: root.py - sz / 2
        color: Theme.flameCore
        opacity: (root.musicActive || root.mode !== "orbit") ? 1 : 0.45

        SequentialAnimation on scale {
            running: root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.88; to: 1.06; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.06; to: 0.88; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 0.42
        blurMax: 10
    }
}
