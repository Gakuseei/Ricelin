pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "app.js" as App

/** Read-only key/value lines from `rows`: [{ label, value }] or [[label, value]]. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property var rows: []

    readonly property var lines: (rows || []).map(r => Array.isArray(r) ? ({ label: String(r[0]), value: String(r[1]) }) : ({ label: String(r.label), value: String(r.value) }))
    readonly property real labelW: {
        let w = 0;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it)
                w = Math.max(w, it.labelNatural);
        }
        return w;
    }

    width: parent ? parent.width : implicitWidth
    implicitWidth: 320 * s
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 6 * root.s

        Repeater {
            id: rep
            model: root.lines

            Item {
                id: line
                required property var modelData
                readonly property real labelNatural: lab.implicitWidth
                width: col.width
                height: Math.max(lab.implicitHeight, val.implicitHeight)

                Text {
                    id: lab
                    width: root.labelW
                    text: line.modelData.label
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                }
                Text {
                    id: val
                    anchors.left: lab.right
                    anchors.leftMargin: 18 * root.s
                    anchors.right: parent.right
                    text: line.modelData.value
                    color: Theme.cream
                    wrapMode: Text.WrapAnywhere
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
