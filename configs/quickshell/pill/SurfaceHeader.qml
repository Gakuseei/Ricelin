import QtQuick
import "Singletons"

/**
 * The one surface header: back chevron, kanji, small-caps title and breadcrumb; a press on the strip steps back (shell.qml).
 */
Item {
    id: head

    property real s: 1
    property string glyph: ""
    property string title: ""
    property string crumb: ""
    property bool canBack: false
    property alias titleContent: titleRow.data

    readonly property bool backable: canBack || crumb.length > 0

    function sentence(t) {
        return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1).toLowerCase() : t;
    }

    width: parent ? parent.width : 0
    height: 22 * head.s

    HoverHandler {
        id: strip
        enabled: head.backable
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        id: titleRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * head.s

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: head.backable
            width: 14 * head.s
            height: width
            color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            GlyphIcon {
                anchors.centerIn: parent
                width: 14 * head.s
                height: width
                name: "chevron-left"
                color: strip.hovered ? Theme.cream : Theme.iconDim
                stroke: 2
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.showGlyphs && head.glyph.length > 0
            text: head.glyph
            color: Theme.cream
            font.family: Theme.fontJp
            font.weight: Font.Medium
            font.pixelSize: 16 * head.s
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (head.crumb.length > 0 ? head.title + "  ›  " + head.crumb : head.title)
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.label * head.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Theme.labelTracking * head.s
        }
    }
}
