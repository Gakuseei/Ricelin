import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Hand-drawn wifi glyph: three concentric arcs over a base dot, the lit-arc
 * count standing in for signal strength (>0.66 lights all three, >0.33 two,
 * >0 one). Lit strokes use iconDim, unlit a dim icon tint, so a radio-on but
 * unconnected glyph reads as a dim fan. When the radio is off the glyph fades
 * further and a diagonal slash crosses it. Paths live in a 24x24 space; the
 * arcs-and-dot bounding box is centred within the item on both axes, and the
 * off-state slash rides the same transform so it stays registered with them.
 * Every stroke weight scales by `s`.
 */
Item {
    id: root

    property real s: 1
    property real level: 0
    property bool on: true

    /**
     * Stroke weight in 24-space units, 0 keeps the legacy screen-constant
     * weight (2*s px). Pass 1.7 where the glyph sits next to GlyphIcon family
     * members (their stroke is 1.7 in 24-space), like the hover-pill glance.
     */
    property real stroke: 0

    implicitWidth: 17 * s
    implicitHeight: 17 * s

    readonly property int litCount: !on ? 0 : (level > 0.66 ? 3 : (level > 0.33 ? 2 : (level > 0 ? 1 : 0)))
    readonly property color offColor: on ? Qt.alpha(Theme.iconDim, 0.4) : Qt.alpha(Theme.iconDim, 0.18)
    readonly property real arcStroke: root.stroke > 0 ? root.stroke : (2 / root.u) * root.s

    readonly property real u: Math.min(width, height) / 24

    readonly property real glyphX: arcs.boundingRect.width > 0
        ? root.width / 2 - (arcs.boundingRect.x + arcs.boundingRect.width / 2) * root.u
        : (root.width - 24 * root.u) / 2
    readonly property real glyphY: arcs.boundingRect.height > 0
        ? root.height / 2 - (arcs.boundingRect.y + arcs.boundingRect.height / 2) * root.u
        : (root.height - 24 * root.u) / 2

    Shape {
        id: arcs

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: root.glyphX
        y: root.glyphY
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.litCount >= 1 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: root.arcStroke
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M9.17 13.17 A4 4 0 0 1 14.83 13.17" }
        }
        ShapePath {
            strokeColor: root.litCount >= 2 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: root.arcStroke
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M6.34 10.34 A8 8 0 0 1 17.66 10.34" }
        }
        ShapePath {
            strokeColor: root.litCount >= 3 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: root.arcStroke
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M3.5 7.5 A12 12 0 0 1 20.5 7.5" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.litCount >= 1 ? Theme.iconDim : root.offColor
            PathSvg { path: "M12 14.1 A1.5 1.5 0 0 1 12 17.1 A1.5 1.5 0 0 1 12 14.1z" }
        }
    }

    Shape {
        id: slash

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: root.glyphX
        y: root.glyphY
        visible: !root.on
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.faint
            fillColor: "transparent"
            strokeWidth: root.stroke > 0 ? root.stroke : (1.7 / root.u) * root.s
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M4 3 L20 19" }
        }
    }
}
