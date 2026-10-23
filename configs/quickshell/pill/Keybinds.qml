pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/binds.js" as Binds
import "lib/keychord.js" as Chord
import "Singletons"

/**
 * 鍵 Keybinds: searchable binds.lua list; a row or the add bar opens one form that writes only the changed facets on Save.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight

    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"

    readonly property real rowH: 38 * s
    readonly property int maxRows: 6

    property var binds: []
    property int focusIndex: 0
    property bool listening: false
    property string conflict: ""

    property string query: ""

    property bool formOpen: false
    property bool formAdd: false
    property int formLine: -1
    property bool formCmdEditable: true
    property string formAction: ""
    property string formCombo: ""
    property string formName: ""
    property string formCmd: ""
    property string origCombo: ""
    property string origName: ""
    property string origCmd: ""
    property string origAction: ""

    readonly property var filtered: {
        if (root.query.length === 0)
            return root.binds;
        var q = root.query.toLowerCase();
        return root.binds.filter(function (b) {
            return (b.combo + " " + b.label + " " + b.name + " " + b.cmd).toLowerCase().indexOf(q) !== -1;
        });
    }

    /** Footer hint built from the actions this view actually offers. */
    readonly property string hint: {
        var parts = [];
        if (root.formOpen)
            parts.push(root.formAdd ? "Enter adds" : "Enter saves");
        else if (root.filtered.length > 0)
            parts.push("Click or Enter to edit");
        parts.push(root.formOpen ? "Esc back" : "Esc close");
        return parts.join("  ·  ");
    }

    function comboPretty(c) {
        return Chord.pretty(c.replace("mouse_up", "Scroll ↑")
                .replace("mouse_down", "Scroll ↓")
                .replace("mouse:272", "Left drag")
                .replace("mouse:273", "Right drag"));
    }

    function refresh() {
        root.binds = Binds.parse(bindsFile.text());
        if (root.focusIndex >= root.filtered.length)
            root.focusIndex = Math.max(0, root.filtered.length - 1);
    }

    holdsFocus: listening

    function back() {
        if (!formOpen)
            return false;
        closeForm();
        return true;
    }

    function handleKey(e) {
        if (listening)
            return false;
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down)
            move(e.key === Qt.Key_Up ? -1 : 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (!e.isAutoRepeat)
                activate();
        } else
            return false;
        return true;
    }

    function move(dir) {
        if (root.listening || root.formOpen || root.filtered.length === 0)
            return;
        root.focusIndex = Math.max(0, Math.min(root.filtered.length - 1, root.focusIndex + dir));
        list.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    function activate() {
        if (root.listening || root.focusIndex < 0 || root.focusIndex >= root.filtered.length)
            return;
        openEdit(root.filtered[root.focusIndex]);
    }

    function openEdit(b) {
        if (b.isMouse)
            return;
        root.conflict = "";
        root.formAdd = false;
        root.formLine = b.lineIndex;
        root.formCmdEditable = b.isExec && b.cmd.length > 0;
        root.formAction = b.action;
        root.formCombo = b.combo;
        root.formName = b.name;
        root.formCmd = b.cmd;
        root.origCombo = b.combo;
        root.origName = b.name;
        root.origCmd = b.cmd;
        root.origAction = b.action;
        root.formOpen = true;
    }

    function openAdd() {
        root.conflict = "";
        root.listening = false;
        root.formAdd = true;
        root.formLine = -1;
        root.formCmdEditable = true;
        root.formAction = "";
        root.formCombo = "";
        root.formName = "";
        root.formCmd = "";
        root.origCombo = "";
        root.origName = "";
        root.origCmd = "";
        root.origAction = "";
        root.formOpen = true;
    }

    function closeForm() {
        root.formOpen = false;
        root.listening = false;
        root.conflict = "";
    }

    /** The chord lands in form state only; a bare modifier keeps capture waiting. */
    function capture(key, modifiers) {
        if (key === Qt.Key_Escape) {
            root.listening = false;
            return;
        }
        var combo = Chord.chord(key, modifiers);
        if (combo === null)
            return;
        root.formCombo = combo;
        root.conflict = "";
        root.listening = false;
        Qt.callLater(nameField.input.forceActiveFocus);
    }

    function taken(combo) {
        return Chord.pretty(combo) + " is already bound";
    }

    /** Add appends one exec line; edit folds only the changed facets into a single write. */
    function save() {
        var text = bindsFile.text();
        if (root.formAdd) {
            if (root.formCombo.length === 0) { root.conflict = "Pick a key first"; return; }
            if (root.formCmd.length === 0) { root.conflict = "Command is empty"; return; }
            if (Binds.inUse(text, root.formCombo, -1)) { root.conflict = root.taken(root.formCombo); return; }
            var a = Binds.add(text, root.formCombo, root.formCmd, root.formName);
            if (!a.ok) { root.conflict = a.error || "Could not add the bind"; return; }
            writer.setText(a.text);
            return;
        }

        if (root.formCombo !== root.origCombo && Binds.inUse(text, root.formCombo, root.formLine)) {
            root.conflict = root.taken(root.formCombo);
            return;
        }

        var out = text;
        if (root.formCombo !== root.origCombo) {
            var r = Binds.rebind(out, root.formLine, root.formCombo);
            if (!r.ok) { root.conflict = r.error || "Could not change the key"; return; }
            out = r.text;
        }
        if (root.formCmdEditable && root.formCmd !== root.origCmd) {
            if (root.formCmd.length === 0) { root.conflict = "Command is empty"; return; }
            var c = Binds.editCmd(out, root.formLine, root.formCmd);
            if (!c.ok) { root.conflict = c.error || "Could not change the command"; return; }
            out = c.text;
        }
        if (!root.formCmdEditable && root.formAction !== root.origAction) {
            if (root.formAction.trim().length === 0) { root.conflict = "Action is empty"; return; }
            var a2 = Binds.editAction(out, root.formLine, root.formAction.trim());
            if (!a2.ok) { root.conflict = a2.error || "Could not change the action"; return; }
            out = a2.text;
        }
        if (root.formName !== root.origName) {
            var n = Binds.editName(out, root.formLine, root.formName);
            if (!n.ok) { root.conflict = n.error || "Could not change the name"; return; }
            out = n.text;
        }

        if (out === text) {
            closeForm();
            return;
        }
        writer.setText(out);
    }

    function removeBind() {
        if (root.formAdd || root.formLine < 0)
            return;
        var d = Binds.del(bindsFile.text(), root.formLine);
        if (!d.ok) { root.conflict = d.error || "Could not delete the bind"; return; }
        writer.setText(d.text);
    }

    onActiveChanged: {
        if (active) {
            bindsFile.reload();
            refresh();
            focusIndex = 0;
            query = "";
        }
        listening = false;
        formOpen = false;
        conflict = "";
    }

    onFormOpenChanged: if (formOpen) Qt.callLater(nameField.input.forceActiveFocus)

    readonly property Item focusRowItem: list.focusRowItem

    readonly property bool rowFocused: focusRowItem !== null && active && !formOpen

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        void list.contentY;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    FileView {
        id: bindsFile
        path: root.bindsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    FileView {
        id: writer
        path: root.bindsPath
        atomicWrites: true
        printErrors: false
        onSaved: {
            HyprReload.request();
            root.closeForm();
            bindsFile.reload();
            root.refresh();
        }
        onSaveFailed: (err) => {
            root.conflict = "Could not write binds.lua";
            console.log("keybinds: write failed: " + err);
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
            glyph: "鍵"
            title: "Keybinds"
            crumb: root.formOpen ? (root.formAdd ? "New bind" : "Edit bind") : ""
            canBack: true
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        SearchField {
            width: parent.width
            height: 28 * root.s
            visible: !root.formOpen
            s: root.s
            kanji: "探"
            placeholder: "Search binds"
            kanjiSize: 15
            fontSize: Theme.fs.body
            gap: 9
            trail: 0
            lineGap: 3
            restOpacity: 0.18
            showCursor: true
            catchEscape: false
            onTextChanged: {
                root.query = text;
                root.focusIndex = 0;
            }
            onMoved: (d) => root.move(d)
            onAccepted: root.activate()
        }

        Item { width: 1; height: Theme.sp.s * root.s; visible: !root.formOpen }

        EmptyState {
            width: parent.width
            visible: !root.formOpen && root.filtered.length === 0
            s: root.s
            glyph: "keyboard"
            text: root.query.length > 0 ? "No binds match" : "No keybinds found"
        }

        ListView {
            id: list
            width: parent.width
            height: !root.formOpen ? Math.min(root.filtered.length, root.maxRows) * root.rowH : 0
            visible: !root.formOpen && root.filtered.length > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            model: root.filtered

            property Item focusRowItem: null

            delegate: Item {
                id: brow
                required property int index
                required property var modelData

                readonly property bool focused: root.focusIndex === brow.index
                readonly property bool editable: !brow.modelData.isMouse

                width: ListView.view.width
                height: root.rowH

                onFocusedChanged: if (focused) list.focusRowItem = brow

                HoverHandler {
                    id: rowHover
                    onHoveredChanged: if (hovered && !root.listening) root.focusIndex = brow.index
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3 * root.s
                    anchors.bottomMargin: 3 * root.s
                    radius: Theme.r.m * root.s
                    color: rowArea.pressed && brow.editable ? Theme.hair
                        : (rowHover.hovered || brow.focused) ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }

                KeyCap {
                    id: comboCaps
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.m * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    combo: root.comboPretty(brow.modelData.combo)
                }

                Item {
                    anchors.left: comboCaps.right
                    anchors.leftMargin: Theme.sp.m * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.m * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    height: labelText.implicitHeight

                    readonly property bool showCmd: rowHover.hovered && brow.modelData.cmd.length > 0

                    Text {
                        id: labelText
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        opacity: parent.showCmd ? 0 : 1
                        text: brow.modelData.label
                        color: brow.focused ? Theme.cream : Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.verticalCenter: labelText.verticalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        opacity: parent.showCmd ? 1 : 0
                        text: brow.modelData.cmd
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        elide: Text.ElideLeft
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    enabled: !root.listening
                    cursorShape: brow.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.focusIndex = brow.index;
                        root.openEdit(brow.modelData);
                    }
                }
            }
        }

        AddBar {
            visible: !root.formOpen
            s: root.s
            text: "Add keybind"
            onClicked: root.openAdd()
        }

        Column {
            id: form
            width: parent.width
            visible: root.formOpen
            spacing: 10 * root.s

            FormField {
                id: keyField
                s: root.s
                label: "Key"
                capture: true
                listening: root.listening
                /** A blank value keeps the field's own caption empty; the caps below draw the chord. */
                value: " "
                hint: "Press keys…  Esc cancels"
                onTapped: {
                    root.conflict = "";
                    root.listening = true;
                }

                KeyCap {
                    x: 11 * root.s
                    y: keyField.height - 13 * root.s - height / 2
                    visible: !root.listening
                    s: root.s
                    combo: root.formCombo.length > 0 ? root.comboPretty(root.formCombo) : ""
                }
            }

            FormField {
                id: nameField
                s: root.s
                label: "Name"
                placeholder: "Label (optional)"
                text: root.formName
                onEdited: root.formName = nameField.text
                onCancelled: root.closeForm()
                onSubmitted: root.save()
            }

            /** A non-exec bind edits its raw lua dispatch in the same box at a smaller size. */
            FormField {
                id: cmdField
                s: root.s
                label: root.formCmdEditable ? "Command" : "Action"
                fontSize: root.formCmdEditable ? Theme.fs.body : Theme.fs.meta
                placeholder: root.formCmdEditable ? "Shell command" : "Lua dispatch"
                text: root.formCmdEditable ? root.formCmd : root.formAction
                onEdited: {
                    if (root.formCmdEditable)
                        root.formCmd = cmdField.text;
                    else
                        root.formAction = cmdField.text;
                }
                onCancelled: root.closeForm()
                onSubmitted: root.save()
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

            Item {
                width: parent.width
                height: 28 * root.s

                Button {
                    anchors.left: parent.left
                    visible: !root.formAdd
                    s: root.s
                    kind: "danger"
                    text: "Delete"
                    onClicked: root.removeBind()
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
                        text: root.formAdd ? "Add" : "Save"
                        onClicked: root.save()
                    }
                }
            }
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hairSoft
        }

        Item {
            width: parent.width
            height: 20 * root.s

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp.xs * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.hint
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.label * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.labelTracking * root.s
            }
        }
    }
}
