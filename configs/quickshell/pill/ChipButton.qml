import QtQuick
import "Singletons"

/** Outlined confirm-row button; `danger` is the vermilion Forget style, `lit` pins the hover border. */
Rectangle {
    id: chip

    property real s: 1
    property string text: ""
    property bool danger: false
    property bool lit: false

    signal clicked()

    width: label.implicitWidth + 20 * chip.s
    height: 22 * chip.s
    radius: 7 * chip.s
    color: chip.danger
        ? Qt.rgba(Theme.verm.r, Theme.verm.g, Theme.verm.b, area.containsMouse ? 0.2 : 0.12)
        : (area.containsMouse ? Theme.tileBg : "transparent")
    border.width: 1
    border.color: chip.danger
        ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.45)
        : ((chip.lit || area.containsMouse) ? Theme.vermDim : Theme.border)

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.danger ? Theme.vermLit : Theme.cream
        font.family: Theme.font
        font.pixelSize: 10 * chip.s
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3 * chip.s
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
