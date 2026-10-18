pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * App manager for a user-defined special workspace (the one named by
 * Spaces.editing). The same two-view shape as Stash: the list view shows each
 * routed window class as an app tile with friendly name and faint raw-class
 * subtitle and a ✕ to drop it, capped by a dashed "add app" bar; the add view
 * swaps in the launcher's fuzzy picker whose pick derives a window class from the
 * entry's StartupWMClass. Reads and writes through the Spaces singleton, which
 * owns spaces.lua and fires the debounced reload — this surface holds no file.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    ameForm: "off"

    readonly property var editingSpace: {
        var sl = Spaces.list;
        for (var i = 0; i < sl.length; i++)
            if (sl[i] && sl[i].id === Spaces.editing)
                return sl[i];
        return null;
    }
    readonly property var entries: editingSpace ? editingSpace.apps : []
    readonly property string spaceName: editingSpace && editingSpace.name ? editingSpace.name : "SPACE"

    /** Pill.qml folds the picker back when the surface leaves */
    readonly property alias addOpen: content.addOpen
    function closeAdd() { content.closeAdd(); }

    function removeAt(i) {
        if (i < 0 || i >= root.entries.length)
            return;
        Spaces.removeApp(Spaces.editing, root.entries[i]);
    }

    function addClass(cls) {
        if (cls && cls.length > 0)
            Spaces.addApp(Spaces.editing, cls);
        content.closeAdd();
    }

    onActiveChanged: content.closeAdd()

    AppRouteList {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        glyph: "場"
        title: root.spaceName
        emptyText: "No apps routed here yet"
        entries: root.entries
        onRemoved: (i) => root.removeAt(i)
        onPicked: (entry) => root.addClass(entry.startupClass || entry.id)
    }
}
