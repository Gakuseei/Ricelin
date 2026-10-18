pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "lib/keychord.js" as Chord
import "Singletons"

/**
 * 場 WORKSPACES hub: a glance at Hyprland's special spaces and the keys that
 * summon them. The three built-in rows (Stash, Private, Minimized) sit on top;
 * below them every user-defined space from the Spaces store gets its own row with
 * a Super+<key> chip, a chevron into its app manager (SpaceApps) and a remove
 * control on hover. Clicking a row's NAME — built-in or custom — folds it open
 * into an inline edit mode (editable name field plus a glyph strip below) saved
 * into spaces.lua; the rest of the row keeps its tap target (the stash surface,
 * the app manager). A custom row's key chip starts an inline letter capture that
 * rebinds the space's trigger, refused with an inline hint on a clash. Built-in
 * edits persist as display-only override entries; their keys live in binds.lua.
 * A dashed "Add Workspace" bar at the bottom swaps the surface into a create
 * form — name, description and a captured single-letter key — that makes a new
 * space on confirm.
 *
 * Built on the plain surface base like Stash and Keybinds; the host routes its
 * header-back to the settings index (or, while the form is open, back to the
 * list) and each navigable row's tap to the matching surface.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

    ameForm: "off"

    property bool formOpen: false
    property bool listening: false
    property string conflict: ""
    property string formName: ""
    property string formDesc: ""
    property string formKey: ""

    property string editId: ""
    property string editName: ""
    property string editGlyph: ""
    property string rebindId: ""
    property string conflictId: ""

    /** Preset glyph picks for a space; every name exists in GlyphIcon's map. */
    readonly property var glyphChoices: ["layers", "lock", "sparkles", "app-window", "waves", "moon", "sun", "palette", "mic", "speaker"]

    readonly property var spaces: [
        { id: "stash", name: "Stash", key: "Super + S", note: "Background apps that open here", surface: "stash", glyph: "layers" },
        { id: "private", name: "Private", key: "Super + P", note: "Hidden scratchpad", surface: "", glyph: "lock" },
        { id: "minimized", name: "Minimized", key: "Super + Shift + M", note: "Minimized windows", surface: "", glyph: "chevron-down" }
    ]

    /** Custom spaces only: built-in display-override entries stay out of the list. */
    readonly property var customSpaces: {
        var sl = Spaces.list;
        var out = [];
        for (var i = 0; i < sl.length; i++)
            if (!Spaces.reserved(sl[i].id))
                out.push(sl[i]);
        return out;
    }

    /** The spaces.lua display-override entry for a built-in id, or null when unedited. */
    function builtinEntry(id) {
        var sl = Spaces.list;
        for (var i = 0; i < sl.length; i++)
            if (sl[i].id === id)
                return sl[i];
        return null;
    }

    function builtinName(row) {
        var e = builtinEntry(row.id);
        return e ? e.name : row.name;
    }

    function builtinGlyph(row) {
        var e = builtinEntry(row.id);
        return (e && e.glyph.length) ? e.glyph : row.glyph;
    }

    function openForm() {
        root.formName = "";
        root.formDesc = "";
        root.formKey = "";
        root.conflict = "";
        root.listening = false;
        root.rebindId = "";
        root.conflictId = "";
        root.formOpen = true;
    }

    function closeForm() {
        root.formOpen = false;
        root.listening = false;
        root.conflict = "";
    }

    /** Glyph a custom space row shows: its saved pick, else the fallback for unpicked spaces. */
    function glyphFor(entry) {
        return entry.glyph && entry.glyph.length ? entry.glyph : "sparkles";
    }

    function openEdit(id, name, glyph) {
        root.rebindId = "";
        root.conflictId = "";
        root.listening = false;
        root.editId = id;
        root.editName = name;
        root.editGlyph = glyph;
    }

    function closeEdit() {
        root.editId = "";
    }

    /** Persist the inline edit: display name plus picked glyph; id, key and apps stay. */
    function saveEdit() {
        var name = root.editName.trim();
        if (name.length > 0)
            Spaces.updateSpace(root.editId, name, root.editGlyph);
        root.closeEdit();
    }

    /**
     * Start an inline key capture on a custom space's key chip. The keyCatcher
     * swallows keystrokes while `listening` and feeds capture(); the chip shows
     * the capture state and the row carries the hint or conflict underneath.
     */
    function rebind(id) {
        root.closeEdit();
        root.conflict = "";
        root.conflictId = "";
        root.rebindId = id;
        root.listening = true;
        keyCatcher.forceActiveFocus();
    }

    /**
     * Fold a captured keypress into a single uppercase letter. Modifiers are
     * dropped (Super is auto-prefixed), a bare modifier keeps capture waiting,
     * Escape ends it, and anything that is not one A–Z letter is refused inline.
     * With a rebind armed the letter goes to that row's key after a clash check
     * against every other space and bind; without one it seeds the create form.
     */
    function capture(key, modifiers) {
        if (key === Qt.Key_Escape) {
            root.listening = false;
            root.rebindId = "";
            return;
        }
        var name = Chord.chord(key, 0);
        if (name === null)
            return;
        if (!/^[A-Z]$/.test(name)) {
            root.conflict = "single letter only";
            root.conflictId = root.rebindId;
            root.listening = false;
            root.rebindId = "";
            return;
        }
        if (root.rebindId.length > 0) {
            if (Spaces.keyTaken(name, root.rebindId)) {
                root.conflict = "Super + " + name + " in use";
                root.conflictId = root.rebindId;
            } else {
                root.conflict = "";
                root.conflictId = "";
                Spaces.updateKey(root.rebindId, name);
            }
            root.listening = false;
            root.rebindId = "";
            return;
        }
        root.formKey = name;
        root.conflict = "";
        root.listening = false;
    }

    /**
     * Validate and create the space. Name must slug to a non-empty, unused id; the
     * key must be one letter and free of every existing bind. A clash is reported
     * inline so nothing is written until it is resolved.
     */
    function create() {
        var name = root.formName.trim();
        if (name.length === 0) { root.conflict = "name empty"; return; }
        var id = Spaces.slug(name);
        if (id.length === 0) { root.conflict = "name needs a letter"; return; }
        if (Spaces.reserved(id)) { root.conflict = name + " is reserved"; return; }
        for (var i = 0; i < Spaces.list.length; i++)
            if (Spaces.list[i].id === id) { root.conflict = name + " already exists"; return; }
        if (!/^[A-Za-z]$/.test(root.formKey)) { root.conflict = "pick a key"; return; }
        if (Spaces.keyTaken(root.formKey)) { root.conflict = "Super + " + root.formKey.toUpperCase() + " in use"; return; }
        Spaces.addSpace(name, root.formDesc.trim(), root.formKey.toUpperCase());
        root.closeForm();
    }

    onActiveChanged: {
        formOpen = false;
        listening = false;
        conflict = "";
        editId = "";
        rebindId = "";
        conflictId = "";
    }

    onFormOpenChanged: if (formOpen) Qt.callLater(nameField.input.forceActiveFocus)

    /**
     * Inline rename + glyph editor shared by every space row, built-in and
     * custom. The host delegate shows it while its row is in edit mode and
     * focuses `field`; it reads and writes root.editName / root.editGlyph
     * directly. Enter saves, Escape cancels; a glyph tap re-picks.
     */
    component EditBlock: Column {
        id: editBlock

        property alias field: nameEdit

        spacing: 6 * root.s

        TextField {
            id: nameEdit
            width: parent.width
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
            selectByMouse: true
            selectionColor: Theme.verm
            text: root.editName
            onTextEdited: root.editName = text
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { root.closeEdit(); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.saveEdit(); e.accepted = true; }
            }
        }

        Row {
            spacing: 4 * root.s

            Repeater {
                model: root.glyphChoices

                delegate: Rectangle {
                    id: gchip
                    required property string modelData
                    readonly property bool on: root.editGlyph === modelData

                    width: 22 * root.s
                    height: 22 * root.s
                    radius: 6 * root.s
                    color: gchip.on ? Qt.alpha(Theme.vermLit, 0.12) : (gArea.containsMouse ? Theme.frameBg : "transparent")
                    border.width: 1
                    border.color: gchip.on ? Qt.alpha(Theme.vermLit, 0.55) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 13 * root.s
                        height: 13 * root.s
                        name: gchip.modelData
                        color: gchip.on ? Theme.vermLit : Theme.iconDim
                        stroke: 1.8
                    }

                    MouseArea {
                        id: gArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editGlyph = gchip.modelData
                    }
                }
            }
        }
    }

    Item {
        id: keyCatcher
        focus: root.listening
        Keys.onPressed: (e) => {
            if (!root.listening)
                return;
            e.accepted = true;
            root.capture(e.key, e.modifiers);
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "場"
            title: "WORKSPACES"
            showBack: true
        }

        Item { width: 1; height: 8 * root.s }

        /** ── list view ── */

        Column {
            id: listCol
            width: parent.width
            visible: !root.formOpen
            spacing: 0

            Repeater {
                model: root.spaces

                delegate: Item {
                    id: wrow
                    required property int index
                    required property var modelData

                    readonly property bool nav: modelData.surface.length > 0
                    readonly property bool editing: root.editId === wrow.modelData.id

                    width: parent.width
                    height: editing ? 80 * root.s : 50 * root.s

                    onEditingChanged: if (editing) Qt.callLater(wEditBlock.field.forceActiveFocus)

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3 * root.s
                        anchors.bottomMargin: 3 * root.s
                        radius: 10 * root.s
                        color: (wrow.editing || (wrow.nav && navHover.hovered)) ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: (wrow.editing || (wrow.nav && navHover.hovered)) ? Theme.frameBorder : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    HoverHandler { id: navHover; enabled: wrow.nav }

                    MouseArea {
                        anchors.fill: parent
                        enabled: wrow.nav
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!wrow.editing) root.requestSurface(wrow.modelData.surface)
                    }

                    GlyphIcon {
                        id: wGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !wrow.editing
                        width: 16 * root.s
                        height: 16 * root.s
                        name: root.builtinGlyph(wrow.modelData)
                        color: Theme.iconDim
                        stroke: 1.8
                    }

                    Column {
                        anchors.left: wGlyph.right
                        anchors.leftMargin: 10 * root.s
                        anchors.right: rightRow.left
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * root.s

                        Column {
                            width: parent.width
                            spacing: 3 * root.s

                            Text {
                                id: wNameText
                                width: parent.width
                                visible: !wrow.editing
                                text: root.builtinName(wrow.modelData)
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12.5 * root.s
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight

                                /** Only the name itself opens rename; the rest of the row keeps its tap target. */
                                MouseArea {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.min(wNameText.implicitWidth, wNameText.width)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEdit(wrow.modelData.id, root.builtinName(wrow.modelData), root.builtinGlyph(wrow.modelData))
                                }
                            }
                            Text {
                                width: parent.width
                                visible: !wrow.editing
                                text: wrow.modelData.note
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                elide: Text.ElideRight
                            }
                        }

                        EditBlock {
                            id: wEditBlock
                            width: parent.width
                            visible: wrow.editing
                        }
                    }

                    Row {
                        id: rightRow
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * root.s

                        /** Built-in keys live in binds.lua (the Keybinds surface owns them); this chip is display-only. */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !wrow.editing
                            width: keyText.implicitWidth + 16 * root.s
                            height: keyText.implicitHeight + 8 * root.s
                            radius: 7 * root.s
                            color: Theme.frameBg
                            border.width: 1
                            border.color: Theme.hairSoft

                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: wrow.modelData.key
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Bold
                                font.letterSpacing: 0.3 * root.s
                            }
                        }

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wrow.nav && !wrow.editing
                            width: 16 * root.s
                            height: 16 * root.s
                            name: "chevron-right"
                            color: navHover.hovered ? Theme.cream : Theme.iconDim
                            stroke: 2.2
                        }

                        /** Save chip for the inline edit; swaps in for the key chip and chevron. */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wrow.editing
                            width: 24 * root.s
                            height: 24 * root.s
                            radius: 7 * root.s
                            color: wSaveArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 13 * root.s
                                height: 13 * root.s
                                name: "check"
                                color: wSaveArea.containsMouse ? Theme.vermLit : Theme.iconDim
                                stroke: 2
                            }

                            MouseArea {
                                id: wSaveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveEdit()
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.hairSoft
                    }
                }
            }

            Repeater {
                model: root.customSpaces

                delegate: Item {
                    id: crow
                    required property int index
                    required property var modelData

                    readonly property bool last: crow.index === root.customSpaces.length - 1
                    readonly property bool editing: root.editId === crow.modelData.id
                    readonly property bool rebinding: root.rebindId === crow.modelData.id
                    readonly property bool keyHint: crow.rebinding || root.conflictId === crow.modelData.id

                    width: parent.width
                    height: editing ? 80 * root.s : (keyHint ? 66 * root.s : 50 * root.s)

                    onEditingChanged: if (editing) Qt.callLater(cEditBlock.field.forceActiveFocus)

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3 * root.s
                        anchors.bottomMargin: 3 * root.s
                        radius: 10 * root.s
                        color: (cHover.hovered || crow.editing) ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: (cHover.hovered || crow.editing) ? Theme.frameBorder : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    HoverHandler { id: cHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (crow.editing)
                                return;
                            if (crow.rebinding) {
                                root.rebindId = "";
                                root.listening = false;
                                return;
                            }
                            root.conflictId = "";
                            Spaces.editing = crow.modelData.id;
                            root.requestSurface("spaceapps");
                        }
                    }

                    GlyphIcon {
                        id: cGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !crow.editing
                        width: 16 * root.s
                        height: 16 * root.s
                        name: root.glyphFor(crow.modelData)
                        color: Theme.iconDim
                        stroke: 1.8
                    }

                    Column {
                        anchors.left: cGlyph.right
                        anchors.leftMargin: 10 * root.s
                        anchors.right: cRightRow.left
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * root.s

                        Column {
                            width: parent.width
                            spacing: 3 * root.s

                            Text {
                                id: cNameText
                                width: parent.width
                                visible: !crow.editing
                                text: crow.modelData.name
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12.5 * root.s
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight

                                /** Only the name itself opens rename; the rest of the row opens the app manager. */
                                MouseArea {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.min(cNameText.implicitWidth, cNameText.width)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEdit(crow.modelData.id, crow.modelData.name, root.glyphFor(crow.modelData))
                                }
                            }
                            Text {
                                width: parent.width
                                visible: !crow.editing && !crow.keyHint && crow.modelData.desc.length > 0
                                text: crow.modelData.desc
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                elide: Text.ElideRight
                            }
                            /** Live capture hint while the key chip listens; the clash message after. */
                            Text {
                                width: parent.width
                                visible: crow.keyHint
                                text: root.conflict.length > 0 ? root.conflict : "press a letter…  esc cancels"
                                color: root.conflict.length > 0 ? Theme.vermLit : Theme.flameGlow
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                elide: Text.ElideRight
                            }
                        }

                        EditBlock {
                            id: cEditBlock
                            width: parent.width
                            visible: crow.editing
                        }
                    }

                    Row {
                        id: cRightRow
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * root.s

                        Rectangle {
                            id: cRemove
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !crow.editing
                            width: 24 * root.s
                            height: 24 * root.s
                            radius: 7 * root.s
                            opacity: cHover.hovered ? 1 : 0
                            color: cRemoveArea.containsMouse ? Qt.alpha(Theme.verm, 0.16) : "transparent"
                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 12 * root.s
                                height: 12 * root.s
                                name: "close"
                                color: cRemoveArea.containsMouse ? Theme.vermLit : Theme.iconDim
                                stroke: 2
                            }

                            MouseArea {
                                id: cRemoveArea
                                anchors.fill: parent
                                enabled: cHover.hovered
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Spaces.removeSpace(crow.modelData.id)
                            }
                        }

                        /** Key chip: tapping starts an inline rebind capture for this space. */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !crow.editing
                            width: cKeyText.implicitWidth + 16 * root.s
                            height: cKeyText.implicitHeight + 8 * root.s
                            radius: 7 * root.s
                            color: crow.rebinding ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
                            border.width: 1
                            border.color: crow.rebinding ? Qt.alpha(Theme.vermLit, 0.55) : Theme.hairSoft
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            Text {
                                id: cKeyText
                                anchors.centerIn: parent
                                text: crow.rebinding ? "…" : "Super + " + crow.modelData.key
                                color: crow.rebinding ? Theme.flameGlow : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Bold
                                font.letterSpacing: 0.3 * root.s
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.rebind(crow.modelData.id)
                            }
                        }

                        /** Save chip for the inline edit; swaps in for the key chip and chevron. */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: crow.editing
                            width: 24 * root.s
                            height: 24 * root.s
                            radius: 7 * root.s
                            color: cSaveArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 13 * root.s
                                height: 13 * root.s
                                name: "check"
                                color: cSaveArea.containsMouse ? Theme.vermLit : Theme.iconDim
                                stroke: 2
                            }

                            MouseArea {
                                id: cSaveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveEdit()
                            }
                        }

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !crow.editing
                            width: 16 * root.s
                            height: 16 * root.s
                            name: "chevron-right"
                            color: cHover.hovered ? Theme.cream : Theme.iconDim
                            stroke: 2.2
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.hairSoft
                        visible: !crow.last
                    }
                }
            }

            Item { width: 1; height: 6 * root.s }

            AddBar {
                s: root.s
                text: "Add Workspace"
                onClicked: root.openForm()
            }
        }

        /** ── create form ── */

        Column {
            id: form
            width: parent.width
            visible: root.formOpen
            spacing: 10 * root.s

            BackHeader {
                s: root.s
                title: "NEW WORKSPACE"
                onBack: root.closeForm()
            }

            FormField {
                id: nameField
                s: root.s
                label: "NAME"
                placeholder: "Discord"
                text: root.formName
                onEdited: root.formName = nameField.text
                onCancelled: root.closeForm()
                onSubmitted: root.create()
            }

            FormField {
                id: descField
                s: root.s
                label: "DESCRIPTION"
                placeholder: "Chat (optional)"
                text: root.formDesc
                onEdited: root.formDesc = descField.text
                onCancelled: root.closeForm()
                onSubmitted: root.create()
            }

            FormField {
                s: root.s
                label: "KEYBIND"
                capture: true
                listening: root.listening
                value: root.formKey.length ? "Super + " + root.formKey : ""
                hint: "press a letter…  esc cancels"
                onTapped: {
                    root.conflict = "";
                    root.listening = true;
                }
            }

            Text {
                width: parent.width
                visible: root.conflict.length > 0
                text: root.conflict
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Item {
                width: parent.width
                height: 30 * root.s

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: cancelLabel.implicitWidth + 24 * root.s
                    height: 28 * root.s
                    radius: 8 * root.s
                    color: cancelArea.containsMouse ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: Theme.hairSoft

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.3 * root.s
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeForm()
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: createLabel.implicitWidth + 30 * root.s
                    height: 28 * root.s
                    radius: 8 * root.s
                    color: createArea.containsMouse ? Theme.vermLit : Theme.verm

                    Text {
                        id: createLabel
                        anchors.centerIn: parent
                        text: "Create"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.4 * root.s
                    }

                    MouseArea {
                        id: createArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.create()
                    }
                }
            }
        }

        Item { width: 1; height: 4 * root.s }
    }
}
