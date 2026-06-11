pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"
import "lib/fuzzy.js" as Fuzzy

/**
 * Launcher surface: a search field over a ranked application list, rendered as
 * one of the morphing pill's surfaces rather than a separate window. Desktop
 * entries are ranked by fuzzy match and prior launch frequency (the usage file
 * is shared with the standalone launcher), and the chosen entry is executed
 * directly. Fills the lower body of the morphing pill.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    property string query: ""
    property int selectedIndex: 0
    property var usage: ({})

    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void field.width;
        return field.mapToItem(root,
            field.cursorRectangle.x + field.cursorRectangle.width / 2,
            field.cursorRectangle.y + field.cursorRectangle.height / 2);
    }
    readonly property real caretX: caretPoint.x
    readonly property real caretY: caretPoint.y

    readonly property string usageFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/launcher-usage.json"

    signal requestClose()

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }
    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    function focusField() { field.forceActiveFocus(); }

    function mapCategory(raw) {
        const order = [
            ["TerminalEmulator", "Terminal"], ["WebBrowser", "Browser"],
            ["InstantMessaging", "Chat"], ["Audio", "Media"], ["AudioVideo", "Media"],
            ["Video", "Media"], ["Game", "Game"], ["Development", "Dev"],
            ["Graphics", "Graphics"], ["Office", "Office"], ["Settings", "System"],
            ["System", "System"], ["Utility", "Tool"], ["Network", "Net"]
        ];
        const cats = String(raw).split(/[;,]/);
        for (let i = 0; i < order.length; i++)
            if (cats.includes(order[i][0]))
                return order[i][1];
        return "";
    }

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (results.length === 0 || selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var entry = results[selectedIndex];
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
                usageStore.setText(JSON.stringify(root.usage));
                usageStore.waitForJob();
            }
            entry.execute();
        }
        root.requestClose();
    }

    onActiveChanged: {
        if (active) {
            query = "";
            field.text = "";
            selectedIndex = 0;
            Qt.callLater(root.focusField);
        }
    }
    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = 0;

    FileView {
        id: usageStore
        path: root.usageFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = usageStore.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    Item {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30 * root.s

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            text: "探"
            color: Theme.dim
            font.family: Theme.fontJp
            font.weight: Font.Medium
            font.pixelSize: 16 * root.s
        }

        TextField {
            id: field
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: glyph.right
            anchors.leftMargin: 10 * root.s
            anchors.right: counter.left
            anchors.rightMargin: 10 * root.s
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 15 * root.s
            placeholderText: "Search apps"
            placeholderTextColor: Theme.faint
            selectByMouse: true
            selectionColor: Theme.verm
            onTextChanged: {
                root.query = text;
                root.selectedIndex = 0;
            }
            cursorDelegate: Item {}
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.activate();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    root.requestClose();
                    e.accepted = true;
                }
            }
        }

        Text {
            id: counter
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            text: root.results.length + " / " + root.totalCount
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.features: { "tnum": 1 }
        }
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.results.length

        delegate: Item {
            id: appRow
            required property int index
            width: list.width
            height: 34 * root.s

            readonly property var entry: root.results[index]
            readonly property bool selected: index === root.selectedIndex

            readonly property string secondary: {
                if (!entry)
                    return "";
                if (entry.genericName && entry.genericName.length > 0)
                    return entry.genericName;
                if (entry.categories && entry.categories.length > 0)
                    return root.mapCategory(entry.categories);
                return "";
            }

            Rectangle {
                anchors.fill: parent
                radius: 9 * root.s
                visible: appRow.selected || rowArea.containsMouse
                color: appRow.selected ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.03)
                border.width: appRow.selected ? 1 : 0
                border.color: Theme.frameBorder
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = appRow.index
                onClicked: {
                    root.selectedIndex = appRow.index;
                    root.activate();
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 11 * root.s
                anchors.rightMargin: 11 * root.s

                Rectangle {
                    id: iconBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * root.s
                    height: 20 * root.s
                    radius: 5 * root.s
                    color: Qt.rgba(1, 1, 1, 0.05)
                    visible: !(icon.status === Image.Ready && icon.source != "")
                }
                Image {
                    id: icon
                    anchors.fill: iconBg
                    sourceSize.width: Math.round(40 * root.s)
                    sourceSize.height: Math.round(40 * root.s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready && source != ""
                    source: appRow.entry && appRow.entry.icon ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                }

                Text {
                    id: nameText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: icon.right
                    anchors.leftMargin: 10 * root.s
                    text: appRow.entry ? appRow.entry.name : ""
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: appRow.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - icon.width - 10 * root.s - sec.width - ret.width - 12 * root.s)
                }
                Text {
                    id: ret
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: "↵"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    visible: appRow.selected
                    width: visible ? implicitWidth + 6 * root.s : 0
                    horizontalAlignment: Text.AlignRight
                }
                Text {
                    id: sec
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: ret.left
                    text: appRow.secondary
                    color: appRow.selected ? Theme.dim : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
