import QtQuick
import "Singletons"

/**
 * Wheel-to-Flickable bridge for layer surfaces: notches glide to a summed goal, touchpad pixels move 1:1.
 */
MouseArea {
    id: root

    property real s: 1
    required property Flickable flick
    property real goal: 0

    acceptedButtons: Qt.NoButton

    function clamped(y) {
        return Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y));
    }

    onWheel: function(event) {
        event.accepted = true;
        if (event.pixelDelta.y !== 0 || Motion.calm) {
            chase.running = false;
            flick.contentY = clamped(flick.contentY - (event.pixelDelta.y || event.angleDelta.y / 120 * 36 * s));
            return;
        }
        if (!chase.running)
            goal = flick.contentY;
        goal = clamped(goal - event.angleDelta.y / 120 * 36 * s);
        chase.running = true;
    }

    FrameAnimation {
        id: chase
        onTriggered: {
            const d = root.goal - root.flick.contentY;
            if (Math.abs(d) < 0.5) {
                root.flick.contentY = root.goal;
                running = false;
                return;
            }
            root.flick.contentY += d * (1 - Math.exp(-frameTime / 0.07));
        }
    }
}
