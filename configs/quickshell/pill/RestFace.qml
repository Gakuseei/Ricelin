import QtQuick
import "Singletons"

/**
 * The resting pill: the modules from `Flags.idleModules`, by default the 時 glyph, the clock and a running activity, or the special workspace's name.
 */
Face {
    id: face

    mode: "rest"

    readonly property real s: host.s
    readonly property real rowWidth: face.host.specialView !== "" ? special.implicitWidth : modules.implicitWidth

    /**
     * Ame's rest anchor: the glyph centre, where the idle outline condenses into the bead; the row centre without a glyph.
     */
    readonly property point wakePoint: {
        void host.width;
        void host.height;
        const g = modules.glyphItem;
        if (g)
            return g.mapToItem(face, g.width / 2, g.height / 2);
        return modules.mapToItem(face, modules.width / 2, modules.height / 2);
    }

    ModuleRow {
        id: modules
        anchors.centerIn: parent
        visible: face.host.specialView === ""
        ids: Flags.idleModules
        phase: "rest"
        host: face.host
        s: face.s
        screenName: face.host.screenName
        barWindow: face.host.barWindow
        live: face.live
    }

    Text {
        id: special
        anchors.centerIn: parent
        visible: face.host.specialView !== ""
        text: face.host.specialView
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 16 * face.s
        font.weight: Font.DemiBold
    }
}
