pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * 字 FONT sub-surface: a searchable list of every installed family, each row
 * rendering its own name as a live preview so the user reads the shape before
 * picking. A click writes the family to Flags.uiFont, which Theme.font reads back
 * through a validated ternary so the whole shell re-renders at once; the leading
 * reset row writes "" to fall back to the bundled Inter. The current pick carries
 * the vermilion tint. Reached from Appearance and morphs back to it on the back
 * chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight
    rows: []

    property string query: ""
    property int focusIndex: 0

    /**
     * Window position of the last hover event allowed to move the highlight.
     * Rows sliding under a stationary cursor during keyboard scrolling repeat
     * the same window point and must not steal the selection.
     */
    property point lastPointer: Qt.point(-1, -1)

    readonly property string resetLabel: "System default (Inter)"

    /**
     * The only Noto families kept in the list. Noto ships hundreds of per-script
     * variants (Noto Sans Arabic, Noto Serif Devanagari and the like) that flood
     * the picker and never serve as a UI font, so every other Noto family is
     * dropped, trimming the list from ~690 entries to ~120.
     */
    readonly property var notoKeep: ["Noto Sans", "Noto Serif", "Noto Sans Mono"]

    /**
     * Deduped, sorted family list with the reset entry prepended, then narrowed by
     * a case-insensitive substring on the live query. The reset row carries an
     * empty family so a click clears Flags.uiFont; the search never hides it, so the
     * fallback stays one tap away.
     */
    readonly property var families: {
        var seen = {};
        var out = [];
        var all = Theme.fontFamilies;
        for (var i = 0; i < all.length; i++) {
            var fam = all[i];
            if (!fam || fam.length === 0 || fam.charAt(0) === ".")
                continue;
            if (fam.indexOf("Noto ") === 0 && root.notoKeep.indexOf(fam) < 0)
                continue;
            if (seen[fam] === true)
                continue;
            seen[fam] = true;
            out.push(fam);
        }
        out.sort(function (a, b) { return a.toLowerCase() < b.toLowerCase() ? -1 : 1; });
        var q = root.query.trim().toLowerCase();
        var rows = [{ family: "", label: root.resetLabel, reset: true }];
        for (var k = 0; k < out.length; k++) {
            if (q.length === 0 || out[k].toLowerCase().indexOf(q) >= 0)
                rows.push({ family: out[k], label: out[k], reset: false });
        }
        return rows;
    }

    function pick(family) {
        Flags.uiFont = family;
    }

    /** Slide the keyboard highlight by dir (+1 down, -1 up), clamped and kept in view. */
    function move(dir) {
        if (root.families.length === 0)
            return;
        root.focusIndex = Math.max(0, Math.min(root.families.length - 1, root.focusIndex + dir));
        list.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    function activate() {
        if (root.focusIndex < 0 || root.focusIndex >= root.families.length)
            return;
        root.pick(root.families[root.focusIndex].family);
    }

    onActiveChanged: {
        if (active) {
            focusIndex = 0;
            Qt.callLater(searchField.forceActiveFocus);
        } else {
            query = "";
            searchField.text = "";
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "字"
            title: "FONT"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        Item {
            width: parent.width
            height: 28 * root.s

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "探"
                color: Theme.dim
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 15 * root.s
            }

            TextField {
                id: searchField
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 4 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                background: null
                padding: 0
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                placeholderText: "search fonts"
                placeholderTextColor: Theme.faint
                selectByMouse: true
                selectionColor: Theme.verm
                onTextChanged: {
                    root.query = text;
                    root.focusIndex = 0;
                }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.move(1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.move(-1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activate();
                        e.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.left: searchField.left
                anchors.right: searchField.right
                anchors.top: searchField.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: Theme.faint
                opacity: searchField.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 8 * root.s }

        Item {
            id: listFrame
            width: parent.width
            height: Math.min(list.contentHeight, 280 * root.s)

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.families

                delegate: Item {
                    id: frow
                    required property int index
                    required property var modelData

                    readonly property bool isReset: frow.modelData.reset === true
                    readonly property bool selected: frow.isReset
                        ? Flags.uiFont.length === 0
                        : Flags.uiFont === frow.modelData.family
                    readonly property bool focused: root.focusIndex === frow.index

                    width: ListView.view.width
                    height: 36 * root.s

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (m) => {
                            var g = rowArea.mapToItem(null, m.x, m.y);
                            if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                                root.lastPointer = Qt.point(g.x, g.y);
                                root.focusIndex = frow.index;
                            }
                        }
                        onClicked: root.pick(frow.modelData.family)
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2 * root.s
                        anchors.bottomMargin: 2 * root.s
                        radius: 9 * root.s
                        color: frow.selected
                            ? Qt.alpha(Theme.vermLit, 0.14)
                            : (frow.focused ? Theme.frameBg : "transparent")
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.right: tick.left
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: frow.modelData.label
                        color: frow.selected ? Theme.vermLit : Theme.cream
                        font.family: frow.isReset ? Theme.font : frow.modelData.family
                        font.pixelSize: 14 * root.s
                        font.weight: frow.selected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: tick
                        anchors.right: parent.right
                        anchors.rightMargin: 14 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: frow.selected
                        width: 6 * root.s
                        height: 6 * root.s
                        radius: width / 2
                        color: Theme.vermLit
                    }
                }
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: list
            }
        }
    }
}
