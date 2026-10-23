pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Base of every settings surface; `rows` entries are seg, toggle, scrub or nav, and an optional `activate` overrides Enter and click.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    property Item focusRowItem: null
    property int kbIndex: -1
    property var rows: []

    function reportRowHover(item, hovered) {
        if (hovered) {
            focusRowItem = item;
            kbIndex = rowIndexOf(item);
        }
    }
    onActiveChanged: if (!active) {
        focusRowItem = null;
        kbIndex = -1;
    }

    function rowIndexOf(item) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].item === item)
                return i;
        return -1;
    }

    function segCycle(r, dir) {
        var n = r.vals.length;
        var i = r.vals.indexOf(r.get());
        r.set(r.vals[(((i < 0 ? 0 : i) + dir) % n + n) % n]);
    }

    function kbMove(dir) {
        if (!rows.length)
            return;
        kbIndex = Math.max(0, Math.min(rows.length - 1, (kbIndex < 0 ? 0 : kbIndex + dir)));
        focusRowItem = rows[kbIndex].item;
    }

    function kbAdjust(dir) {
        if (!rows.length)
            return;
        if (kbIndex < 0) {
            kbIndex = 0;
            focusRowItem = rows[0].item;
        }
        var r = rows[kbIndex];
        if (r.kind === "seg")
            segCycle(r, dir);
        else if (r.kind === "toggle")
            r.set(dir > 0);
        else if (r.kind === "scrub")
            r.bump(dir);
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down)
            kbMove(e.key === Qt.Key_Up ? -1 : 1);
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right)
            kbAdjust(e.key === Qt.Key_Left ? -1 : 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (!e.isAutoRepeat)
                kbActivate();
        } else
            return false;
        return true;
    }

    function kbActivate() {
        if (kbIndex < 0)
            return;
        var r = rows[kbIndex];
        if (typeof r.activate === "function")
            r.activate();
        else if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg")
            segCycle(r, 1);
    }

    function activateRow(item) {
        var idx = rowIndexOf(item);
        if (idx < 0)
            return;
        kbIndex = idx;
        focusRowItem = item;
        var r = rows[idx];
        if (typeof r.activate === "function")
            r.activate();
        else if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg")
            segCycle(r, 1);
    }

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint
}
