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

    /** True hops between rest and hover on the pill's own springs and face fades; false jumps. */
    property bool animated: false

    /** Whose workspaces the preview shows; the focused monitor by default. */
    property string screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    readonly property bool hover: mode === "hover"
    readonly property real targetW: hover ? metrics.hoverWidth(hoverRow.implicitWidth) : metrics.restWidth(restRow.implicitWidth)
    readonly property real targetH: hover ? metrics.hoverH : metrics.restH

    /** Faces read this the way they read the pill's: 1 once the shape has arrived. */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    implicitWidth: springs.item ? springs.item.w : targetW
    implicitHeight: springs.item ? springs.item.h : targetH
    enabled: interactive

    PillMetrics {
        id: metrics
        s: root.s
    }

    Loader {
        id: springs
        active: root.animated

        sourceComponent: QtObject {
            readonly property real w: springW.value
            readonly property real h: springH.value
            readonly property bool snappy: Flags.springFeel === "snappy"

            property Spring springW: Spring {
                target: root.targetW
                response: snappy ? 0.19 : 0.26
            }
            property Spring springH: Spring {
                target: root.targetH
                response: snappy ? 0.19 : 0.26
            }

            Component.onCompleted: {
                springW.snap(root.targetW);
                springH.snap(root.targetH);
            }
        }
    }

    PillBody {
        anchors.fill: parent
        s: root.s
        radius: metrics.restCorner
    }

    Face {
        id: restFace
        host: root
        mode: "rest"

        ModuleRow {
            id: restRow
            anchors.centerIn: parent
            ids: root.animated || !root.hover ? Flags.idleModules : []
            phase: "rest"
            s: root.s
            screenName: root.screenName
            live: root.interactive && restFace.live
            actions: false
            awake: restFace.opacity > 0.01
        }
    }

    Face {
        id: hoverFace
        host: root
        mode: "hover"

        ModuleRow {
            id: hoverRow
            anchors.centerIn: parent
            ids: root.animated || root.hover ? Flags.hoverModules : []
            phase: "hover"
            s: root.s
            screenName: root.screenName
            live: root.interactive && hoverFace.live
            actions: false
            awake: hoverFace.opacity > 0.01
        }
    }
}
