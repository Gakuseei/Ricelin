import QtQuick
import "Singletons"

/**
 * The one small-caps label: group names between rows and field names in forms.
 */
Text {
    id: label

    property real s: 1

    topPadding: 16 * label.s
    bottomPadding: 6 * label.s
    leftPadding: 0 * label.s
    color: Theme.textFaint
    font.family: Theme.font
    font.pixelSize: Theme.fs.label * label.s
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Theme.labelTracking * label.s
}
