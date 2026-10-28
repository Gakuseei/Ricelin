import QtQuick
import QtQuick.Controls
import "../Singletons"
import "app.js" as App

/** Text input: `text`, `placeholder`, `valid` (red edge when false); `edited(text)` per keystroke, `accepted(text)` on Enter or focus loss, Esc restores and leaves. */
Rectangle {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool valid: true
    property real fieldWidth: 180
    property bool mono: false
    property bool glyph: false
    property int maxLength: 32767
    signal edited(string text)
    signal accepted(string text)

    property string textAtFocus: ""

    implicitWidth: fieldWidth * s
    implicitHeight: 30 * s
    radius: 8 * s
    color: Theme.tileBg
    border.width: 1
    border.color: !valid ? Theme.danger : (input.activeFocus ? Qt.alpha(Theme.vermLit, 0.55) : (hover.hovered ? Theme.vermDim : Theme.border))
    Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler {
        id: hover
        cursorShape: Qt.IBeamCursor
    }

    TextField {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10 * root.s
        anchors.rightMargin: 10 * root.s
        background: null
        padding: 0
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: root.glyph ? TextInput.AlignHCenter : TextInput.AlignLeft
        color: Theme.cream
        font.family: root.glyph ? Theme.fontJp : (root.mono ? "JetBrains Mono" : Theme.font)
        font.pixelSize: (root.glyph ? 15 : 12.5) * root.s
        placeholderText: root.placeholder
        placeholderTextColor: Theme.textFaint
        selectByMouse: true
        selectionColor: Theme.verm
        selectedTextColor: Theme.bright
        maximumLength: root.maxLength
        onActiveFocusChanged: if (activeFocus) root.textAtFocus = text
        onTextEdited: root.edited(text)
        onEditingFinished: root.accepted(text)
        Keys.onEscapePressed: (e) => {
            if (text !== root.textAtFocus) {
                text = root.textAtFocus;
                root.edited(text);
            }
            if (App.shell)
                App.shell.focusHome();
            else
                focus = false;
            e.accepted = true;
        }
    }
}
