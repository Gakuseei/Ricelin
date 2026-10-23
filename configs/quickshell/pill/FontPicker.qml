pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 字 FONT: every installed family, each row previewing itself; a pick writes Flags.uiFont and the reset row clears it back to Inter.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight
    rows: []

    property string query: ""
    property int focusIndex: 0

    /**
     * Last pointer point that moved the highlight, so rows sliding under a still cursor never steal it.
     */
    property point lastPointer: Qt.point(-1, -1)

    readonly property string resetLabel: "System default (Inter)"

    /**
     * The only Noto families kept; the hundreds of per-script variants never serve as a UI font.
     */
    readonly property var notoKeep: ["Noto Sans", "Noto Serif", "Noto Sans Mono"]

    /**
     * Deduped, sorted, query-filtered families; the reset row always stays first.
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
            Qt.callLater(searchField.input.forceActiveFocus);
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

        SurfaceHeader {
            s: root.s
            glyph: "字"
            title: "FONT"
            canBack: true
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        SearchField {
            id: searchField
            width: parent.width
            height: 28 * root.s
            s: root.s
            kanji: "探"
            placeholder: "Search fonts"
            kanjiSize: 15
            fontSize: Theme.fs.body
            gap: Theme.sp.s
            lead: Theme.sp.m
            trail: Theme.sp.m
            lineGap: Theme.sp.xs
            restOpacity: 0.18
            showCursor: true
            catchEscape: false
            onTextChanged: {
                root.query = text;
                root.focusIndex = 0;
            }
            onMoved: (d) => root.move(d)
            onAccepted: root.activate()
        }

        Item { width: 1; height: Theme.sp.s * root.s }

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
                        anchors.topMargin: Theme.sp.xxs * root.s
                        anchors.bottomMargin: Theme.sp.xxs * root.s
                        radius: Theme.r.m * root.s
                        color: rowArea.pressed ? Theme.pressBg
                            : frow.selected ? Qt.alpha(Theme.vermLit, 0.14)
                            : (frow.focused ? Theme.frameBg : "transparent")
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp.m * root.s
                        anchors.right: tick.left
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: frow.modelData.label
                        color: frow.selected ? Theme.vermLit : Theme.cream
                        font.family: frow.isReset ? Theme.font : frow.modelData.family
                        font.pixelSize: Theme.fs.title * root.s
                        font.weight: frow.selected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    GlyphIcon {
                        id: tick
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: frow.selected
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "check"
                        color: Theme.vermLit
                        stroke: 2.2
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
