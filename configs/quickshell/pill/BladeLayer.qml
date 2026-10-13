pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

/**
 * The corner launcher window: one per screen, a click-through overlay that only
 * accepts input over the bead (closed) or over the fan (open). It sits in the
 * top-left corner.
 *
 * It behaves like the pill. Resting on the bead for a beat opens the fan, the
 * pointer leaving lets it close again after a short grace, and a click on the
 * bead pins it open until the next click. The pointer is read from one
 * window-level HoverHandler: events only exist inside the input mask, so
 * "the window is hovered" means "the pointer is over the bead or the fan".
 */
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1

    color: "transparent"
    visible: true
    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ricelin-blades"

    // Only as large as the fan, in the top-left corner. If the dock is set to the
    // left edge the fan starts just past it, so the two can never overlap.
    anchors { top: true; left: true }
    margins { left: Dock.onRight ? 0 : Math.round((Dock.footprintPx + 12) * root.s) }
    implicitWidth: Math.ceil(fan.extent)
    implicitHeight: Math.ceil(fan.extent)

    property bool hoverLatch: false
    property bool pinned: false
    readonly property bool open: pinned || hoverLatch

    /**
     * False for the first seconds after the shell maps. Hyprland hands pointer
     * focus to a freshly mapped layer surface at the cursor, which would read as
     * a hover and open the fan by itself. A real hover in that window just opens
     * a moment late.
     */
    property bool bootSettled: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.bootSettled = true
    }

    /** Input envelope: the bead while closed, a disc around the origin while open. The rest of the screen stays click-through. */
    readonly property real maskReach: root.open ? fan.reach : fan.beadSize / 2 + 4 * root.s
    mask: Region {
        x: fan.originX - root.maskReach
        y: fan.originY - root.maskReach
        width: root.maskReach * 2
        height: root.maskReach * 2
        shape: RegionShape.Ellipse
    }

    BladeLauncherModel { id: bladeModel }

    function collapse() {
        root.pinned = false;
        root.hoverLatch = false;
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: windowHover
            onHoveredChanged: {
                if (hovered) {
                    graceTimer.stop();
                    if (root.bootSettled)
                        intentTimer.restart();
                } else {
                    intentTimer.stop();
                    graceTimer.restart();
                }
            }
        }

        // Brushing past the corner must not open it; resting on the bead does.
        Timer {
            id: intentTimer
            interval: 120
            onTriggered: if (windowHover.hovered) root.hoverLatch = true
        }

        Timer {
            id: graceTimer
            interval: 300
            onTriggered: if (!windowHover.hovered) root.hoverLatch = false
        }

        BladeFan {
            id: fan
            anchors.fill: parent
            model: bladeModel
            s: root.s
            open: root.open
            onToggleRequested: root.pinned = !root.pinned
            onLaunched: root.collapse()
        }
    }
}
