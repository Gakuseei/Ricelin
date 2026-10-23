pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * Labelled box of an inline editor form: a TextField, or with `capture` a click target that arms key capture.
 */
Item {
    id: field

    property real s: 1
    property string label: ""
    property real fontSize: Theme.fs.body
    readonly property alias input: input
    property alias text: input.text
    property alias placeholder: input.placeholderText

    property bool capture: false
    property bool listening: false
    property string value: ""
    property string hint: ""

    signal edited()
    signal cancelled()
    signal submitted()
    signal tapped()

    width: parent ? parent.width : 0
    height: 40 * field.s

    SettingsLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        s: field.s
        topPadding: 0
        bottomPadding: 0
        text: field.label
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 26 * field.s
        radius: Theme.r.s * field.s
        color: field.listening ? Qt.alpha(Theme.vermLit, 0.12)
            : (capArea.pressed ? Theme.pressBg : (capArea.containsMouse ? Qt.alpha(Theme.cream, 0.08) : Theme.frameBg))
        border.width: 1
        border.color: field.listening ? Qt.alpha(Theme.vermLit, 0.55)
            : (input.activeFocus ? Qt.alpha(Theme.vermLit, 0.45) : (capArea.containsMouse ? Theme.frameBorder : Theme.hairSoft))
        Behavior on color { enabled: field.capture; ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

        TextField {
            id: input
            visible: !field.capture
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp.m * field.s
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp.m * field.s
            anchors.verticalCenter: parent.verticalCenter
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: field.fontSize * field.s
            placeholderTextColor: Theme.textFaint
            selectByMouse: true
            selectionColor: Theme.verm
            onTextEdited: field.edited()
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { field.cancelled(); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { field.submitted(); e.accepted = true; }
            }
        }

        Text {
            visible: field.capture
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp.m * field.s
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp.m * field.s
            anchors.verticalCenter: parent.verticalCenter
            text: field.listening ? field.hint : (field.value.length ? field.value : "Click to set a key")
            color: field.listening ? Theme.flameGlow : (field.value.length ? Theme.cream : Theme.textFaint)
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * field.s
            font.weight: field.value.length ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }

        MouseArea {
            id: capArea
            anchors.fill: parent
            visible: field.capture
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.tapped()
        }
    }
}
