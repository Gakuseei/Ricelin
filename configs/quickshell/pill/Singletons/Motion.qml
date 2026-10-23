pragma Singleton
import QtQuick
import Quickshell

Singleton {
    /**
     * Reduce motion: nothing travels, bounces or loops; things fade in place at their normal pace.
     */
    readonly property bool calm: Flags.reduceMotion
    readonly property int fast:     140
    readonly property int standard: 300
    readonly property int morph:    420
    readonly property int shapeshift: 520
    readonly property int glide:    260
    readonly property int heat:     1100
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline

    /**
     * Liquid morph curve cubic-bezier(0.16, 1, 0.3, 1) with a long visible settle tail, for use with easeMorph (BezierSpline).
     */
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    /**
     * Content opacity for a morph closeness: nothing until the shape is near, then a smooth rise.
     */
    function reveal(p) {
        const t = Math.max(0, Math.min(1, (p - 0.35) / 0.5));
        return t * t * (3 - 2 * t);
    }

    readonly property real rSmall: 7
    readonly property real rTile:  13

    readonly property int pulse: 420
}
