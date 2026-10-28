pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."
import "../Singletons"
import "app.js" as App

/** Reorderable `items` [{ id, label, icon?, kanji?, sub?, on?, removable?, expandable? }]: drag a grip or Alt+Up/Down to move, Space toggles, Delete removes; each change emits `edited(items)` as a new array, `detail` is an optional per-item Component that gets `entry` and `index`, shown for rows without `expandable: false`. */
Item {
    id: list

    property real s: App.shell ? App.shell.s : 1
    property var items: []
    property Component detail: null
    signal edited(var items)
    signal moved(int from, int to)
    signal toggled(int index, bool on)
    signal removed(int index)

    readonly property real rowH: 42 * s
    property int dragIndex: -1
    property real dragDy: 0
    property int dropIndex: -1
    property int expanded: -1
    property int focusIndex: -1
    property bool refocus: false

    width: parent ? parent.width : implicitWidth
    implicitWidth: 400 * s
    implicitHeight: col.implicitHeight

    function copy() {
        return (items || []).map(o => Object.assign({}, o));
    }

    function move(from, to) {
        const n = (items || []).length;
        if (from < 0 || to < 0 || from >= n || to >= n || from === to)
            return;
        const a = copy();
        const it = a.splice(from, 1)[0];
        a.splice(to, 0, it);
        focusIndex = to;
        refocus = true;
        if (expanded === from)
            expanded = to;
        moved(from, to);
        edited(a);
    }

    function setOn(i, on) {
        const a = copy();
        if (!a[i] || typeof a[i].on !== "boolean")
            return;
        a[i].on = on;
        focusIndex = i;
        toggled(i, on);
        edited(a);
    }

    function remove(i) {
        const a = copy();
        if (!a[i] || a[i].removable !== true)
            return;
        a.splice(i, 1);
        focusIndex = Math.min(i, a.length - 1);
        refocus = true;
        expanded = -1;
        removed(i);
        edited(a);
    }

    onItemsChanged: if (refocus) Qt.callLater(() => {
        refocus = false;
        const r = rep.itemAt(focusIndex);
        if (r)
            r.takeFocus();
    })

    Column {
        id: col
        width: parent.width

        Repeater {
            id: rep
            model: list.items

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool dragging: list.dragIndex === index
                readonly property bool hasToggle: typeof modelData.on === "boolean"
                readonly property bool off: hasToggle && !modelData.on
                readonly property bool expandable: list.detail !== null && modelData.expandable !== false
                readonly property bool open: list.expanded === index && expandable
                readonly property bool lit: rowHover.hovered || grip.activeFocus

                function takeFocus() {
                    grip.forceActiveFocus();
                }

                width: col.width
                height: list.rowH + (open && detailLoader.item ? detailLoader.item.implicitHeight + 10 * list.s : 0)
                z: dragging ? 5 : 0

                readonly property real shift: {
                    if (list.dragIndex < 0 || dragging)
                        return 0;
                    if (list.dragIndex < index && list.dropIndex >= index)
                        return -list.rowH;
                    if (list.dragIndex > index && list.dropIndex <= index)
                        return list.rowH;
                    return 0;
                }

                transform: Translate {
                    y: row.dragging ? list.dragDy : row.shift
                    Behavior on y {
                        enabled: !row.dragging && list.dragIndex >= 0 && !Motion.calm
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                HoverHandler {
                    id: rowHover
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12 * list.s
                    anchors.rightMargin: 12 * list.s
                    height: 1
                    color: Theme.hairSoft
                    visible: row.index > 0 && list.dragIndex < 0
                    opacity: row.lit ? 0 : 1
                }

                RectangularShadow {
                    anchors.fill: rowBg
                    visible: row.dragging
                    radius: rowBg.radius
                    blur: 24 * list.s
                    offset.y: 8 * list.s
                    color: Qt.rgba(0, 0, 0, 0.42)
                }
                Rectangle {
                    id: rowBg
                    anchors.fill: parent
                    radius: 9 * list.s
                    color: row.dragging ? Theme.cardTop : Theme.frameBg
                    border.width: row.dragging ? 1 : 0
                    border.color: Theme.border
                    opacity: row.dragging || row.lit ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                Item {
                    id: main
                    width: parent.width
                    height: list.rowH

                    Rectangle {
                        id: grip
                        x: 6 * list.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22 * list.s
                        height: 28 * list.s
                        radius: 6 * list.s
                        color: gripArea.containsMouse || row.dragging ? Theme.frameBg : "transparent"
                        border.width: activeFocus ? 2 * list.s : 0
                        border.color: Qt.alpha(Theme.vermLit, 0.6)
                        activeFocusOnTab: true

                        Keys.onPressed: (e) => {
                            const alt = (e.modifiers & (Qt.AltModifier | Qt.ControlModifier)) !== 0;
                            if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
                                const d = e.key === Qt.Key_Up ? -1 : 1;
                                if (alt) {
                                    list.move(row.index, row.index + d);
                                } else {
                                    const r = rep.itemAt(row.index + d);
                                    if (r)
                                        r.takeFocus();
                                }
                            } else if (e.key === Qt.Key_Space) {
                                if (row.hasToggle)
                                    list.setOn(row.index, !row.modelData.on);
                            } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
                                list.remove(row.index);
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (row.expandable)
                                    list.expanded = row.open ? -1 : row.index;
                            } else {
                                return;
                            }
                            e.accepted = true;
                        }

                        Grid {
                            anchors.centerIn: parent
                            columns: 2
                            rowSpacing: 3 * list.s
                            columnSpacing: 4 * list.s

                            Repeater {
                                model: 6

                                Rectangle {
                                    width: 2.6 * list.s
                                    height: width
                                    radius: width / 2
                                    color: gripArea.containsMouse || row.dragging ? Theme.cream : Theme.faint
                                }
                            }
                        }

                        MouseArea {
                            id: gripArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real startY: 0

                            onPressed: (mouse) => {
                                list.expanded = -1;
                                startY = mapToItem(list, mouse.x, mouse.y).y;
                                list.dragIndex = row.index;
                                list.dropIndex = row.index;
                                list.dragDy = 0;
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed)
                                    return;
                                const n = (list.items || []).length;
                                const dy = mapToItem(list, mouse.x, mouse.y).y - startY;
                                const minDy = -row.index * list.rowH;
                                const maxDy = (n - 1 - row.index) * list.rowH;
                                list.dragDy = Math.max(minDy, Math.min(maxDy, dy));
                                list.dropIndex = Math.max(0, Math.min(n - 1, row.index + Math.round(list.dragDy / list.rowH)));
                            }
                            onReleased: {
                                const from = list.dragIndex;
                                const to = list.dropIndex;
                                list.dragIndex = -1;
                                list.dropIndex = -1;
                                list.dragDy = 0;
                                if (from >= 0 && to >= 0 && from !== to)
                                    list.move(from, to);
                            }
                            onCanceled: {
                                list.dragIndex = -1;
                                list.dropIndex = -1;
                                list.dragDy = 0;
                            }
                        }
                    }

                    Item {
                        id: ic
                        anchors.left: grip.right
                        anchors.leftMargin: 6 * list.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22 * list.s
                        height: width
                        opacity: row.off ? 0.45 : 1

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: (row.modelData.icon || "").length > 0
                            width: 16 * list.s
                            height: width
                            name: row.modelData.icon || ""
                            color: Theme.subtle
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: (row.modelData.icon || "").length === 0 && (row.modelData.kanji || "").length > 0
                            text: row.modelData.kanji || ""
                            color: Theme.iconDim
                            font.family: Theme.fontJp
                            font.weight: Font.Medium
                            font.pixelSize: 14 * list.s
                        }
                    }

                    Text {
                        id: name
                        anchors.left: ic.right
                        anchors.leftMargin: 10 * list.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label || row.modelData.id || ""
                        color: row.off ? Theme.textFaint : Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * list.s
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.left: name.right
                        anchors.leftMargin: 10 * list.s
                        anchors.right: tail.left
                        anchors.rightMargin: 10 * list.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.sub || ""
                        color: Theme.textFaint
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 11.5 * list.s
                    }

                    Row {
                        id: tail
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * list.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * list.s

                        TailButton {
                            visible: row.modelData.removable === true
                            glyph: "close"
                            onTapped: list.remove(row.index)
                        }
                        TailButton {
                            visible: row.expandable
                            glyph: "chevron-down"
                            turned: row.open
                            onTapped: list.expanded = row.open ? -1 : row.index
                        }
                        AppToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.hasToggle
                            activeFocusOnTab: false
                            s: list.s
                            checked: row.modelData.on === true
                            onToggled: (on) => list.setOn(row.index, on)
                        }
                    }
                }

                Loader {
                    id: detailLoader
                    anchors.top: main.bottom
                    x: 66 * list.s
                    width: parent.width - x - 12 * list.s
                    active: row.open
                    sourceComponent: list.detail
                    onLoaded: {
                        if ("entry" in item)
                            item.entry = Qt.binding(() => row.modelData);
                        if ("index" in item)
                            item.index = Qt.binding(() => row.index);
                    }
                }
            }
        }
    }

    component TailButton: Rectangle {
        id: tb
        property string glyph: ""
        property bool turned: false
        signal tapped()
        anchors.verticalCenter: parent.verticalCenter
        width: 26 * list.s
        height: width
        radius: 7 * list.s
        color: tbArea.containsMouse ? Theme.frameBg : "transparent"

        GlyphIcon {
            anchors.centerIn: parent
            width: 14 * list.s
            height: width
            name: tb.glyph
            stroke: 2
            color: tbArea.containsMouse ? Theme.cream : Theme.textFaint
            rotation: tb.turned ? 180 : 0
            Behavior on rotation { enabled: !Motion.calm; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: tbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.tapped()
        }
    }
}
