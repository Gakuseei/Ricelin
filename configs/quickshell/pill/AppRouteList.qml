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

    readonly property alias addOpen: picker.addOpen
    function closeAdd() { picker.closeAdd(); }
    function normalizeClass(cls) { return picker.normalizeClass(cls); }

    signal removed(int index)
    signal picked(var entry)

    spacing: 0

    SettingsHeader {
        s: body.s
        glyph: body.glyph
        title: body.title
        showBack: true
    }

    Item { width: 1; height: 9 * body.s }


    Item {
        width: parent.width
        height: visible ? 26 * body.s : 0
        visible: !picker.addOpen && body.entries.length === 0

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4 * body.s
            anchors.verticalCenter: parent.verticalCenter
            text: body.emptyText
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11 * body.s
            font.weight: Font.Medium
        }
    }

    ListView {
        id: list
        width: parent.width
        height: visible ? Math.min(contentHeight, 230 * body.s) : 0
        visible: !picker.addOpen && body.entries.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: body.entries

        delegate: Item {
            id: erow
            required property int index
            required property string modelData

            readonly property var resolved: {
                void picker.allApps;
                return picker.resolveEntry(modelData);
            }
            readonly property string title: resolved && resolved.name ? resolved.name : modelData
            readonly property bool named: resolved && resolved.name && resolved.name !== modelData

            width: ListView.view.width
            height: 46 * body.s

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 3 * body.s
                anchors.bottomMargin: 3 * body.s
                radius: 10 * body.s
                color: rowHover.hovered ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: rowHover.hovered ? Theme.frameBorder : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            HoverHandler { id: rowHover }

            Rectangle {
                id: tile
                anchors.left: parent.left
                anchors.leftMargin: 10 * body.s
                anchors.verticalCenter: parent.verticalCenter
                width: 28 * body.s
                height: 28 * body.s
                radius: 7 * body.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.hairSoft

                Text {
                    anchors.centerIn: parent
                    visible: !(icon.status === Image.Ready && icon.source != "")
                    text: erow.title.length > 0 ? erow.title.charAt(0).toUpperCase() : "?"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13 * body.s
                    font.weight: Font.DemiBold
                }

                Image {
                    id: icon
                    anchors.fill: parent
                    anchors.margins: 4 * body.s
                    sourceSize.width: Math.round(40 * body.s)
                    sourceSize.height: Math.round(40 * body.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: erow.resolved && erow.resolved.icon ? Quickshell.iconPath(erow.resolved.icon, true) : ""
                }
            }

            Column {
                anchors.left: tile.right
                anchors.leftMargin: 12 * body.s
                anchors.right: removeBtn.left
                anchors.rightMargin: 10 * body.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * body.s

                Text {
                    width: parent.width
                    text: erow.title
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12.5 * body.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: erow.named
                    text: erow.modelData
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * body.s
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: removeBtn
                anchors.right: parent.right
                anchors.rightMargin: 8 * body.s
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * body.s
                height: 26 * body.s
                radius: 7 * body.s
                color: removeArea.containsMouse ? Qt.alpha(Theme.verm, 0.16) : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }

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
        onPicked: (entry) => body.picked(entry)
    }

    Item { width: 1; height: 4 * body.s }
}
