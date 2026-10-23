pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/** Body of the class-routing surfaces (Stash, SpaceApps); the surface owns the data and gets removed(index) / picked(entry). */
Column {
    id: body

    property real s: 1
    property string glyph: ""
    property string title: ""
    property string emptyText: ""
    property var entries: []

    readonly property real rowH: 46 * s
    readonly property int maxRows: 5

    /** Keyboard row: 0..entries-1 are apps, entries.length is the add bar. */
    property int focusIndex: 0

    readonly property alias addOpen: picker.addOpen
    function closeAdd() { picker.closeAdd(); }
    function normalizeClass(cls) { return picker.normalizeClass(cls); }

    /** A window-class pattern as a readable name: "[Ss]potify" reads "Spotify". */
    function className(cls) {
        return String(cls).replace(/\[(.)(.)\]/g, "$1").replace(/[\^$\\]|\.\*/g, "");
    }

    function handleKey(e) {
        if (picker.addOpen)
            return false;
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            body.focusIndex = Math.max(0, Math.min(body.entries.length, body.focusIndex + (e.key === Qt.Key_Up ? -1 : 1)));
            if (body.focusIndex < body.entries.length)
                list.positionViewAtIndex(body.focusIndex, ListView.Contain);
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (!e.isAutoRepeat && body.focusIndex >= body.entries.length)
                picker.openAdd();
        } else if (e.key === Qt.Key_Delete) {
            if (body.focusIndex < body.entries.length)
                body.removed(body.focusIndex);
        } else
            return false;
        return true;
    }

    signal removed(int index)
    signal picked(var entry)

    onEntriesChanged: if (focusIndex > entries.length) focusIndex = entries.length

    spacing: 0

    SurfaceHeader {
        s: body.s
        glyph: body.glyph
        title: body.title
        crumb: picker.addOpen ? "Add app" : ""
        canBack: true
    }

    Item { width: 1; height: Theme.sp.s * body.s }

    EmptyState {
        width: parent.width
        visible: !picker.addOpen && body.entries.length === 0
        s: body.s
        glyph: "app-window"
        text: body.emptyText
    }

    ListView {
        id: list
        width: parent.width
        height: visible ? Math.min(body.entries.length, body.maxRows) * body.rowH : 0
        visible: !picker.addOpen && body.entries.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        model: body.entries

        delegate: Item {
            id: erow
            required property int index
            required property string modelData

            readonly property var resolved: {
                void picker.allApps;
                return picker.resolveEntry(modelData);
            }
            readonly property string title: resolved && resolved.name ? resolved.name : body.className(modelData)
            readonly property bool focused: body.focusIndex === erow.index

            width: ListView.view.width
            height: body.rowH

            HoverHandler {
                id: rowHover
                onHoveredChanged: if (hovered) body.focusIndex = erow.index
            }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 3 * body.s
                anchors.bottomMargin: 3 * body.s
                radius: Theme.r.m * body.s
                color: erow.focused || rowHover.hovered ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: erow.focused || rowHover.hovered ? Theme.frameBorder : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                id: tile
                anchors.left: parent.left
                anchors.leftMargin: 10 * body.s
                anchors.verticalCenter: parent.verticalCenter
                width: 28 * body.s
                height: 28 * body.s
                radius: Theme.r.s * body.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.hairSoft

                Text {
                    anchors.centerIn: parent
                    visible: !icon.visible
                    text: erow.title.length > 0 ? erow.title.charAt(0).toUpperCase() : "?"
                    color: Theme.iconDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * body.s
                    font.weight: Font.DemiBold
                }

                Image {
                    id: icon
                    anchors.fill: parent
                    anchors.margins: Theme.sp.xs * body.s
                    sourceSize.width: Math.round(40 * body.s)
                    sourceSize.height: Math.round(40 * body.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: erow.resolved && erow.resolved.icon ? Quickshell.iconPath(erow.resolved.icon, true) : ""
                }
            }

            Text {
                id: nameText
                anchors.left: tile.right
                anchors.leftMargin: Theme.sp.m * body.s
                anchors.right: removeBtn.left
                anchors.rightMargin: Theme.sp.s * body.s
                anchors.verticalCenter: parent.verticalCenter
                text: erow.title
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.body * body.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            /** The raw window-class match, only while hovered, over the free space right of the name. */
            Text {
                anchors.right: removeBtn.left
                anchors.rightMargin: Theme.sp.s * body.s
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(implicitWidth, removeBtn.x - nameText.x - nameText.contentWidth - 2 * Theme.sp.m * body.s))
                visible: erow.modelData !== erow.title
                opacity: rowHover.hovered ? 1 : 0
                text: erow.modelData
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * body.s
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                id: removeBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp.s * body.s
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * body.s
                height: 26 * body.s
                radius: Theme.r.s * body.s
                scale: removeArea.pressed && !Motion.calm ? 0.94 : 1
                color: removeArea.containsMouse ? Qt.alpha(Theme.verm, removeArea.pressed ? 0.26 : 0.16) : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 13 * body.s
                    height: 13 * body.s
                    name: "close"
                    color: removeArea.containsMouse ? Theme.vermLit : Theme.iconDim
                    stroke: 2
                }

                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: body.removed(erow.index)
                }
            }
        }
    }

    Item { width: 1; height: visible ? 6 * body.s : 0; visible: !picker.addOpen }

    AppPickerList {
        id: picker
        width: parent.width
        s: body.s
        barLit: body.focusIndex >= body.entries.length
        onPicked: (entry) => body.picked(entry)
    }

    Item { width: 1; height: Theme.sp.xs * body.s }
}
