pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "../lib/keychord.js" as Chord
import "app.js" as App

/** Edit or create form for one special space: name, description, Super key, glyph and its apps; the page validates `submitted(fields)` and sets `error`. */
Item {
    id: form

    property real s: App.shell ? App.shell.s : 1
    /** "new", "custom" or "builtin"; built-ins keep their key and description. */
    property string mode: "custom"
    property string name: ""
    property string desc: ""
    property string key: ""
    property string glyph: ""
    property int appCount: 0
    property bool appsEditable: false
    property string error: ""
    property string spaceId: ""
    property bool listening: false
    signal submitted(var fields)
    signal cancelled()
    signal manageApps()

    readonly property bool builtin: mode === "builtin"
    readonly property real labelW: 92 * s
    readonly property var glyphs: ["layers", "lock", "sparkles", "app-window", "waves", "moon", "sun", "palette", "mic", "speaker"]

    width: parent ? parent.width : implicitWidth
    implicitWidth: 480 * s
    implicitHeight: col.implicitHeight

    function focusName() {
        nameField.input.forceActiveFocus();
    }

    function submit() {
        form.listening = false;
        form.submitted({ name: nameField.text, desc: descField.text, key: form.key, glyph: form.glyph });
    }

    /** One letter A–Z; Super is implied and Shift with it sends the focused window. */
    function capture(k) {
        if (k === Qt.Key_Escape) {
            form.listening = false;
            return;
        }
        const n = Chord.chord(k, 0);
        if (n === null)
            return;
        form.listening = false;
        if (!/^[A-Z]$/.test(n)) {
            form.error = "Pick a single letter from A to Z";
            return;
        }
        form.key = n;
        form.error = Spaces.keyTaken(n, form.mode === "new" ? "" : form.spaceId) ? "Super + " + n + " is already in use" : "";
    }

    Column {
        id: col
        width: parent.width
        spacing: 10 * form.s

        Text {
            width: parent.width
            visible: form.builtin
            text: "Built-in spaces keep their key. Rename them or pick a glyph."
            color: Theme.textFaint
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 11.5 * form.s
        }

        Field {
            label: "Name"
            AppField {
                id: nameField
                Keys.onReturnPressed: form.submit()
                Keys.onEnterPressed: form.submit()
                fieldWidth: 260
                text: form.name
                placeholder: "Discord"
                maxLength: 40
                valid: form.error.indexOf("Name") < 0
                onAccepted: (t) => form.name = t
            }
        }

        Field {
            label: "Description"
            visible: !form.builtin
            AppField {
                id: descField
                Keys.onReturnPressed: form.submit()
                Keys.onEnterPressed: form.submit()
                fieldWidth: 260
                text: form.desc
                placeholder: "Chat (optional)"
                maxLength: 60
                onAccepted: (t) => form.desc = t
            }
        }

        Field {
            label: "Key"
            visible: !form.builtin

            Row {
                spacing: 12 * form.s

                Rectangle {
                    id: keyBox
                    width: Math.max(150 * form.s, keyInner.implicitWidth + 20 * form.s)
                    height: 30 * form.s
                    radius: 8 * form.s
                    color: form.listening ? Qt.alpha(Theme.vermLit, 0.08) : Theme.tileBg
                    border.width: 1
                    border.color: form.listening || keyBox.activeFocus ? Qt.alpha(Theme.vermLit, 0.6)
                        : (form.error.indexOf("Super") >= 0 || form.error.indexOf("letter") >= 0 ? Theme.danger : (keyArea.containsMouse ? Theme.vermDim : Theme.border))
                    activeFocusOnTab: true
                    focus: form.listening
                    Keys.onPressed: (e) => {
                        if (form.listening) {
                            form.capture(e.key);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            form.listening = true;
                            e.accepted = true;
                        }
                    }

                    Item {
                        id: keyInner
                        anchors.left: parent.left
                        anchors.leftMargin: 6 * form.s
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: form.listening || form.key.length === 0 ? hintText.implicitWidth + 4 * form.s : caps.implicitWidth
                        height: parent.height

                        KeyCap {
                            id: caps
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !form.listening && form.key.length > 0
                            s: form.s
                            combo: "Super + " + form.key
                        }
                        Text {
                            id: hintText
                            x: 4 * form.s
                            anchors.verticalCenter: parent.verticalCenter
                            visible: form.listening || form.key.length === 0
                            text: form.listening ? "Press a letter…" : "Click, then press a letter"
                            color: form.listening ? Theme.flameGlow : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: 12 * form.s
                        }
                    }

                    MouseArea {
                        id: keyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            form.listening = true;
                            keyBox.forceActiveFocus();
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Shift with it sends the focused window"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11.5 * form.s
                }
            }
        }

        Field {
            label: "Glyph"

            Flow {
                width: col.width - form.labelW
                spacing: 4 * form.s

                Repeater {
                    model: form.glyphs

                    Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool picked: form.glyph === modelData
                        width: 30 * form.s
                        height: 28 * form.s
                        radius: 7 * form.s
                        color: picked ? Qt.alpha(Theme.vermLit, 0.14) : (chipArea.containsMouse ? Theme.frameBg : "transparent")
                        border.width: 1
                        border.color: picked ? Qt.alpha(Theme.vermLit, 0.6) : Theme.frameBorder
                        Behavior on color { ColorAnimation { duration: 100 } }

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 15 * form.s
                            height: width
                            name: chip.modelData
                            color: chip.picked ? Theme.vermLit : Theme.iconDim
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: form.glyph = chip.picked && !form.builtin ? "" : chip.modelData
                        }
                    }
                }
            }
        }

        Field {
            label: "Apps"
            visible: form.appsEditable

            Row {
                spacing: 12 * form.s

                AppButton {
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    icon: "app-window"
                    text: form.mode === "new" ? "Add apps after creating" : "Manage apps"
                    enabled: form.mode !== "new"
                    onClicked: form.manageApps()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: form.mode !== "new"
                    text: form.appCount === 0 ? "No apps open here yet" : form.appCount === 1 ? "1 app opens here" : form.appCount + " apps open here"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11.5 * form.s
                }
            }
        }

        Item {
            width: parent.width
            height: 30 * form.s

            Text {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: 12 * form.s
                anchors.verticalCenter: parent.verticalCenter
                text: form.error
                color: Theme.danger
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12 * form.s
                font.weight: Font.Medium
            }

            Row {
                id: actions
                anchors.right: parent.right
                spacing: 8 * form.s

                AppButton {
                    text: "Cancel"
                    kind: "ghost"
                    onClicked: form.cancelled()
                }
                AppButton {
                    text: form.mode === "new" ? "Create" : "Save"
                    kind: "primary"
                    onClicked: form.submit()
                }
            }
        }
    }

    component Field: Item {
        id: field
        property string label: ""
        default property alias content: slot.data
        width: col.width
        height: visible ? Math.max(30 * form.s, slot.childrenRect.height) : 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 12 * form.s
        }
        Item {
            id: slot
            x: form.labelW
            width: parent.width - x
            height: childrenRect.height
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
