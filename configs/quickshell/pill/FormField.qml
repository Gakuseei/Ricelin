pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/** Labelled box of an inline editor form: a TextField, or with `capture` a tap target that arms key capture. */
Item {
    id: field

    property real s: 1
    property string label: ""
    property real fontSize: 11.5
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

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: field.label
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * field.s
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1 * field.s
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 26 * field.s
        radius: 8 * field.s
        color: field.listening ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
        border.width: 1
        border.color: field.listening ? Qt.alpha(Theme.vermLit, 0.55)
            : (input.activeFocus ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft)
        Behavior on color { enabled: field.capture; ColorAnimation { duration: Motion.fast } }

        TextField {
            id: input
            visible: !field.capture
            anchors.left: parent.left
            anchors.leftMargin: 11 * field.s
            anchors.right: parent.right
            anchors.rightMargin: 11 * field.s
            anchors.verticalCenter: parent.verticalCenter
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: field.fontSize * field.s
            placeholderTextColor: Theme.faint
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
            anchors.leftMargin: 11 * field.s
            anchors.verticalCenter: parent.verticalCenter
            text: field.listening ? field.hint : (field.value.length ? field.value : "tap to set a key")
            color: field.listening ? Theme.flameGlow : (field.value.length ? Theme.cream : Theme.faint)
            font.family: Theme.font
            font.pixelSize: 11.5 * field.s
            font.weight: field.value.length ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            visible: field.capture
            cursorShape: Qt.PointingHandCursor
            onClicked: field.tapped()
        }
    }
}
