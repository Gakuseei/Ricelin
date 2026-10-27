import QtQuick
import "Singletons"

/**
 * The hover bar: the modules from `Flags.hoverModules`, by default workspaces, clock and date, and the status icons that open their surfaces.
 */
Face {
    id: face

    mode: "hover"
    exitMs: 90
    visible: true

    readonly property real s: host.s
    readonly property alias rowWidth: modules.implicitWidth

    /**
     * Ame's dock while hovered: under the hovered icon or dot, else under the active workspace, else under the row.
     */
    readonly property point soulPoint: {
        void host.width;
        void host.height;
        const drop = 12 * s;
        const it = host.soulItem;
        if (it)
            return it.mapToItem(face, it.width / 2, it.height + drop * 0.55);
        const ws = modules.wsItem;
        if (!ws)
            return modules.mapToItem(face, modules.width / 2, modules.height + drop * 0.55);
        void ws.activeName;
        void ws.width;
        if (host.soulWsIndex >= 0) {
            const p = ws.mapToItem(face, ws.slotCenterX(host.soulWsIndex), ws.height / 2);
            return Qt.point(p.x, p.y + drop);
        }
        return ws.mapToItem(face, ws.activeDotPoint.x, ws.activeDotPoint.y + drop);
    }

    ModuleRow {
        id: modules
        anchors.centerIn: parent
        ids: Flags.hoverModules
        phase: "hover"
        host: face.host
        s: face.s
        screenName: face.host.screenName
        barWindow: face.host.barWindow
        live: face.live
        awake: face.live || face.opacity > 0.01
    }
}
