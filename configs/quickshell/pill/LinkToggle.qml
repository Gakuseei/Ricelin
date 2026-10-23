import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * Toggle switch: tile bg off, terracotta fill on; the knob slides on and stretches while pressed.
 */
Rectangle {
    id: toggle

    property real s: 1
    property bool on: false
    signal toggled()

    readonly property real knob: 10 * s
    readonly property real knobW: area.pressed ? knob + 3 * s : knob
    readonly property real inset: 3 * s

    width: 28 * s
    height: 16 * s
    radius: height / 2
    color: on ? (area.containsMouse ? Theme.vermLit : Theme.verm) : (area.containsMouse ? Theme.cardTop : Theme.tileBg)
    border.width: on ? 0 : 1
    border.color: area.containsMouse ? Theme.vermDim : Theme.border
    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Rectangle {
        id: knobRect
        anchors.verticalCenter: parent.verticalCenter
        width: toggle.knobW
        height: toggle.knob
        radius: height / 2
        color: Theme.cream
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        x: toggle.on ? toggle.width - width - toggle.inset : toggle.inset
        Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4 * toggle.s
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
