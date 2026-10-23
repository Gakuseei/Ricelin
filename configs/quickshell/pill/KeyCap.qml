pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * A key chord as one cap per key ("Super", "Shift", "S"); empty shows "Set key".
 */
Row {
    id: caps

    property real s: 1
    property string combo: ""

    readonly property var keys: combo.split("+").map(k => k.trim()).filter(k => k.length > 0)
        .map(k => k.length > 1 ? k.charAt(0).toUpperCase() + k.slice(1).toLowerCase() : k.toUpperCase())

    spacing: 4 * s

    Repeater {
        model: caps.keys.length > 0 ? caps.keys : ["Set key"]

        Rectangle {
            id: cap
            required property string modelData
            readonly property bool unset: caps.keys.length === 0
            width: Math.max(20 * caps.s, capText.implicitWidth + 12 * caps.s)
            height: 20 * caps.s
            radius: Theme.r.s * caps.s
            color: unset ? "transparent" : Theme.tileBg
            border.width: 1
            border.color: unset ? Theme.border : Theme.hair

            Text {
                id: capText
                anchors.centerIn: parent
                text: cap.modelData
                color: cap.unset ? Theme.textFaint : Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * caps.s
                font.weight: Font.Medium
            }
        }
    }
}
