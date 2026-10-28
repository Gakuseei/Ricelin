import QtQuick
import "Singletons"
import "lib/spring.js" as Sp

/**
 * A damped spring that keeps its velocity when the target moves, so an interrupted morph never jumps.
 */
QtObject {
    id: sp

    property real target: 0
    property real value: 0
    property real velocity: 0

    /**
     * Response is the undamped period in seconds; damping below 1 overshoots. Growth may use its own pair.
     */
    property real response: 0.34
    property real damping: 1
    property real growResponse: response
    property real growDamping: damping
    property bool growing: false
    readonly property bool running: frame.running

    function snap(v) {
        value = v;
        velocity = 0;
        frame.running = false;
    }

    /**
     * Starts from a value and velocity of the caller's choosing, e.g. a released drag.
     */
    function launch(from, vel, to) {
        if (Flags.reduceMotion) {
            target = to;
            snap(to);
            return;
        }
        value = from;
        velocity = vel;
        growing = to > from;
        target = to;
        frame.running = true;
    }

    /** Reduce motion: the shape jumps to its target and only the content fades. */
    onTargetChanged: {
        if (Flags.reduceMotion) {
            snap(target);
            return;
        }
        growing = target > value;
        frame.running = true;
    }

    function step(dt) {
        const g = growing;
        const z = g ? growDamping : damping;
        const xv = Sp.step(value - target, velocity, 2 * Math.PI / (g ? growResponse : response), z, dt);
        if (Math.abs(xv[0]) < 0.25 && Math.abs(xv[1]) < 2) {
            snap(target);
            return;
        }
        velocity = xv[1];
        value = target + xv[0];
    }

    property FrameAnimation frame: FrameAnimation {
        running: false
        onTriggered: sp.step(Math.min(frameTime, 1 / 30))
    }
}
