import QtQuick
import "../Singletons"
import "app.js" as App

/** One preset as a card: a mini pill, name, "Active" or "Modified", and Apply; user presets also rename and delete. */
Rectangle {
    id: card

    property real s: App.shell ? App.shell.s : 1
    property string name: ""
    property string desc: ""
    property var values: ({})
    property bool user: false
    /** "", "active" or "modified". */
    property string status: ""
    signal apply()
    signal renamed(string name)
    signal removed()

    readonly property bool done: status === "active"
    property bool renaming: false
    property bool arm: false

    implicitHeight: thumbArea.height + info.implicitHeight
    radius: 12 * s
    color: Qt.rgba(0, 0, 0, 0.16)
    border.width: 1
    border.color: status === "active" ? Qt.alpha(Theme.vermLit, 0.5) : Theme.frameBorder
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Item {
        id: thumbArea
        width: parent.width
        height: 72 * card.s

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            topLeftRadius: card.radius - 1
            topRightRadius: card.radius - 1
            color: Qt.rgba(0, 0, 0, 0.14)
        }

        PresetsThumb {
            id: thumb
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            s: card.s
            values: card.values
            scale: Math.min(0.85, (thumbArea.width - 28 * card.s) / Math.max(1, implicitWidth))
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.frameBorder
        }
    }

    Column {
        id: info
        anchors.top: thumbArea.bottom
        width: parent.width
        padding: 12 * card.s
        topPadding: 11 * card.s
        spacing: 4 * card.s

        Item {
            width: parent.width - 2 * info.padding
            height: 24 * card.s

            Text {
                id: nameText
                visible: !card.renaming
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 8 * card.s : 0))
                text: card.name
                elide: Text.ElideRight
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * card.s
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: badge
                visible: card.status.length > 0 && !card.renaming
                anchors.left: nameText.right
                anchors.leftMargin: 8 * card.s
                anchors.verticalCenter: parent.verticalCenter
                width: badgeText.implicitWidth + 12 * card.s
                height: 18 * card.s
                radius: 5 * card.s
                color: card.done ? Qt.alpha(Theme.vermLit, 0.16) : Theme.frameBg
                border.width: 1
                border.color: card.done ? Qt.alpha(Theme.vermLit, 0.28) : Theme.frameBorder

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: card.done ? "Active" : "Modified"
                    color: card.done ? Theme.cream : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * card.s
                    font.weight: Font.DemiBold
                }
            }

            AppField {
                id: nameField
                visible: card.renaming
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                implicitHeight: 26 * card.s
                s: card.s
                maxLength: 40
                valid: text.trim().length > 0
                onAccepted: (t) => {
                    const n = t.trim();
                    if (card.renaming && n.length > 0 && n !== card.name)
                        card.renamed(n);
                    card.renaming = false;
                }
            }
        }

        Text {
            width: parent.width - 2 * info.padding
            height: 2 * 15.5 * card.s
            text: card.desc
            color: Theme.textFaint
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 15.5 * card.s
            lineHeightMode: Text.FixedHeight
            font.family: Theme.font
            font.pixelSize: 11.5 * card.s
        }

        Item {
            width: parent.width - 2 * info.padding
            height: applyBtn.height + 4 * card.s

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: -6 * card.s
                visible: card.user
                spacing: 2 * card.s

                AppButton {
                    s: card.s
                    small: true
                    kind: "ghost"
                    text: "Rename"
                    onClicked: {
                        card.arm = false;
                        nameField.text = card.name;
                        card.renaming = true;
                        nameField.input.forceActiveFocus();
                        nameField.input.selectAll();
                    }
                }
                AppButton {
                    s: card.s
                    small: true
                    kind: card.arm ? "danger" : "ghost"
                    text: card.arm ? "Delete for good" : "Delete"
                    onClicked: {
                        if (card.arm) {
                            card.arm = false;
                            card.removed();
                        } else {
                            card.arm = true;
                            disarm.restart();
                        }
                    }
                }
            }

            AppButton {
                id: applyBtn
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                s: card.s
                small: true
                kind: card.done ? "secondary" : "primary"
                enabled: !card.done
                text: card.done ? "Applied" : (card.status === "modified" ? "Apply again" : "Apply")
                onClicked: card.apply()
            }
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: card.arm = false
    }
}
