import QtQuick
import "../Singletons"
import "app.js" as App

/** Switch: `checked` is the state, `toggled(checked)` carries the new one; click, Space or Enter flips it. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property bool checked: false
    signal toggled(bool checked)

    readonly property real knob: 12 * s
    readonly property real inset: 3 * s

    implicitWidth: 30 * s
    implicitHeight: 18 * s
    activeFocusOnTab: true

    function flip() {
        root.toggled(!root.checked);
    }

    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()
    Keys.onEnterPressed: flip()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3 * root.s
        radius: height / 2
        color: "transparent"
        border.width: 2 * root.s
        border.color: Qt.alpha(Theme.vermLit, 0.6)
        visible: root.activeFocus
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? (area.containsMouse ? Theme.vermLit : Theme.verm)
            : (area.containsMouse ? Theme.cardTop : Theme.tileBg)
        border.width: 1
        border.color: root.checked ? color : (area.containsMouse ? Theme.vermDim : Theme.border)
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: area.pressed ? root.knob + 3 * root.s : root.knob
        height: root.knob
        radius: height / 2
        color: Theme.cream
        x: root.checked ? root.width - width - root.inset : root.inset
        Behavior on x { enabled: !Motion.calm; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4 * root.s
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
