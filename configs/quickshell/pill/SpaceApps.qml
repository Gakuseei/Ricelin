pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Apps routed into the custom space named by Spaces.editing; Spaces owns spaces.lua and the reload.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

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
    readonly property string spaceName: editingSpace && editingSpace.name ? editingSpace.name : "Space"

    readonly property alias addOpen: content.addOpen
    function closeAdd() { content.closeAdd(); }
    function back() {
        if (!addOpen)
            return false;
        closeAdd();
        return true;
    }
    function handleKey(e) { return content.handleKey(e); }

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

    onActiveChanged: {
        content.closeAdd();
        content.focusIndex = 0;
    }

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
