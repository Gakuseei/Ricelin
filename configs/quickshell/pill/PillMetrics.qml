import QtQuick
import "Singletons"

/**
 * Pill shape numbers from the shape flags, shared by the pill and its settings preview; hover height and open corners keep today's 58/38 and 22/18 ratios.
 */
QtObject {
    property real s: 1

    readonly property real baseH: Math.max(24, Math.min(64, Flags.pillHeight))
    readonly property real restH: baseH * s
    readonly property real hoverH: restH * 58 / 38
    readonly property real restW: Math.max(0, Flags.idleWidth) * s
    readonly property real restPad: 18 * s
    readonly property real hoverPad: 20 * s
    readonly property real restCorner: Math.max(0, Math.min(Flags.pillRounding, baseH / 2)) * s
    readonly property real openCorner: restCorner * 22 / 18

    function restWidth(rowW) {
        return Math.max(restW, rowW + 2 * restPad);
    }

    function hoverWidth(rowW) {
        return rowW + 2 * hoverPad;
    }
}
