pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "app.js" as App

/** One special space line: glyph tile, name, note and app chips, its Super key, Edit and (custom only) delete; registers `key` with the page so search can jump here. */
Item {
    id: row

    property real s: App.shell ? App.shell.s : 1
    property var space: ({})
    property string key: ""
    property bool first: false
    property bool editing: false
    property Component editor: null
    signal edit()
    signal remove()

    property Item page: null
    readonly property bool isAppRow: true
    readonly property bool lit: hover.hovered && !editing
    readonly property real padX: 12 * s
    readonly property var apps: space.apps || []
    readonly property int maxChips: 6

    width: parent ? parent.width : implicitWidth
    implicitWidth: 480 * s
    implicitHeight: main.height + (editing && formLoader.item ? formLoader.item.implicitHeight + 16 * s : 0)

    function flash() {
        flashAnim.restart();
    }

    function attach() {
        let p = row.parent;
        while (p && p.isAppPage !== true)
            p = p.parent;
        if (p !== page) {
            if (page && key.length > 0)
                page.unregisterRow(key, row);
            page = p;
            if (page && key.length > 0)
                page.registerRow(key, row);
        }
    }

    /** "[Ss]potify" reads "Spotify". */
    function className(cls) {
        return String(cls).replace(/\[(.)(.)\]/g, "$1").replace(/[\^$\\]|\.\*/g, "");
    }

    Component.onCompleted: attach()
    onParentChanged: if (parent) attach()
    Component.onDestruction: if (page && key.length > 0) page.unregisterRow(key, row)

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: row.padX
        anchors.rightMargin: row.padX
        height: 1
        color: Theme.hairSoft
        visible: !row.first
    }

    Rectangle {
        anchors.fill: parent
        radius: 9 * row.s
        color: Theme.frameBg
        opacity: row.lit || row.editing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: flashRect
        anchors.fill: parent
        radius: 9 * row.s
        color: Theme.vermLit
        opacity: 0

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashRect; property: "opacity"; to: 0.2; duration: 120; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 450 }
            NumberAnimation { target: flashRect; property: "opacity"; to: 0; duration: 1300; easing.type: Easing.OutCubic }
        }
    }

    Item {
        id: main
        width: parent.width
        height: Math.max(58 * row.s, textCol.implicitHeight + 22 * row.s)

        Rectangle {
            id: tile
            x: row.padX
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * row.s
            height: width
            radius: 10 * row.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.hairSoft

            GlyphIcon {
                anchors.centerIn: parent
                visible: (row.space.glyph || "").length > 0
                width: 16 * row.s
                height: width
                name: row.space.glyph || ""
                color: Theme.cream
            }
            Text {
                anchors.centerIn: parent
                visible: (row.space.glyph || "").length === 0
                text: (row.space.name || "?").charAt(0).toUpperCase()
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * row.s
                font.weight: Font.DemiBold
            }
        }

        Column {
            id: textCol
            anchors.left: tile.right
            anchors.leftMargin: 12 * row.s
            anchors.right: tail.left
            anchors.rightMargin: 16 * row.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * row.s

            Row {
                width: parent.width
                spacing: 8 * row.s

                Text {
                    id: nameText
                    text: row.space.name || ""
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * row.s
                    font.weight: Font.Medium
                }
                Text {
                    anchors.baseline: nameText.baseline
                    width: Math.max(0, parent.width - nameText.width - parent.spacing)
                    text: row.space.note || ""
                    color: Theme.textFaint
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11.5 * row.s
                }
            }

            Flow {
                width: parent.width
                spacing: 4 * row.s
                visible: row.apps.length > 0

                Repeater {
                    model: row.apps.slice(0, row.maxChips)

                    Rectangle {
                        id: chip
                        required property string modelData
                        width: chipText.implicitWidth + 16 * row.s
                        height: 22 * row.s
                        radius: 6 * row.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: row.className(chip.modelData)
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 11 * row.s
                            font.weight: Font.Medium
                        }
                    }
                }
                Text {
                    visible: row.apps.length > row.maxChips
                    height: 22 * row.s
                    verticalAlignment: Text.AlignVCenter
                    text: "+" + (row.apps.length - row.maxChips)
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11 * row.s
                }
            }
        }

        Row {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: row.padX
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * row.s

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                s: row.s
                combo: row.space.combo || ""
                opacity: (row.space.combo || "").length > 0 ? 1 : 0.6
            }
            AppButton {
                anchors.verticalCenter: parent.verticalCenter
                small: true
                text: row.editing ? "Close" : "Edit"
                onClicked: row.edit()
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * row.s
                height: width

                AppButton {
                    anchors.fill: parent
                    visible: !row.space.builtin
                    small: true
                    kind: "danger"
                    icon: "trash"
                    onClicked: row.remove()
                }
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: tail.left
            height: parent.height
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: row.edit()
        }
    }

    Loader {
        id: formLoader
        x: 58 * row.s
        y: main.height + 2 * row.s
        width: parent.width - x - row.padX
        active: row.editing
        sourceComponent: row.editor
    }
}
