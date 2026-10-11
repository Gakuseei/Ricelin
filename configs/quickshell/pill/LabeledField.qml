import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * Label-above-value text field for anything too long to sit in a SettingsRow's
 * right-hand control slot — executable paths, prefixes, working directories.
 * Shares SearchField's actual input styling (transparent TextField background,
 * focus hairline) but stacks a full-width box under an uppercase caption
 * instead of inlining it, since a path can run to 60+ characters and a
 * right-aligned control would just clip it.
 *
 * `browse` picks the file/folder picker AppLauncher already owns (zenity,
 * falling back to kdialog); leave it unset for a plain text field.
 */
Item {
    id: root

    property real s: 1
    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    /** "" (none), "file" or "folder" */
    property string browse: ""
    property bool last: false

    signal committed(string value)

    width: parent ? parent.width : 0
    height: capText.implicitHeight + 6 * root.s + 34 * root.s + (root.last ? 0 : 10 * root.s)

    Text {
        id: capText
        anchors.top: parent.top
        anchors.left: parent.left
        text: root.label
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1 * root.s
    }

    Rectangle {
        id: box
        anchors.top: capText.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34 * root.s
        radius: 9 * root.s
        color: Theme.frameBg
        border.width: 1
        border.color: input.activeFocus ? Theme.hair : Theme.hairSoft
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        TextField {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 10 * root.s
            anchors.right: browseBtn.visible ? browseBtn.left : parent.right
            anchors.rightMargin: browseBtn.visible ? 6 * root.s : 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            placeholderText: root.placeholder
            placeholderTextColor: Theme.faint
            selectByMouse: true
            selectionColor: Theme.verm
            cursorDelegate: Item {}
            onEditingFinished: root.committed(text)
        }

        Rectangle {
            id: browseBtn
            visible: root.browse.length > 0
            anchors.right: parent.right
            anchors.rightMargin: 4 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: browseLabel.implicitWidth + 16 * root.s
            height: 24 * root.s
            radius: 7 * root.s
            color: browseArea.containsMouse ? Qt.alpha(Theme.cream, 0.1) : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                id: browseLabel
                anchors.centerIn: parent
                text: "Browse…"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: browseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var cb = (p) => { if (p && p.length > 0) { input.text = p; root.committed(p); } };
                    if (root.browse === "folder")
                        AppLauncher.pickFolder(cb);
                    else
                        AppLauncher.pickFile(cb);
                }
            }
        }
    }
}
