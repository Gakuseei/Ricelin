import QtQuick
import "Singletons"

/**
 * One-line picker value with tabular digits; a "WIDTH×HEIGHT" label dims its × so the numbers carry the read.
 */
Row {
    id: lbl

    property real s: 1
    property string text: ""
    property color color: Theme.cream
    property int weight: Font.DemiBold
    property real maxWidth: 0

    readonly property int xSplit: lbl.text.indexOf("×")
    spacing: 0

    Text {
        width: lbl.maxWidth > 0 && lbl.xSplit < 0 ? Math.min(implicitWidth, lbl.maxWidth) : implicitWidth
        elide: Text.ElideRight
        text: lbl.xSplit >= 0 ? lbl.text.substring(0, lbl.xSplit) : lbl.text
        color: lbl.color
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * lbl.s
        font.weight: lbl.weight
        font.features: { "tnum": 1 }
    }

    Text {
        visible: lbl.xSplit >= 0
        leftPadding: Theme.sp.xxs * lbl.s
        rightPadding: Theme.sp.xxs * lbl.s
        text: "×"
        color: Qt.alpha(lbl.color, 0.55)
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * lbl.s
        font.weight: Font.Medium
    }

    Text {
        visible: lbl.xSplit >= 0
        text: lbl.xSplit >= 0 ? lbl.text.substring(lbl.xSplit + 1) : ""
        color: lbl.color
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * lbl.s
        font.weight: lbl.weight
        font.features: { "tnum": 1 }
    }
}
