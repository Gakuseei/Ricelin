import QtQuick
import "Singletons"

/** Back strip over an inline form or picker: a chevron that emits back() and a small caps title. */
Item {
    id: head

    property real s: 1
    property string title: ""

    signal back()

    width: parent ? parent.width : 0
    height: 22 * head.s

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7 * head.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * head.s
            height: 16 * head.s

            GlyphIcon {
                anchors.fill: parent
                name: "chevron-left"
                color: backArea.containsMouse ? Theme.cream : Theme.iconDim
                stroke: 1.8
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                anchors.margins: -6 * head.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: head.back()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: head.title
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9.5 * head.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4 * head.s
        }
    }
}
