import QtQuick
import Quickshell.Hyprland
import "Singletons"

/**
 * The real pill at rest or hovered, drawn live from the flags at real size without a screen or host; nothing it shows can fire an action.
 */
Item {
    id: root

    /** "rest" or "hover". */
    property string mode: "rest"
    property real s: Flags.uiScale

    /** False leaves it mouse-inert; true lets icons show their hover tint. */
    property bool interactive: false

    /** Whose workspaces the preview shows; the focused monitor by default. */
    property string screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    readonly property bool hover: mode === "hover"

    implicitWidth: hover ? metrics.hoverWidth(modules.implicitWidth) : metrics.restWidth(modules.implicitWidth)
    implicitHeight: hover ? metrics.hoverH : metrics.restH
    enabled: interactive

    PillMetrics {
        id: metrics
        s: root.s
    }

    PillBody {
        anchors.fill: parent
        s: root.s
        radius: metrics.restCorner
    }

    ModuleRow {
        id: modules
        anchors.centerIn: parent
        ids: root.hover ? Flags.hoverModules : Flags.idleModules
        phase: root.hover ? "hover" : "rest"
        s: root.s
        screenName: root.screenName
        live: root.interactive
        actions: false
    }
}
