pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Clipboard: filterable cliphist history; Enter copies, hover or Ctrl+X deletes a row, holding 掃 wipes everything.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    property string query: ""
    property int selectedIndex: 0

    /** Last pointer position that moved the selection, so rows sliding under a still cursor never steal it. */
    property point lastPointer: Qt.point(-1, -1)

    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void search.input.width;
        return search.input.mapToItem(root,
            search.input.cursorRectangle.x + search.input.cursorRectangle.width / 2,
            search.input.cursorRectangle.y + search.input.cursorRectangle.height / 2);
    }
    readonly property real caretX: caretPoint.x
    readonly property real caretY: caretPoint.y

    ameForm: "caret"
    amePoint: Qt.point(caretX, caretY)

    readonly property var results: {
        var all = Cliphist.entries;
        var q = query.trim().toLowerCase();
        if (!q.length)
            return all;
        var out = [];
        for (var i = 0; i < all.length; i++) {
            var hay = (all[i].isImage ? all[i].label + " " + all[i].sizeLabel : all[i].preview).toLowerCase();
            if (hay.indexOf(q) !== -1)
                out.push(all[i]);
        }
        return out;
    }

    /** Rows sit on one grid: a text row is one unit, an image row two, so the viewport always ends on a row edge. */
    readonly property real rowGap: 2 * s
    readonly property real unit: 28 * s
    readonly property int unitsFit: Math.max(0, Math.floor((height - list.y + rowGap) / (unit + rowGap)))

    function focusField() { search.input.forceActiveFocus(); }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        Cliphist.copy(results[selectedIndex]);
        root.requestClose();
    }

    function removeAt(index) {
        if (index < 0 || index >= results.length)
            return;
        Cliphist.remove(results[index]);
    }

    onActiveChanged: {
        if (active) {
            query = "";
            search.text = "";
            selectedIndex = 0;
            Cliphist.refresh();
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = Math.max(0, results.length - 1)

    SearchField {
        id: search
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        kanji: "控"
        placeholder: "Search clipboard"
        counterText: root.results.length + " / " + Cliphist.count
        onTextChanged: {
            root.query = text;
            root.selectedIndex = 0;
        }
        onMoved: (d) => root.move(d)
        onAccepted: root.activate()
        onDismissed: root.requestClose()
        onKeyPressed: (e) => {
            if (e.key === Qt.Key_X && (e.modifiers & Qt.ControlModifier)
                && search.input.selectedText.length === 0) {
                root.removeAt(root.selectedIndex);
                e.accepted = true;
            }
        }

        Item {
            id: wipeBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s

            readonly property real hold: wipeHeat.hold
            readonly property bool holding: wipeHeat.holding
            readonly property color tone: holding ? Theme.vermLit : (wipeArea.containsMouse ? Theme.cream : Theme.textFaint)

            Tooltip {
                s: root.s
                placement: "below"
                title: "Hold to clear history"
                show: wipeArea.containsMouse || wipeBtn.holding
            }

            Text {
                visible: Flags.showGlyphs
                anchors.centerIn: parent
                text: "掃"
                color: wipeBtn.tone
                font.family: Theme.fontJp
                font.pixelSize: 12 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            GlyphIcon {
                visible: !Flags.showGlyphs
                anchors.centerIn: parent
                width: 12 * root.s
                height: 12 * root.s
                name: "trash"
                color: wipeBtn.tone
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            HeatHold {
                id: wipeHeat
                onConfirmed: Cliphist.wipe()
            }

            MouseArea {
                id: wipeArea
                anchors.fill: parent
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: wipeHeat.press()
                onReleased: wipeHeat.release()
                onExited: wipeHeat.cancel()
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width * wipeBtn.hold
            visible: wipeBtn.holding
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(Theme.vermLit, 0.15) }
                GradientStop { position: 1.0; color: Theme.vermLit }
            }
        }
    }

    EmptyState {
        anchors.horizontalCenter: parent.horizontalCenter
        y: list.y + Theme.sp.l * root.s
        visible: root.results.length === 0 && (root.query.length > 0 || Cliphist.loaded)
        s: root.s
        glyph: "type"
        text: root.query.length ? "No matches" : "Clipboard is empty"
    }

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.unitsFit * root.unit + Math.max(0, root.unitsFit - 1) * root.rowGap
        spacing: root.rowGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        model: root.results.length

        delegate: Item {
            id: row
            required property int index
            width: list.width
            height: entry && entry.isImage ? 2 * root.unit + root.rowGap : root.unit

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex

            HoverHandler {
                id: rowHover
                onPointChanged: {
                    if (!hovered)
                        return;
                    var sp = point.scenePosition;
                    if (sp.x !== root.lastPointer.x || sp.y !== root.lastPointer.y) {
                        root.lastPointer = Qt.point(sp.x, sp.y);
                        root.selectedIndex = row.index;
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.r.m * root.s
                visible: row.selected || rowHover.hovered
                color: rowArea.pressed ? Theme.hair : (row.selected ? Theme.frameBg : Qt.alpha(Theme.cream, 0.03))
                border.width: row.selected ? 1 : 0
                border.color: Theme.frameBorder
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedIndex = row.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp.m * root.s
                anchors.rightMargin: Theme.sp.m * root.s

                Rectangle {
                    id: thumbTile
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.entry !== undefined && row.entry.isImage
                    width: visible ? 72 * root.s : 0
                    height: 44 * root.s
                    radius: Theme.r.s * root.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: thumbTile.visible ? "file://" + row.entry.thumb : ""
                        sourceSize.width: 128
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: thumbTile.visible ? thumbTile.right : parent.left
                    anchors.leftMargin: thumbTile.visible ? Theme.sp.m * root.s : 0
                    anchors.right: sizeTag.left
                    anchors.rightMargin: 8 * root.s
                    text: row.entry === undefined ? "" : (row.entry.isImage ? row.entry.label : row.entry.preview)
                    color: row.entry !== undefined && row.entry.isImage
                        ? (row.selected ? Theme.subtle : Theme.textFaint)
                        : (row.selected ? Theme.cream : Theme.subtle)
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    font.weight: row.selected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }

                Text {
                    id: sizeTag
                    anchors.right: tail.left
                    anchors.rightMargin: width > 0 ? 8 * root.s : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.entry !== undefined && row.entry.isImage ? row.entry.sizeLabel : ""
                    width: text.length ? implicitWidth : 0
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.features: { "tnum": 1 }
                }

                Item {
                    id: tail
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(ret.implicitWidth, dismiss.implicitWidth)
                    height: Math.max(ret.implicitHeight, dismiss.implicitHeight)

                    Text {
                        id: ret
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: row.selected && !rowHover.hovered ? 1 : 0
                        text: "↵"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    GlyphIcon {
                        id: dismiss
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 11 * root.s
                        implicitHeight: 11 * root.s
                        width: implicitWidth
                        height: implicitHeight
                        opacity: rowHover.hovered ? 1 : 0
                        name: "close"
                        stroke: 2
                        color: dismissArea.containsMouse ? Theme.vermLit : Theme.iconDim
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: dismissArea
                            anchors.fill: parent
                            anchors.margins: -6 * root.s
                            enabled: rowHover.hovered
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeAt(row.index)
                        }
                    }
                }
            }
        }
    }

    WheelScroller {
        anchors.fill: list
        s: root.s
        flick: list
    }
}
