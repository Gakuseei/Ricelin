import QtQuick
import "Singletons"

/**
 * Shared morph-surface contract for the pill's standard surfaces. Each surface
 * fills the pill body inset by its own margins (scaled by `s`), fades in with
 * the morph as it nears full openness, and is only enabled while open. A surface
 * sets `open`, `s` and `morphCloseness` from the host plus its own `mTop`/`mLeft`/
 * `mRight`/`mBottom` insets; `active` mirrors `open` for the legacy
 * `onActiveChanged` hooks. `requestClose()` is the surface's ask to dismiss the
 * pill. The mode-string surfaces (Osd, Toast) use a different lifecycle and do
 * not derive from this base.
 */
Item {
    id: surface

    property real s: 1
    property bool open: false
    property real morphCloseness: 1

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()

    /**
     * Ame anchor contract. Each surface declares the flame's form and the dock
     * point (in surface-local coordinates) for its own open state; the host maps
     * the point into pill space and feeds the active surface's pair to Ame. Plain
     * (non-readonly) so a deriving surface can re-bind them; the base default is
     * the off state at the surface centre.
     */
    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    enabled: open
    opacity: open ? Math.pow(morphCloseness, 1.3) : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
}
