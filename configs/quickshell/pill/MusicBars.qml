pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Rest-pill spectrum in the clock-glyph slot; heights chase cava with a short ease so they never strobe.
 */
Row {
    id: root

    property real s: 1
    property real span: 18

    height: span * s
    spacing: 1.2 * s

    Repeater {
        model: Cava.bars

        Rectangle {
            required property int index

            width: 1.8 * root.s
            radius: width / 2
            anchors.bottom: parent.bottom
            height: Math.max(2 * root.s, (Cava.levels[index] || 0) * root.span * root.s)

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.flameGlow }
                GradientStop { position: 1.0; color: Theme.vermLit }
            }

            Behavior on height {
                NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad }
            }
        }
    }
}
