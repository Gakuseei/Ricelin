pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import "lib/keychord.js" as Chord
import "Singletons"

/**
 * 場 Workspaces: built-in and custom special spaces in one list; a name renames, a custom key cap rebinds, the add bar opens the create form.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight

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

    property int focusIndex: 0

    /** Preset glyph picks for a space; every name exists in GlyphIcon's map. */
    readonly property var glyphChoices: ["layers", "lock", "sparkles", "app-window", "waves", "moon", "sun", "palette", "mic", "speaker"]

    readonly property var builtins: [
        { id: "stash", name: "Stash", combo: "Super + S", note: "Background apps that open here", target: "stash", glyph: "layers" },
        { id: "private", name: "Private", combo: "Super + P", note: "Hidden scratchpad", target: "", glyph: "lock" },
        { id: "minimized", name: "Minimized", combo: "Super + Shift + M", note: "Minimized windows", target: "", glyph: "minimize" }
    ]

    /** Built-ins (with their spaces.lua display overrides) followed by the custom spaces, one shape for both. */
    readonly property var rows: {
        var sl = Spaces.list;
        var over = ({});
        var out = [];
        for (var i = 0; i < sl.length; i++)
            if (Spaces.reserved(sl[i].id))
                over[sl[i].id] = sl[i];
        for (var b = 0; b < root.builtins.length; b++) {
            var d = root.builtins[b];
            var e = over[d.id];
            out.push({ id: d.id, builtin: true, name: e ? e.name : d.name, glyph: e && root.glyphChoices.indexOf(e.glyph) >= 0 ? e.glyph : d.glyph,
                       note: d.note, combo: d.combo, target: d.target });
        }
        for (var c = 0; c < sl.length; c++) {
            var cs = sl[c];
            if (Spaces.reserved(cs.id))
                continue;
            out.push({ id: cs.id, builtin: false, name: cs.name, glyph: cs.glyph || "", note: cs.desc || "",
                       combo: cs.key.length ? "Super + " + cs.key : "", target: "spaceapps" });
        }
        return out;
    }

    holdsFocus: listening

    function back() {
        if (!formOpen)
            return false;
        closeForm();
        return true;
    }

    function handleKey(e) {
        if (listening || formOpen || editId.length > 0)
            return false;
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down)
            focusIndex = Math.max(0, Math.min(rows.length, focusIndex + (e.key === Qt.Key_Up ? -1 : 1)));
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (e.isAutoRepeat)
                return true;
            if (focusIndex < rows.length)
                activateRow(rows[focusIndex]);
            else
                openForm();
        } else
            return false;
        return true;
    }

    /** A row opens its surface; rows without one rename instead. */
    function activateRow(r) {
        if (root.editId === r.id)
            return;
        if (root.rebindId === r.id) {
            root.rebindId = "";
            root.listening = false;
            return;
        }
        root.conflictId = "";
        if (r.target === "spaceapps") {
            Spaces.editing = r.id;
            root.requestSurface("spaceapps");
        } else if (r.target.length > 0) {
            root.requestSurface(r.target);
        } else {
            root.openEdit(r.id, r.name, r.glyph);
        }
    }

    function openForm() {
        root.formName = "";
        root.formDesc = "";
        root.formKey = "";
        root.conflict = "";
        root.listening = false;
        root.rebindId = "";
        root.conflictId = "";
        root.editId = "";
        root.formOpen = true;
    }

    function closeForm() {
        root.formOpen = false;
        root.listening = false;
        root.conflict = "";
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

    function saveEdit() {
        var name = root.editName.trim();
        if (name.length > 0)
            Spaces.updateSpace(root.editId, name, root.editGlyph);
        root.closeEdit();
    }

    function rebind(id) {
        root.closeEdit();
        root.conflict = "";
        root.conflictId = "";
        root.rebindId = id;
        root.listening = true;
        keyCatcher.forceActiveFocus();
    }

    /** One A–Z letter (Super is implied); with a rebind armed it goes to that row after a clash check, else into the form. */
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
            root.conflict = "Single letters only";
            root.conflictId = root.rebindId;
            root.listening = false;
            root.rebindId = "";
            return;
        }
        if (root.rebindId.length > 0) {
            if (Spaces.keyTaken(name, root.rebindId)) {
                root.conflict = "Super + " + name + " is in use";
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

    function create() {
        var name = root.formName.trim();
        if (name.length === 0) { root.conflict = "Name is empty"; return; }
        var id = Spaces.slug(name);
        if (id.length === 0) { root.conflict = "Name needs a letter"; return; }
        if (Spaces.reserved(id)) { root.conflict = name + " is reserved"; return; }
        for (var i = 0; i < Spaces.list.length; i++)
            if (Spaces.list[i].id === id) { root.conflict = name + " already exists"; return; }
        if (!/^[A-Za-z]$/.test(root.formKey)) { root.conflict = "Pick a key"; return; }
        if (Spaces.keyTaken(root.formKey)) { root.conflict = "Super + " + root.formKey.toUpperCase() + " is in use"; return; }
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
        focusIndex = 0;
    }

    onFormOpenChanged: if (formOpen) Qt.callLater(nameField.input.forceActiveFocus)

    /** Inline rename plus glyph strip; Enter saves, Esc cancels. */
    component EditBlock: Column {
        id: editBlock

        property alias field: nameEdit

        spacing: 6 * root.s

        QQC.TextField {
            id: nameEdit
            width: parent.width
            background: null
            padding: 0
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * root.s
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
            spacing: Theme.sp.xs * root.s

            Repeater {
                model: root.glyphChoices

                delegate: Rectangle {
                    id: gchip
                    required property string modelData
                    readonly property bool on: root.editGlyph === modelData

                    width: 22 * root.s
                    height: 22 * root.s
                    radius: Theme.r.s * root.s
                    scale: gArea.pressed && !Motion.calm ? 0.94 : 1
                    color: gchip.on ? Qt.alpha(Theme.vermLit, 0.12) : (gArea.containsMouse ? Theme.frameBg : "transparent")
                    border.width: 1
                    border.color: gchip.on ? Qt.alpha(Theme.vermLit, 0.55) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

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

    /** Small square icon button for remove and save. */
    component IconButton: Rectangle {
        id: ib

        property string glyph: ""
        property real glyphSize: 13
        property bool warn: false

        signal clicked()

        width: 24 * root.s
        height: 24 * root.s
        radius: Theme.r.s * root.s
        scale: ibArea.pressed && !Motion.calm ? 0.94 : 1
        color: ibArea.containsMouse ? Qt.alpha(ib.warn ? Theme.verm : Theme.vermLit, ibArea.pressed ? 0.26 : 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        GlyphIcon {
            anchors.centerIn: parent
            width: ib.glyphSize * root.s
            height: ib.glyphSize * root.s
            name: ib.glyph
            color: ibArea.containsMouse ? Theme.vermLit : Theme.iconDim
            stroke: 2
        }

        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
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

        SurfaceHeader {
            s: root.s
            glyph: "場"
            title: "Workspaces"
            crumb: root.formOpen ? "New workspace" : ""
            canBack: true
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Column {
            id: listCol
            width: parent.width
            visible: !root.formOpen
            spacing: 0

            Repeater {
                model: root.rows

                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData

                    readonly property bool editing: root.editId === row.modelData.id
                    readonly property bool rebinding: root.rebindId === row.modelData.id
                    readonly property bool keyHint: row.rebinding || root.conflictId === row.modelData.id
                    readonly property bool focused: root.focusIndex === row.index
                    readonly property bool lit: row.editing || row.focused || rowHover.hovered

                    width: parent.width
                    height: (row.editing ? 80 : 50) * root.s

                    onEditingChanged: if (editing) Qt.callLater(rowEdit.field.forceActiveFocus)

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: if (hovered && !root.listening) root.focusIndex = row.index
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3 * root.s
                        anchors.bottomMargin: 3 * root.s
                        radius: Theme.r.m * root.s
                        color: rowArea.pressed && !row.editing ? Theme.hair : (row.lit ? Theme.frameBg : "transparent")
                        border.width: 1
                        border.color: row.lit ? Theme.frameBorder : "transparent"
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        enabled: !row.editing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateRow(row.modelData)
                    }

                    Item {
                        id: iconSlot
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20 * root.s
                        height: 20 * root.s
                        visible: !row.editing

                        GlyphIcon {
                            anchors.centerIn: parent
                            visible: row.modelData.glyph.length > 0
                            width: 16 * root.s
                            height: 16 * root.s
                            name: row.modelData.glyph
                            color: Theme.iconDim
                            stroke: 1.8
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: row.modelData.glyph.length === 0
                            radius: Theme.r.xs * root.s
                            color: Theme.tileBg
                            border.width: 1
                            border.color: Theme.hairSoft

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.name.length > 0 ? row.modelData.name.charAt(0).toUpperCase() : "?"
                                color: Theme.iconDim
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.meta * root.s
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 40 * root.s
                        anchors.right: rightRow.left
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            id: nameText
                            width: parent.width
                            visible: !row.editing
                            text: row.modelData.name
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight

                            /** Only the name itself renames; the rest of the row keeps its own target. */
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.min(nameText.implicitWidth, nameText.width)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEdit(row.modelData.id, row.modelData.name, row.modelData.glyph)
                            }
                        }

                        Text {
                            width: parent.width
                            visible: !row.editing && (row.keyHint || row.modelData.note.length > 0)
                            text: row.keyHint ? (root.conflict.length > 0 ? root.conflict : "Press a letter…  Esc cancels") : row.modelData.note
                            color: row.keyHint ? (root.conflict.length > 0 ? Theme.danger : Theme.flameGlow) : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            elide: Text.ElideRight
                        }

                        EditBlock {
                            id: rowEdit
                            width: parent.width
                            visible: row.editing
                        }
                    }

                    Row {
                        id: rightRow
                        anchors.right: parent.right
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp.s * root.s

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.modelData.builtin && !row.editing
                            enabled: rowHover.hovered
                            opacity: rowHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                            glyph: "close"
                            glyphSize: 12
                            warn: true
                            onClicked: Spaces.removeSpace(row.modelData.id)
                        }

                        /** Built-in keys live in binds.lua and only show here; a custom cap starts a rebind. */
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.editing
                            width: caps.width + 6 * root.s
                            height: caps.height + 6 * root.s
                            radius: Theme.r.m * root.s
                            color: row.rebinding ? Qt.alpha(Theme.vermLit, 0.12)
                                : (!row.modelData.builtin && capArea.containsMouse ? Theme.frameBg : "transparent")
                            border.width: 1
                            border.color: row.rebinding ? Qt.alpha(Theme.vermLit, 0.55) : "transparent"
                            scale: capArea.pressed && !Motion.calm ? 0.97 : 1
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            KeyCap {
                                id: caps
                                anchors.centerIn: parent
                                s: root.s
                                combo: row.rebinding ? "Super + …" : row.modelData.combo
                            }

                            MouseArea {
                                id: capArea
                                anchors.fill: parent
                                enabled: !row.modelData.builtin
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.rebind(row.modelData.id)
                            }
                        }

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !row.editing && row.modelData.target.length > 0
                            width: 16 * root.s
                            height: 16 * root.s
                            name: "chevron-right"
                            color: row.lit ? Theme.cream : Theme.iconDim
                            stroke: 2.2
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.editing
                            glyph: "check"
                            onClicked: root.saveEdit()
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.hairSoft
                        visible: row.index < root.rows.length - 1
                    }
                }
            }

            Item { width: 1; height: 6 * root.s }

            AddBar {
                s: root.s
                text: "Add workspace"
                lit: root.focusIndex === root.rows.length
                onClicked: root.openForm()
            }
        }

        Column {
            id: form
            width: parent.width
            visible: root.formOpen
            spacing: 10 * root.s

            FormField {
                id: nameField
                s: root.s
                label: "Name"
                placeholder: "Discord"
                text: root.formName
                onEdited: root.formName = nameField.text
                onCancelled: root.closeForm()
                onSubmitted: root.create()
            }

            FormField {
                id: descField
                s: root.s
                label: "Description"
                placeholder: "Chat (optional)"
                text: root.formDesc
                onEdited: root.formDesc = descField.text
                onCancelled: root.closeForm()
                onSubmitted: root.create()
            }

            FormField {
                id: keyField
                s: root.s
                label: "Keybind"
                capture: true
                listening: root.listening
                /** A blank value keeps the field's own caption empty; the caps below draw the chord. */
                value: " "
                hint: "Press a letter…  Esc cancels"
                onTapped: {
                    root.conflict = "";
                    root.listening = true;
                }

                KeyCap {
                    x: 11 * root.s
                    y: keyField.height - 13 * root.s - height / 2
                    visible: !root.listening
                    s: root.s
                    combo: root.formKey.length > 0 ? "Super + " + root.formKey : ""
                }
            }

            Text {
                width: parent.width
                visible: root.conflict.length > 0
                text: root.conflict
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.sp.s * root.s

                Button {
                    s: root.s
                    kind: "ghost"
                    text: "Cancel"
                    onClicked: root.closeForm()
                }
                Button {
                    s: root.s
                    kind: "primary"
                    text: "Create"
                    onClicked: root.create()
                }
            }
        }

        Item { width: 1; height: Theme.sp.xs * root.s }
    }
}
