import QtQuick
import "Singletons"

/**
 * The one small label: group names between rows and field names in forms.
 */
Text {
    id: label

    property real s: 1

    topPadding: 16 * label.s
    bottomPadding: 6 * label.s
    leftPadding: 0 * label.s
    color: Theme.textFaint
    font.family: Theme.font
    font.pixelSize: Theme.fs.meta * label.s
    font.weight: Font.DemiBold
}
