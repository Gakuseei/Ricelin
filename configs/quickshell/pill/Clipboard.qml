pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * Clipboard surface: a search field over the cliphist history, rendered as one
 * of the morphing pill's surfaces. Entries come from the warm Cliphist
 * singleton snapshot, so the list is populated the moment the pill finishes
 * morphing. Typing filters by substring, Return copies the selected entry back
 * to the clipboard and closes, hovering a row cross-fades a dismiss glyph that
 * deletes the entry (Ctrl+X does the same for the keyboard selection). Image
 * entries render their cached thumbnail beside the binary descriptor. Holding
 * the 掃 glyph for the heat duration wipes the entire history — press-and-hold
 * is the pill's native confirmation, mirroring the destructive power tiles;
 * progress sweeps along the header divider and drains on early release.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    property string query: ""
    property int selectedIndex: 0

    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void field.width;
        return field.mapToItem(root,
            field.cursorRectangle.x + field.cursorRectangle.width / 2,
            field.cursorRectangle.y + field.cursorRectangle.height / 2);
    }
    readonly property real caretX: caretPoint.x
    readonly property real caretY: caretPoint.y

    signal requestClose()

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

    function focusField() { field.forceActiveFocus(); }

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
            field.text = "";
            selectedIndex = 0;
            Cliphist.refresh();
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = Math.max(0, results.length - 1)

    Item {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30 * root.s

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            text: "控"
            color: Theme.dim
            font.family: Theme.fontJp
            font.weight: Font.Medium
            font.pixelSize: 16 * root.s
        }

        TextField {
            id: field
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: glyph.right
            anchors.leftMargin: 10 * root.s
            anchors.right: counter.left
            anchors.rightMargin: 10 * root.s
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 15 * root.s
            placeholderText: "Search clipboard"
            placeholderTextColor: Theme.faint
            selectByMouse: true
            selectionColor: Theme.verm
            onTextChanged: {
                root.query = text;
                root.selectedIndex = 0;
            }
            cursorDelegate: Item {}
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.activate();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    root.requestClose();
                    e.accepted = true;
                } else if (e.key === Qt.Key_X && (e.modifiers & Qt.ControlModifier)) {
                    root.removeAt(root.selectedIndex);
                    e.accepted = true;
                }
            }
        }

        Text {
            id: counter
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: wipeBtn.left
            anchors.rightMargin: 10 * root.s
            text: root.results.length + " / " + Cliphist.count
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.features: { "tnum": 1 }
        }

        Item {
            id: wipeBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: 16 * root.s
            height: 16 * root.s

            property real hold: 0
            readonly property bool holding: hold > 0.001

            Text {
                anchors.centerIn: parent
                text: "掃"
                color: wipeBtn.holding ? Theme.vermLit : (wipeArea.containsMouse ? Theme.cream : Theme.faint)
                font.family: Theme.fontJp
                font.pixelSize: 12 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            NumberAnimation {
                id: wipeFill
                target: wipeBtn
                property: "hold"
                from: 0
                to: 1
                duration: Motion.heat
                onFinished: {
                    Cliphist.wipe();
                    wipeDrain.restart();
                }
            }
            NumberAnimation {
                id: wipeDrain
                target: wipeBtn
                property: "hold"
                to: 0
                duration: 180
            }

            MouseArea {
                id: wipeArea
                anchors.fill: parent
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    wipeDrain.stop();
                    wipeFill.restart();
                }
                onReleased: {
                    wipeFill.stop();
                    if (wipeBtn.hold < 1)
                        wipeDrain.restart();
                }
                onExited: {
                    wipeFill.stop();
                    wipeDrain.restart();
                }
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

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results.length

        delegate: Item {
            id: row
            required property int index
            width: list.width
            height: (entry && entry.isImage ? 44 : 28) * root.s

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex

            HoverHandler {
                id: rowHover
                onHoveredChanged: if (hovered) root.selectedIndex = row.index
            }

            Rectangle {
                anchors.fill: parent
                radius: 9 * root.s
                visible: row.selected || rowHover.hovered
                color: row.selected ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.03)
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
                anchors.leftMargin: 11 * root.s
                anchors.rightMargin: 11 * root.s

                Rectangle {
                    id: thumbTile
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.entry !== undefined && row.entry.isImage
                    width: visible ? 52 * root.s : 0
                    height: 32 * root.s
                    radius: 6 * root.s
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
                        smooth: true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: thumbTile.visible ? thumbTile.right : parent.left
                    anchors.leftMargin: thumbTile.visible ? 9 * root.s : 0
                    anchors.right: sizeTag.left
                    anchors.rightMargin: 8 * root.s
                    text: row.entry === undefined ? "" : (row.entry.isImage ? row.entry.label : row.entry.preview)
                    color: row.entry !== undefined && row.entry.isImage
                        ? (row.selected ? Theme.dim : Theme.faint)
                        : (row.selected ? Theme.cream : Theme.subtle)
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
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
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
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
                        font.pixelSize: 12 * root.s
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    Text {
                        id: dismiss
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: rowHover.hovered ? 1 : 0
                        text: "✕"
                        color: dismissArea.containsMouse ? Theme.cream : Theme.dim
                        font.pixelSize: 10 * root.s
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

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
}
