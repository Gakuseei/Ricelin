import QtQuick
import "Singletons"

/**
 * What a list shows when there is nothing in it: a quiet icon, one line, and an optional action.
 */
Column {
    id: empty

    property real s: 1
    property string glyph: ""
    property string text: ""
    property string action: ""

    signal triggered()

    spacing: 8 * s
    topPadding: 14 * s
    bottomPadding: 14 * s

    GlyphIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: empty.glyph.length > 0
        width: 20 * empty.s
        height: width
        name: empty.glyph
        color: Theme.textFaint
        stroke: 1.7
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: empty.text
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: Theme.fs.body * empty.s
        font.weight: Font.Normal
    }

    Button {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: empty.action.length > 0
        s: empty.s
        text: empty.action
        onClicked: empty.triggered()
    }
}
