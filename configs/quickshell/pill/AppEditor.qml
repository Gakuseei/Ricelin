pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "Singletons"

/**
 * Full property editor for one Application Registry record — the "visual
 * thing, not a command-terminal thing" surface from the design conversation.
 * Every control writes straight through AppRegistry.update() the moment it
 * changes, same live-edit contract the rest of the pill's settings pages
 * use (no separate Save step to forget about); the host just has to keep
 * rebinding `app` to `AppRegistry.byId(id)` so edits reflect back in.
 *
 * Six sections mirror the mock from the design conversation: Identity,
 * Execution, Graphics, Window, Performance, Advanced — plus a small
 * Danger Zone at the foot for removing the entry from Ricelin (this never
 * touches the prefix or the game's own files on disk, only the registry
 * record; deleting the prefix itself is one explicit tap away in Execution).
 */
Item {
    id: root

    required property var app
    property real s: 1

    signal back()

    implicitHeight: col.implicitHeight

    function patch(fields) { AppRegistry.update(root.app.id, fields); }
    function patchWindow(fields) { root.patch({ window: Object.assign({}, root.app.window, fields) }); }
    function patchPerf(fields) { root.patch({ performance: Object.assign({}, root.app.performance, fields) }); }

    function setEnvVar(key, value) {
        if (!key || key.length === 0) return;
        root.patch({ env: Object.assign({}, root.app.env, { [key]: value }) });
    }
    function removeEnvVar(key) {
        var next = Object.assign({}, root.app.env);
        delete next[key];
        root.patch({ env: next });
    }
    function setDllOverride(dll, mode) {
        if (!dll || dll.length === 0) return;
        root.patch({ dllOverrides: Object.assign({}, root.app.dllOverrides, { [dll]: mode }) });
    }
    function removeDllOverride(dll) {
        var next = Object.assign({}, root.app.dllOverrides);
        delete next[dll];
        root.patch({ dllOverrides: next });
    }

    component SectionLabel: Item {
        id: sec
        property string text: ""
        width: parent ? parent.width : 0
        height: lbl.implicitHeight + 9 * root.s
        Text {
            id: lbl
            text: sec.text
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.hairSoft }
    }

    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 38 * root.s
        height: 22 * root.s
        radius: height / 2
        color: sw.checked ? Qt.alpha(Theme.onGlow, 0.9) : Theme.threadBg
        border.width: 1
        border.color: sw.checked ? "transparent" : Theme.hairSoft
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Rectangle {
            width: parent.height - 4 * root.s
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 2 * root.s : 2 * root.s
            color: Theme.bright
            Behavior on x { SpringAnimation { spring: 3; damping: 0.35 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    /** Compact caption-less text box for a SettingsRow control slot — NumberField's free-text sibling. */
    component TextChip: Rectangle {
        id: tc
        property alias value: tcInput.text
        property string placeholder: ""
        signal committed(string value)
        implicitWidth: 130 * root.s
        height: 26 * root.s
        radius: 7 * root.s
        color: Theme.frameBg
        border.width: 1
        border.color: tcInput.activeFocus ? Theme.hair : Theme.hairSoft
        TextField {
            id: tcInput
            anchors.fill: parent
            anchors.margins: 2 * root.s
            horizontalAlignment: Text.AlignRight
            background: null
            padding: 4 * root.s
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            placeholderText: tc.placeholder
            placeholderTextColor: Theme.faint
            selectByMouse: true
            onEditingFinished: tc.committed(text)
        }
    }

    component NumberField: Rectangle {
        id: nf
        property alias value: nfInput.text
        signal committed(string value)
        implicitWidth: 64 * root.s
        height: 26 * root.s
        radius: 7 * root.s
        color: Theme.frameBg
        border.width: 1
        border.color: nfInput.activeFocus ? Theme.hair : Theme.hairSoft
        TextField {
            id: nfInput
            anchors.fill: parent
            anchors.margins: 2 * root.s
            horizontalAlignment: Text.AlignHCenter
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.features: { "tnum": 1 }
            validator: IntValidator { bottom: 0; top: 1000 }
            selectByMouse: true
            onEditingFinished: nf.committed(text)
        }
    }

    /** One env-var or DLL-override line: a key, a value slot (text or a mode seg), a remove ✕. */
    component MapRow: Item {
        id: mrow
        property string keyText: ""
        default property alias valueSlot: valueHolder.data
        signal removed()
        width: parent ? parent.width : 0
        height: 30 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.34
            text: mrow.keyText
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Item {
            id: valueHolder
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.36
            anchors.right: rmBtn.left
            anchors.rightMargin: 6 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: childrenRect.height
        }
        Rectangle {
            id: rmBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 22 * root.s
            height: 22 * root.s
            radius: 6 * root.s
            color: rmArea.containsMouse ? Qt.alpha(Theme.verm, 0.16) : "transparent"
            GlyphIcon { anchors.centerIn: parent; width: 11 * root.s; height: 11 * root.s; name: "close"; color: rmArea.containsMouse ? Theme.vermLit : Theme.iconDim; stroke: 2 }
            MouseArea { id: rmArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mrow.removed() }
        }
    }

    component AddRow: Item {
        id: arow
        property string keyPlaceholder: "NAME"
        property string valuePlaceholder: "value"
        signal added(string key, string value)
        width: parent ? parent.width : 0
        height: 30 * root.s

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.34 - 6 * root.s
            height: 24 * root.s
            radius: 6 * root.s
            color: Theme.frameBg
            TextField {
                id: keyField
                anchors.fill: parent
                anchors.margins: 2 * root.s
                background: null
                padding: 4 * root.s
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                placeholderText: arow.keyPlaceholder
                placeholderTextColor: Theme.faint
                selectByMouse: true
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.36
            anchors.right: addBtn.left
            anchors.rightMargin: 6 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 24 * root.s
            radius: 6 * root.s
            color: Theme.frameBg
            TextField {
                id: valField
                anchors.fill: parent
                anchors.margins: 2 * root.s
                background: null
                padding: 4 * root.s
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                placeholderText: arow.valuePlaceholder
                placeholderTextColor: Theme.faint
                selectByMouse: true
                onAccepted: { arow.added(keyField.text, valField.text); keyField.text = ""; valField.text = ""; }
            }
        }
        Rectangle {
            id: addBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 22 * root.s
            height: 22 * root.s
            radius: 6 * root.s
            color: addArea.containsMouse ? Theme.frameBg : "transparent"
            border.width: 1
            border.color: Theme.hairSoft
            Text { anchors.centerIn: parent; text: "+"; color: Theme.subtle; font.pixelSize: 14 * root.s; font.weight: Font.Bold }
            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { arow.added(keyField.text, valField.text); keyField.text = ""; valField.text = ""; }
            }
        }
    }

    /** Compact text button used for the prefix/environment actions and the danger-zone confirm. */
    component TextButton: Rectangle {
        id: tb
        property string label: ""
        property bool danger: false
        signal clicked()
        implicitWidth: tbLabel.implicitWidth + 20 * root.s
        implicitHeight: 26 * root.s
        radius: 7 * root.s
        color: tbArea.containsMouse ? (tb.danger ? Qt.alpha(Theme.verm, 0.16) : Theme.frameBg) : "transparent"
        border.width: 1
        border.color: tb.danger ? Qt.alpha(Theme.verm, 0.4) : Theme.frameBorder
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Text {
            id: tbLabel
            anchors.centerIn: parent
            text: tb.label
            color: tb.danger ? Theme.vermLit : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.DemiBold
        }
        MouseArea { id: tbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        // Header
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
                    MouseArea { id: backArea; anchors.fill: parent; anchors.margins: -6 * root.s; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Edit"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }
        }

        Item { width: 1; height: 14 * root.s }

        // ---- Identity ----------------------------------------------------
        SectionLabel { text: "Identity" }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Name"; text: root.app.name; onCommitted: (v) => root.patch({ name: v }) }
        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            name: "Category"
            control: SettingsSeg {
                s: root.s
                options: AppRegistry.categories.map(c => ({ label: c.label, value: c.id }))
                value: root.app.category
                onPicked: (v) => root.patch({ category: v })
            }
        }
        SettingsRow {
            name: "Favorite"
            last: true
            control: ToggleSwitch { checked: root.app.favorite; onToggled: root.patch({ favorite: !root.app.favorite }) }
        }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Custom icon (optional)"; text: root.app.iconImage; placeholder: "Auto (first letter of name)"; browse: "file"; last: true; onCommitted: (v) => root.patch({ iconImage: v }) }

        Item { width: 1; height: 18 * root.s }

        // ---- Execution ----------------------------------------------------
        SectionLabel { text: "Execution" }
        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            name: "Runner"
            sub: RuntimeManager.runtimeAvailable(root.app.runner) ? "" : RuntimeManager.profileFor(root.app.runner).label + " isn't confirmed installed — this app is already configured to use it, so it stays selectable. Rescan if you've just installed it."
            last: true
            control: SettingsSeg {
                s: root.s
                options: RuntimeManager.selectableProfiles(root.app.runner).map(p => ({ label: p.shortLabel, value: p.id }))
                value: root.app.runner
                onPicked: (v) => root.patch({ runner: v })
            }
        }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Executable"; text: root.app.executable; browse: "file"; onCommitted: (v) => root.patch({ executable: v }) }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Working directory"; text: root.app.workingDirectory; placeholder: "Auto-detect from executable"; browse: "folder"; onCommitted: (v) => root.patch({ workingDirectory: v }) }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Prefix / environment"; text: root.app.prefix; browse: "folder"; onCommitted: (v) => root.patch({ prefix: v }) }
        Item { width: 1; height: 8 * root.s }
        Flow {
            width: parent.width
            spacing: 6 * root.s
            TextButton { label: "Create"; onClicked: AppLauncher.createPrefix(root.app) }
            TextButton { label: "Clone…"; onClicked: AppLauncher.pickFolder((p) => { if (p) AppLauncher.clonePrefix(root.app, p); }) }
            TextButton { label: "Reset"; danger: true; onClicked: AppLauncher.resetPrefix(root.app) }
            TextButton { label: "Open Files"; onClicked: AppLauncher.openPrefixFiles(root.app) }
            TextButton { label: "Winetricks"; onClicked: AppLauncher.runWinetricks(root.app) }
        }

        Item { width: 1; height: 10 * root.s; visible: root.app.runner === "umu" }
        LabeledField {
            visible: root.app.runner === "umu"
            s: root.s; label: "UMU game ID"; text: root.app.umuId; placeholder: "umu-" + root.app.id
            onCommitted: (v) => root.patch({ umuId: v })
        }
        Item { width: 1; height: 10 * root.s; visible: root.app.runner === "umu" }
        SettingsRow {
            visible: root.app.runner === "umu"
            name: "Proton build"
            sub: RuntimeManager.protonBuilds.length === 0 ? "None found under compatibilitytools.d" : ""
            last: true
            control: SettingsSeg {
                s: root.s
                options: (RuntimeManager.protonBuilds.length > 0 ? RuntimeManager.protonBuilds.map(b => ({ label: b.name, value: b.name })) : [ { label: "GE-Proton", value: "GE-Proton" } ])
                value: root.app.protonBuild
                onPicked: (v) => root.patch({ protonBuild: v })
            }
        }

        Item { width: 1; height: 18 * root.s }

        // ---- Graphics ----------------------------------------------------
        SectionLabel { text: "Graphics" }
        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            name: "Graphics API"
            sub: RuntimeManager.recommend(root.app).reason
            captionOnFocus: false
            last: true
            control: SettingsSeg {
                s: root.s
                options: [ { label: "Auto", value: "unknown" }, { label: "D3D9", value: "d3d9" }, { label: "D3D11", value: "d3d11" }, { label: "D3D12", value: "d3d12" }, { label: "Native", value: "native" } ]
                value: root.app.graphicsApi
                onPicked: (v) => root.patch({ graphicsApi: v })
            }
        }

        Item { width: 1; height: 18 * root.s }

        // ---- Window ----------------------------------------------------
        SectionLabel { text: "Window" }
        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            name: "Mode"
            control: SettingsSeg {
                s: root.s
                options: [ { label: "Windowed", value: "windowed" }, { label: "Borderless", value: "borderless" }, { label: "Fullscreen", value: "fullscreen" } ]
                value: root.app.window.mode
                onPicked: (v) => root.patchWindow({ mode: v })
            }
        }
        SettingsRow {
            name: "Resolution"
            last: true
            control: TextChip {
                value: root.app.window.resolution
                placeholder: "Native"
                onCommitted: (v) => root.patchWindow({ resolution: v })
            }
        }
        Item { width: 1; height: 10 * root.s }
        LabeledField { s: root.s; label: "Monitor"; text: root.app.window.monitor; placeholder: "Automatic"; last: true; onCommitted: (v) => root.patchWindow({ monitor: v }) }

        Item { width: 1; height: 18 * root.s }

        // ---- Performance ----------------------------------------------------
        SectionLabel { text: "Performance" }
        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            name: "MangoHud overlay"
            sub: "FPS / frametime overlay while the game runs"
            control: ToggleSwitch { checked: root.app.performance.mangohud; onToggled: root.patchPerf({ mangohud: !root.app.performance.mangohud }) }
        }
        SettingsRow {
            name: "Gamescope"
            sub: "Nested compositor — helps upscaling & fullscreen behaviour"
            control: ToggleSwitch { checked: root.app.performance.gamescope; onToggled: root.patchPerf({ gamescope: !root.app.performance.gamescope }) }
        }
        SettingsRow {
            name: "FPS limit"
            sub: "0 = unlimited"
            last: true
            control: NumberField { value: String(root.app.performance.fpsLimit); onCommitted: (v) => root.patchPerf({ fpsLimit: parseInt(v, 10) || 0 }) }
        }

        Item { width: 1; height: 18 * root.s }

        // ---- Advanced ----------------------------------------------------
        SectionLabel { text: "Advanced" }
        Item { width: 1; height: 10 * root.s }
        LabeledField {
            s: root.s
            label: "Launch arguments"
            text: (root.app.args || []).join(" ")
            placeholder: "-windowed -novid"
            last: true
            onCommitted: (v) => root.patch({ args: v.trim().length > 0 ? v.trim().split(/\s+/) : [] })
        }

        Item { width: 1; height: 14 * root.s }
        Text { text: "Environment variables"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 10 * root.s; font.weight: Font.Bold; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 * root.s }
        Item { width: 1; height: 8 * root.s }
        Repeater {
            model: Object.keys(root.app.env || {})
            delegate: MapRow {
                id: envRow
                required property string modelData
                keyText: modelData
                onRemoved: root.removeEnvVar(envRow.modelData)
                Rectangle {
                    width: parent.width; height: 24 * root.s; radius: 6 * root.s; color: Theme.frameBg
                    TextField {
                        anchors.fill: parent; anchors.margins: 2 * root.s
                        background: null; padding: 4 * root.s
                        color: Theme.cream; font.family: Theme.font; font.pixelSize: 10.5 * root.s
                        text: root.app.env[envRow.modelData] || ""
                        selectByMouse: true
                        onEditingFinished: root.setEnvVar(envRow.modelData, text)
                    }
                }
            }
        }
        AddRow { keyPlaceholder: "VARIABLE"; valuePlaceholder: "value"; onAdded: (k, v) => root.setEnvVar(k, v) }

        Item { width: 1; height: 14 * root.s }
        Text { text: "DLL overrides"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 10 * root.s; font.weight: Font.Bold; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 * root.s }
        Item { width: 1; height: 8 * root.s }
        Repeater {
            model: Object.keys(root.app.dllOverrides || {})
            delegate: MapRow {
                id: dllRow
                required property string modelData
                keyText: modelData
                onRemoved: root.removeDllOverride(dllRow.modelData)
                SettingsSeg {
                    s: root.s
                    options: [ { label: "Native", value: "native" }, { label: "Builtin", value: "builtin" }, { label: "N,B", value: "native,builtin" }, { label: "Off", value: "disabled" } ]
                    value: root.app.dllOverrides[dllRow.modelData] || "native"
                    onPicked: (v) => root.setDllOverride(dllRow.modelData, v)
                }
            }
        }
        AddRow { keyPlaceholder: "d3d11"; valuePlaceholder: "native"; onAdded: (k, v) => root.setDllOverride(k, v.length > 0 ? v : "native") }

        Item { width: 1; height: 22 * root.s }

        // ---- Danger zone ----------------------------------------------------
        SectionLabel { text: "Danger zone" }
        Item { width: 1; height: 10 * root.s }
        Row {
            spacing: 8 * root.s
            TextButton {
                label: removeArm.armed ? "Tap again to remove" : "Remove from Ricelin"
                danger: true
                onClicked: {
                    if (removeArm.armed) {
                        removeArm.armed = false;
                        AppRegistry.remove(root.app.id);
                        root.back();
                    } else {
                        removeArm.armed = true;
                        removeArm.restart();
                    }
                }
            }
        }
        Timer { id: removeArm; property bool armed: false; interval: 3000; onTriggered: armed = false }

        Item { width: 1; height: 8 * root.s }
    }
}
