import QtQuick
import "Singletons"

/** Small-caps group label between settings rows. */
Text {
    id: label

    property real s: 1

    topPadding: 16 * label.s
    bottomPadding: 6 * label.s
    color: Theme.faint
    font.family: Theme.font
    font.pixelSize: 8.5 * label.s
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.2 * label.s
}
