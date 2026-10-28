pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"
import "../lib/binds.js" as Binds
import "../lib/keychord.js" as Chord
import "PageKeybindsNames.js" as Names
import "app.js" as App

/** Every bind in binds.lua: filter, edit one inline (keys, name, command or action), delete, add; each save writes only the changed parts. */
AppPage {
    id: page
    pageId: "keybinds"
    resettable: false

    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"
    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]

    property var binds: []
    property string query: ""

    property bool formOpen: false
    property bool formAdd: false
    property bool listening: false
    property string heldMods: ""
    property int formLine: -1
    property bool formCmdEditable: true
    property string formAction: ""
    property string formCombo: ""
    property string formName: ""
    property string formCmd: ""
    property string formLabel: ""
    property string origCombo: ""
    property string origName: ""
    property string origCmd: ""
    property string origAction: ""
    property string formError: ""

    /** What the pending write was, so its toast and scroll land after the file is saved. */
    property var pendingOp: null

    readonly property var tokens: query.trim().toLowerCase().split(/\s+/).filter(t => t.length > 0)
    readonly property int shownCount: binds.filter(b => page.matches(b)).length

    readonly property var clash: {
        if (!formOpen || formCombo.length === 0 || (!formAdd && formCombo === origCombo))
            return null;
        const c = formCombo.toLowerCase();
        for (let i = 0; i < binds.length; i++)
            if (binds[i].lineIndex !== formLine && binds[i].combo.toLowerCase() === c)
                return binds[i];
        return null;
    }
    readonly property string clashText: clash ? Names.combo(formCombo) + " already runs " + Names.label(clash) : ""

    function hay(b) {
        return [Names.combo(b.combo), Chord.pretty(b.combo), b.combo, Names.label(b), b.label, b.name, Names.action(b), b.action,
                "keybinds shortcuts hotkeys binds"].join(" ").toLowerCase();
    }

    function matches(b) {
        if (tokens.length === 0)
            return true;
        const h = hay(b);
        return tokens.every(t => h.indexOf(t) >= 0);
    }

    function setQuery(q) {
        filterField.text = q;
        page.query = q;
    }

    function refresh() {
        let parsed = [];
        try {
            parsed = Binds.parse(bindsFile.text());
        } catch (e) {
            parsed = [];
        }
        if (JSON.stringify(parsed) !== JSON.stringify(page.binds))
            page.binds = parsed;
    }

    function splitCombo(c) {
        const parts = String(c).split("+").map(k => k.trim()).filter(k => k.length > 0);
        const mods = [];
        let key = "";
        for (let i = 0; i < parts.length; i++) {
            const up = parts[i].toUpperCase();
            if (i < parts.length - 1 && modOrder.indexOf(up) >= 0)
                mods.push(up);
            else
                key = key.length > 0 ? key + " + " + parts[i] : parts[i];
        }
        return { mods: mods, key: key };
    }

    function hasMod(m) {
        return splitCombo(formCombo).mods.indexOf(m) >= 0;
    }

    /** Modifier chips work without pressing the combo, which matters for combos Hyprland already grabs. */
    function toggleMod(m) {
        listening = false;
        heldMods = "";
        const p = splitCombo(formCombo);
        const mods = p.mods.indexOf(m) >= 0 ? p.mods.filter(x => x !== m) : p.mods.concat([m]);
        const ordered = modOrder.filter(x => mods.indexOf(x) >= 0);
        formCombo = p.key.length > 0 ? ordered.concat([p.key]).join(" + ") : ordered.join(" + ");
        formError = "";
    }

    function openEdit(b) {
        if (b.isMouse)
            return;
        listening = false;
        formError = "";
        formAdd = false;
        formLine = b.lineIndex;
        formCmdEditable = b.isExec && b.cmd.length > 0;
        formAction = b.action;
        formCombo = b.combo;
        formName = b.name;
        formCmd = b.cmd;
        formLabel = Names.label(b);
        origCombo = b.combo;
        origName = b.name;
        origCmd = b.cmd;
        origAction = b.action;
        formOpen = true;
    }

    function openAdd() {
        formError = "";
        formAdd = true;
        formLine = -1;
        formCmdEditable = true;
        formAction = "";
        formCombo = "";
        formName = "";
        formCmd = "";
        formLabel = "";
        origCombo = "";
        origName = "";
        origCmd = "";
        origAction = "";
        listening = true;
        formOpen = true;
    }

    readonly property bool formDirty: formAdd
        ? (formCombo.length > 0 || formName.length > 0 || formCmd.length > 0)
        : (formCombo !== origCombo || formName !== origName || formCmd !== origCmd || formAction !== origAction)

    function cancel(outside) {
        if (!formOpen || (outside && formDirty))
            return false;
        closeForm();
        return true;
    }

    function closeForm() {
        formOpen = false;
        listening = false;
        formError = "";
        heldMods = "";
    }

    /** The chord lands in form state only; a bare modifier keeps capture waiting and shows what is held. */
    function capture(key, modifiers) {
        const combo = Chord.chord(key, modifiers);
        if (combo === null) {
            heldMods = Chord.modNames(modifiers).join(" + ");
            return;
        }
        formCombo = combo;
        formError = "";
        heldMods = "";
        listening = false;
    }

    /** The parsed line must still hold the combo the form opened with, so an outside edit never shifts a write onto another bind. */
    function lineStillMatches(text) {
        const now = Binds.parse(text);
        for (let i = 0; i < now.length; i++)
            if (now[i].lineIndex === formLine)
                return now[i].combo === origCombo;
        return false;
    }

    /** Add appends one exec line; edit folds only the changed facets into a single write. */
    function save() {
        const text = bindsFile.text();
        if (formCombo.length === 0 || splitCombo(formCombo).key.length === 0) {
            formError = "Pick a key first";
            return;
        }
        if (clash) {
            formError = clashText;
            return;
        }
        if (formAdd) {
            if (formCmd.trim().length === 0) {
                formError = "Command is empty";
                return;
            }
            const a = Binds.add(text, formCombo, formCmd.trim(), formName.trim());
            if (!a.ok) {
                formError = a.error || "Could not add the bind";
                return;
            }
            pendingOp = { kind: "add", combo: formCombo };
            writer.setText(a.text);
            return;
        }

        if (!lineStillMatches(text)) {
            formError = "binds.lua changed meanwhile, open the bind again";
            refresh();
            return;
        }

        let out = text;
        if (formCombo !== origCombo) {
            const r = Binds.rebind(out, formLine, formCombo);
            if (!r.ok) {
                formError = r.error || "Could not change the key";
                return;
            }
            out = r.text;
        }
        if (formCmdEditable && formCmd !== origCmd) {
            if (formCmd.trim().length === 0) {
                formError = "Command is empty";
                return;
            }
            const c = Binds.editCmd(out, formLine, formCmd);
            if (!c.ok) {
                formError = c.error || "Could not change the command";
                return;
            }
            out = c.text;
        }
        if (!formCmdEditable && formAction !== origAction) {
            if (formAction.trim().length === 0) {
                formError = "Action is empty";
                return;
            }
            const a2 = Binds.editAction(out, formLine, formAction.trim());
            if (!a2.ok) {
                formError = a2.error === "unbalanced () or quote" ? "The action has an unmatched bracket or quote" : (a2.error || "Could not change the action");
                return;
            }
            out = a2.text;
        }
        if (formName !== origName) {
            const n = Binds.editName(out, formLine, formName.trim());
            if (!n.ok) {
                formError = n.error || "Could not change the name";
                return;
            }
            out = n.text;
        }

        if (out === text) {
            closeForm();
            return;
        }
        pendingOp = { kind: "save", combo: formCombo };
        writer.setText(out);
    }

    function removeBind(b) {
        const text = bindsFile.text();
        const now = Binds.parse(text).filter(x => x.lineIndex === b.lineIndex);
        if (now.length === 0 || now[0].combo !== b.combo) {
            App.toast("binds.lua changed meanwhile, try again", "error");
            refresh();
            return;
        }
        const d = Binds.del(text, b.lineIndex);
        if (!d.ok) {
            App.toast(d.error || "Could not delete the bind", "error");
            return;
        }
        pendingOp = { kind: "delete", combo: b.combo };
        writer.setText(d.text);
    }

    function revealCombo(combo) {
        let at = -1;
        for (let i = binds.length - 1; i >= 0; i--) {
            if (binds[i].combo === combo) {
                at = i;
                break;
            }
        }
        if (at < 0)
            return false;
        if (!matches(binds[at]))
            setQuery("");
        const it = rep.itemAt(at);
        if (it && App.shell)
            App.shell.scrollToItem(it, true);
        return it !== null;
    }

    function reveal(key) {
        const k = String(key);
        if (k.indexOf("filter:") === 0) {
            closeForm();
            setQuery(k.slice(7));
            if (App.shell)
                App.shell.scrollToItem(filterRow, false);
            return true;
        }
        if (k.indexOf("bind:") === 0) {
            closeForm();
            return revealCombo(k.slice(5));
        }
        const row = rowMap[k];
        if (!row)
            return false;
        if (App.shell)
            App.shell.scrollToItem(row, true);
        return true;
    }

    Component.onCompleted: refresh()

    FileView {
        id: bindsFile
        path: page.bindsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: page.refresh()
        onFileChanged: reload()
    }

    FileView {
        id: writer
        path: page.bindsPath
        atomicWrites: true
        printErrors: false
        onSaved: {
            HyprReload.request();
            const op = page.pendingOp;
            page.pendingOp = null;
            page.closeForm();
            bindsFile.reload();
            page.refresh();
            if (!op)
                return;
            const shown = Names.combo(op.combo);
            if (op.kind === "delete") {
                App.toast("Deleted " + shown);
            } else {
                App.toast((op.kind === "add" ? "Added " : "Saved ") + shown);
                Qt.callLater(() => page.revealCombo(op.combo));
            }
        }
        onSaveFailed: (err) => {
            page.pendingOp = null;
            page.formError = "Could not write binds.lua";
            console.log("keybinds: write failed: " + err);
        }
    }

    AppGroup {
        title: "Shortcuts"
        hint: "Click a bind to change its keys, name or command"

        Item {
            id: filterRow
            width: parent.width
            height: 46 * page.s

            AppField {
                id: filterField
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 * page.s - countText.width
                placeholder: "Filter binds by key, name or command"
                onEdited: (t) => page.query = t
            }
            Text {
                id: countText
                anchors.right: parent.right
                anchors.rightMargin: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                text: page.shownCount === page.binds.length ? page.binds.length + " binds" : page.shownCount + " of " + page.binds.length
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12 * page.s
                font.features: { "tnum": 1 }
            }
        }

        Text {
            x: 12 * page.s
            width: parent.width - 24 * page.s
            visible: page.shownCount === 0
            topPadding: 14 * page.s
            bottomPadding: 14 * page.s
            text: page.binds.length === 0 ? "No keybinds found in binds.lua" : "No binds match “" + page.query.trim() + "”"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 12.5 * page.s
        }

        Repeater {
            id: rep
            model: page.binds

            BindRow {}
        }

        AppRow {
            label: "Add a bind"
            sub: "Runs a command when you press its keys"
            key: "keys.add"
            AppButton {
                text: "Add bind"
                enabled: !(page.formOpen && page.formAdd)
                onClicked: page.openAdd()
            }
        }

        Loader {
            width: parent.width
            active: page.formOpen && page.formAdd
            visible: active
            sourceComponent: BindForm {}
        }
    }

    component BindRow: Item {
        id: brow
        required property var modelData
        required property int index
        readonly property var b: modelData
        readonly property bool editing: page.formOpen && !page.formAdd && page.formLine === b.lineIndex
        readonly property bool editable: !b.isMouse

        function flash() {
            flashAnim.restart();
        }

        width: parent ? parent.width : 0
        visible: editing || page.matches(b)
        height: editing ? formLoader.height + 4 * page.s : 52 * page.s

        HoverHandler {
            id: hover
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * page.s
            anchors.rightMargin: 12 * page.s
            height: 1
            color: Theme.hairSoft
            visible: brow.y > 0 && !brow.editing
        }

        Rectangle {
            anchors.fill: parent
            radius: 9 * page.s
            color: area.pressed ? Theme.pressBg : Theme.frameBg
            opacity: brow.editing || (hover.hovered && brow.editable) || area.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: flashRect
            anchors.fill: parent
            radius: 9 * page.s
            color: Theme.vermLit
            opacity: 0

            SequentialAnimation {
                id: flashAnim
                NumberAnimation { target: flashRect; property: "opacity"; to: 0.2; duration: 120; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 450 }
                NumberAnimation { target: flashRect; property: "opacity"; to: 0; duration: 1300; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: brow.editable && !brow.editing
            cursorShape: brow.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: page.openEdit(brow.b)
        }

        Item {
            anchors.fill: parent
            visible: !brow.editing

            KeyCap {
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                s: page.s
                combo: Names.combo(brow.b.combo)
            }

            Column {
                x: 200 * page.s
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, actions.x - x - 14 * page.s)
                spacing: 3 * page.s

                Row {
                    width: parent.width
                    spacing: 8 * page.s

                    Text {
                        id: nameText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - (selfChip.visible ? selfChip.width + parent.spacing : 0))
                        text: Names.label(brow.b)
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13 * page.s
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        id: selfChip
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Names.opensSettings(brow.b)
                        width: selfText.implicitWidth + 14 * page.s
                        height: 18 * page.s
                        radius: 6 * page.s
                        color: Qt.alpha(Theme.onGlow, 0.14)
                        border.width: 1
                        border.color: Qt.alpha(Theme.onGlow, 0.28)

                        Text {
                            id: selfText
                            anchors.centerIn: parent
                            text: "This app"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10.5 * page.s
                            font.weight: Font.DemiBold
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: Names.action(brow.b)
                    color: Theme.textFaint
                    elide: Text.ElideMiddle
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11 * page.s
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * page.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !brow.editable
                    text: "Edit in binds.lua"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 11.5 * page.s
                }
                AppButton {
                    visible: brow.editable
                    small: true
                    text: "Edit"
                    onClicked: page.openEdit(brow.b)
                }
                AppButton {
                    visible: brow.editable
                    small: true
                    kind: "danger"
                    icon: "trash"
                    onClicked: page.removeBind(brow.b)
                }
            }
        }

        Loader {
            id: formLoader
            y: 2 * page.s
            width: parent.width
            active: brow.editing
            visible: active
            height: active && item ? item.implicitHeight : 0
            sourceComponent: BindForm {}
        }
    }

    component BindForm: Column {
        id: form

        readonly property real labelW: 84 * page.s
        readonly property real fieldW: width - labelW - 12 * page.s

        width: parent ? parent.width : 0
        topPadding: 12 * page.s
        bottomPadding: 12 * page.s
        spacing: 10 * page.s

        Component.onDestruction: if (page.activeForm === form) page.activeForm = null
        Component.onCompleted: {
            page.activeForm = form;
            if (page.listening)
                capBox.forceActiveFocus();
            else
                nameField.input.forceActiveFocus();
            Qt.callLater(() => {
                if (App.shell)
                    App.shell.scrollToItem(form, false);
            });
        }

        Rectangle {
            x: 12 * page.s
            width: parent.width - 24 * page.s
            height: 1
            color: Theme.hairSoft
            visible: page.formAdd
        }

        Item {
            width: parent.width
            height: Math.max(capBox.height, mods.height)

            Text {
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Keys"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12.5 * page.s
            }

            Rectangle {
                id: capBox
                x: form.labelW
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(150 * page.s, form.fieldW - mods.width - 10 * page.s)
                height: 32 * page.s
                radius: 8 * page.s
                color: Theme.tileBg
                border.width: 1
                border.color: page.listening ? Qt.alpha(Theme.vermLit, 0.7)
                    : capBox.activeFocus ? Qt.alpha(Theme.vermLit, 0.45)
                    : capHover.hovered ? Theme.vermDim : Theme.border
                activeFocusOnTab: true

                onActiveFocusChanged: if (!activeFocus) {
                    page.listening = false;
                    page.heldMods = "";
                }

                Keys.onPressed: (e) => {
                    if (!page.listening) {
                        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            page.listening = true;
                            e.accepted = true;
                        }
                        return;
                    }
                    if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)
                        return;
                    e.accepted = true;
                    if (e.key === Qt.Key_Escape) {
                        page.listening = false;
                        page.heldMods = "";
                        return;
                    }
                    page.capture(e.key, e.modifiers);
                    if (!page.listening)
                        nameField.input.forceActiveFocus();
                }
                Keys.onReleased: (e) => {
                    if (page.listening && page.heldMods.length > 0)
                        page.heldMods = Chord.modNames(e.modifiers).join(" + ");
                }

                HoverHandler {
                    id: capHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        page.formError = "";
                        page.listening = true;
                        capBox.forceActiveFocus();
                    }
                }

                KeyCap {
                    x: 8 * page.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.listening ? page.heldMods.length > 0 : page.formCombo.length > 0
                    s: page.s
                    combo: Names.combo(page.listening ? page.heldMods : page.formCombo)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10 * page.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.listening || page.formCombo.length === 0
                    text: page.listening ? "Press keys…" : "Click, then press keys"
                    color: page.listening ? Theme.subtle : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12 * page.s
                }
            }

            Row {
                id: mods
                anchors.left: capBox.right
                anchors.leftMargin: 10 * page.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * page.s

                Repeater {
                    model: [{ id: "SUPER", label: "Super" }, { id: "CTRL", label: "Ctrl" }, { id: "ALT", label: "Alt" }, { id: "SHIFT", label: "Shift" }]

                    ModChip {}
                }
            }
        }

        Text {
            x: form.labelW
            width: form.fieldW
            visible: page.listening
            text: "A combo that is already in use runs its action instead. Press the key alone, then pick the modifiers on the right."
            color: Theme.textFaint
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 11.5 * page.s
        }

        Item {
            width: parent.width
            height: nameField.height

            Text {
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Name"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12.5 * page.s
            }
            AppField {
                id: nameField
                x: form.labelW
                width: form.fieldW
                text: page.formName
                placeholder: page.formLabel.length > 0 ? page.formLabel + " (optional)" : "Label (optional)"
                onEdited: (t) => {
                    page.formName = t;
                    page.formError = "";
                }
            }
            Connections {
                target: nameField.input
                function onAccepted() { page.save(); }
            }
        }

        Item {
            width: parent.width
            height: cmdField.height

            Text {
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                text: page.formCmdEditable ? "Command" : "Action"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: 12.5 * page.s
            }
            AppField {
                id: cmdField
                x: form.labelW
                width: form.fieldW
                mono: true
                text: page.formCmdEditable ? page.formCmd : page.formAction
                placeholder: page.formCmdEditable ? "Shell command, like ghostty" : "Lua dispatch, like hl.dsp.window.kill()"
                onEdited: (t) => {
                    if (page.formCmdEditable)
                        page.formCmd = t;
                    else
                        page.formAction = t;
                    page.formError = "";
                }
            }
            Connections {
                target: cmdField.input
                function onAccepted() { page.save(); }
            }
        }

        Text {
            x: form.labelW
            width: form.fieldW
            visible: text.length > 0
            text: page.formError.length > 0 ? page.formError : page.clashText
            color: Theme.danger
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 12 * page.s
            font.weight: Font.Medium
        }

        Item {
            width: parent.width
            height: 30 * page.s

            AppButton {
                x: form.labelW
                visible: !page.formAdd
                kind: "danger"
                text: "Delete"
                onClicked: {
                    const b = page.binds.filter(x => x.lineIndex === page.formLine)[0];
                    if (b)
                        page.removeBind(b);
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12 * page.s
                spacing: 8 * page.s

                AppButton {
                    text: "Cancel"
                    onClicked: page.closeForm()
                }
                AppButton {
                    kind: "primary"
                    text: page.formAdd ? "Add" : "Save"
                    onClicked: page.save()
                }
            }
        }
    }

    component ModChip: Rectangle {
        id: chip
        required property var modelData
        readonly property bool on: page.hasMod(modelData.id)

        width: chipText.implicitWidth + 18 * page.s
        height: 26 * page.s
        radius: 7 * page.s
        color: on ? Qt.alpha(Theme.onGlow, 0.16) : (chipArea.containsMouse ? Theme.pressBg : Theme.frameBg)
        border.width: chip.activeFocus ? 2 * page.s : 1
        border.color: chip.activeFocus ? Qt.alpha(Theme.vermLit, 0.6) : on ? Qt.alpha(Theme.onGlow, 0.3) : Theme.frameBorder
        activeFocusOnTab: true
        Keys.onSpacePressed: page.toggleMod(chip.modelData.id)
        Keys.onReturnPressed: page.toggleMod(chip.modelData.id)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.modelData.label
            color: chip.on || chipArea.containsMouse ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * page.s
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.toggleMod(chip.modelData.id)
        }
    }
}
