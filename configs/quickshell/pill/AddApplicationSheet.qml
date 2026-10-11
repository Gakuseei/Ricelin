pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"

/**
 * "Add to Ricelin" — deliberately the lean form from the design
 * conversation's mock, not the full editor: executable, name, category,
 * runner, prefix. Picking an executable auto-fills name and working
 * directory so the common case is three taps (Browse, pick a category,
 * Add); graphics API, performance and advanced overrides are one Edit
 * away afterwards rather than front-loaded here.
 */
Item {
    id: root

    property real s: 1

    signal cancelled()
    signal added(string appId)

    implicitHeight: col.implicitHeight

    property string name: ""
    property string category: "game"
    property string runner: "wine"
    property string executable: ""
    property string workingDirectory: ""
    property string prefix: ""
    property bool nameTouched: false
    property bool prefixTouched: false

    readonly property bool canAdd: root.name.trim().length > 0 && root.executable.trim().length > 0

    function toFolderName(n) {
        return String(n).replace(/[^A-Za-z0-9]/g, "");
    }

    function baseName(p) {
        var parts = String(p).split("/");
        var file = parts[parts.length - 1];
        var dot = file.lastIndexOf(".");
        return dot > 0 ? file.slice(0, dot) : file;
    }

    function dirOf(p) {
        var i = String(p).lastIndexOf("/");
        return i > 0 ? p.slice(0, i) : "";
    }

    function onExecutablePicked(p) {
        if (!p || p.length === 0)
            return;
        root.executable = p;
        if (!root.nameTouched)
            root.name = root.baseName(p);
        if (root.workingDirectory.length === 0)
            root.workingDirectory = root.dirOf(p);
        if (!root.prefixTouched && root.name.length > 0)
            root.prefix = (Quickshell.env("HOME") || "") + "/Games/" + root.toFolderName(root.name) + "/prefix";
    }

    function submit() {
        if (!root.canAdd)
            return;
        var rec = AppRegistry.add({
            name: root.name.trim(),
            category: root.category,
            runner: root.runner,
            executable: root.executable.trim(),
            workingDirectory: root.workingDirectory.trim(),
            prefix: root.prefix.trim(),
            umuId: root.runner === "umu" ? ("umu-" + AppRegistry.slugify(root.name)) : ""
        });
        root.added(rec.id);
    }

    component TextButton: Rectangle {
        id: tb
        property string label: ""
        property bool primary: false
        signal clicked()
        implicitWidth: tbLabel.implicitWidth + 22 * root.s
        implicitHeight: 32 * root.s
        radius: 9 * root.s
        color: tb.primary ? (tb.enabled ? Theme.vermDeep : Theme.threadBg) : (tbArea.containsMouse ? Theme.frameBg : "transparent")
        opacity: tb.enabled ? 1 : 0.5
        border.width: 1
        border.color: tb.primary ? "transparent" : Theme.frameBorder
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Text {
            id: tbLabel
            anchors.centerIn: parent
            text: tb.label
            color: tb.primary ? Theme.bright : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.Bold
        }
        MouseArea { id: tbArea; anchors.fill: parent; enabled: tb.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s; height: 15 * root.s
                    name: "chevron-left"
                    color: backArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 2.2
                    MouseArea { id: backArea; anchors.fill: parent; anchors.margins: -6 * root.s; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelled() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add to Ricelin"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Bold
                }
            }
        }

        Item { width: 1; height: 16 * root.s }

        LabeledField {
            s: root.s
            label: "Executable"
            text: root.executable
            placeholder: "Select the game's .exe"
            browse: "file"
            onCommitted: (v) => root.onExecutablePicked(v)
            onTextChanged: root.executable = text
        }
        Item { width: 1; height: 10 * root.s }
        LabeledField {
            s: root.s
            label: "Name"
            text: root.name
            placeholder: "How it appears in Ricelin"
            onTextChanged: { root.name = text; if (text.length > 0) root.nameTouched = true; }
        }
        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            name: "Category"
            control: SettingsSeg {
                s: root.s
                compact: true
               options: AppRegistry.categories.map(c => ({ label: c.label, value: c.id }))
                value: root.category
                onPicked: (v) => root.category = v
            }
        }
        SettingsRow {
            name: "Runner"
            sub: root.runner === "umu" && !RuntimeManager.hasUmu ? "UMU wasn't detected on this system yet"
                : (root.runner !== "umu" && !RuntimeManager.hasWine ? "Wine wasn't detected on this system yet" : "")
            last: true
            control: SettingsSeg {
                s: root.s
                options: [ { label: "Wine", value: "wine" }, { label: "Staging", value: "wine-staging" }, { label: "UMU", value: "umu" }, { label: "Native", value: "native" } ]
                value: root.runner
                onPicked: (v) => root.runner = v
            }
        }

        Item { width: 1; height: 10 * root.s }
        LabeledField {
            s: root.s
            label: "Working directory"
            text: root.workingDirectory
            placeholder: "Auto-detected from the executable"
            browse: "folder"
            onCommitted: (v) => root.workingDirectory = v
            onTextChanged: root.workingDirectory = text
        }
        Item { width: 1; height: 10 * root.s }
        LabeledField {
            s: root.s
            label: "Prefix / environment"
            text: root.prefix
            placeholder: "Where its Windows environment lives"
            browse: "folder"
            last: true
            onTextChanged: { root.prefix = text; if (text.length > 0) root.prefixTouched = true; }
        }

        Item { width: 1; height: 18 * root.s }

        Row {
            anchors.right: parent.right
            spacing: 8 * root.s
            TextButton { label: "Cancel"; onClicked: root.cancelled() }
            TextButton { label: "Add"; primary: true; enabled: root.canAdd; onClicked: root.submit() }
        }

        Item { width: 1; height: 8 * root.s }
    }
}
