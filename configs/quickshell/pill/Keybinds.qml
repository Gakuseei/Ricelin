pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "lib/binds.js" as Binds
import "lib/keychord.js" as Chord
import "Singletons"

/**
 * 鍵 KEYBINDS surface: a searchable list of the keyboard shortcuts parsed from
 * ~/.config/hypr/modules/binds.lua, each row a combo chip on the left and its
 * name or derived action on the right; hovering a row reveals the underlying
 * command. Tapping a row opens a unified form prefilled in EDIT mode — a
 * key-binding field that arms chord capture, a name field and a command field
 * — with Save and Delete. A dashed bar at the bottom opens the same form EMPTY
 * in ADD mode. Save folds the minimal set of binds.js calls (rebind / editCmd /
 * editName, or add) into one text and writes it; the write reloads Hyprland and
 * re-parses. A command is only editable when it is a single string literal
 * (`exec_cmd("...")`); a non-exec dispatch or an env-prefixed exec path is shown
 * read-only as the raw action so it can never be clobbered.
 *
 * The capture path mirrors the wallpaper strip's search handoff: while
 * `listening`, an Item with focus swallows every keystroke; the captured combo
 * is held in form state and only applied on Save, so a mistaken chord can be
 * retried without touching the file.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"

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

    /**
     * Binds whose combo, label, name or inner command contains the current query
     * as a case-insensitive substring. An empty query passes every bind through.
     */
    readonly property var filtered: {
        if (root.query.length === 0)
            return root.binds;
        var q = root.query.toLowerCase();
        return root.binds.filter(function (b) {
            return (b.combo + " " + b.label + " " + b.name + " " + b.cmd).toLowerCase().indexOf(q) !== -1;
        });
    }

    /**
     * Display form of a combo: mouse tokens are spelled out so a scroll or button
     * gesture reads clearly. These binds are shown read-only.
     */
    function comboPretty(c) {
        return c.replace("mouse_up", "Scroll ↑")
                .replace("mouse_down", "Scroll ↓")
                .replace("mouse:272", "LMB")
                .replace("mouse:273", "RMB");
    }

    function refresh() {
        root.binds = Binds.parse(bindsFile.text());
        if (root.focusIndex >= root.filtered.length)
            root.focusIndex = Math.max(0, root.filtered.length - 1);
    }

    /**
     * Slide the focused row by `dir` (+1 down, -1 up), clamped over the filtered
     * list, and keep it in view. No-op while a chord capture is live so the arrow
     * keys feed the catcher instead.
     */
    function move(dir) {
        if (root.listening || root.formOpen)
            return;
        if (root.filtered.length === 0)
            return;
        root.focusIndex = Math.max(0, Math.min(root.filtered.length - 1, root.focusIndex + dir));
        list.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    /**
     * Open the unified form in EDIT mode for the focused row, seeding form state
     * from the bind so Save can diff against the originals.
     */
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

    /**
     * Apply a captured chord to the form state (not the file). A bare modifier is
     * ignored so capture keeps waiting for the final key; Escape ends capture.
     */
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
        Qt.callLater(nameField.forceActiveFocus);
    }

    /**
     * Commit the form. ADD guards the combo against an existing bind, then writes
     * one appended exec line. EDIT folds only the changed facets — combo via
     * rebind, command via editCmd, name via editName — into a single text before
     * one write. A combo that collides with another bind is refused inline.
     */
    function save() {
        var text = bindsFile.text();
        if (root.formAdd) {
            if (root.formCombo.length === 0) { root.conflict = "pick a key"; return; }
            if (root.formCmd.length === 0) { root.conflict = "command empty"; return; }
            if (Binds.inUse(text, root.formCombo, -1)) {
                root.conflict = root.formCombo + " already bound";
                return;
            }
            var a = Binds.add(text, root.formCombo, root.formCmd, root.formName);
            if (!a.ok) { root.conflict = a.error || "add failed"; return; }
            writer.setText(a.text);
            return;
        }

        if (root.formCombo !== root.origCombo && Binds.inUse(text, root.formCombo, root.formLine)) {
            root.conflict = root.formCombo + " already bound";
            return;
        }

        var out = text;
        if (root.formCombo !== root.origCombo) {
            var r = Binds.rebind(out, root.formLine, root.formCombo);
            if (!r.ok) { root.conflict = r.error || "rebind failed"; return; }
            out = r.text;
        }
        if (root.formCmdEditable && root.formCmd !== root.origCmd) {
            if (root.formCmd.length === 0) { root.conflict = "command empty"; return; }
            var c = Binds.editCmd(out, root.formLine, root.formCmd);
            if (!c.ok) { root.conflict = c.error || "command edit failed"; return; }
            out = c.text;
        }
        if (!root.formCmdEditable && root.formAction !== root.origAction) {
            if (root.formAction.trim().length === 0) { root.conflict = "action empty"; return; }
            var a2 = Binds.editAction(out, root.formLine, root.formAction.trim());
            if (!a2.ok) { root.conflict = a2.error || "action edit failed"; return; }
            out = a2.text;
        }
        if (root.formName !== root.origName) {
            var n = Binds.editName(out, root.formLine, root.formName);
            if (!n.ok) { root.conflict = n.error || "name edit failed"; return; }
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
        if (!d.ok) { root.conflict = d.error || "delete failed"; return; }
        writer.setText(d.text);
    }

    onActiveChanged: {
        if (active) {
            bindsFile.reload();
            refresh();
            focusIndex = 0;
            listening = false;
            query = "";
            formOpen = false;
            conflict = "";
        } else {
            listening = false;
            formOpen = false;
            conflict = "";
        }
    }

    onFormOpenChanged: if (formOpen) Qt.callLater(nameField.forceActiveFocus)

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
            reloadProc.running = true;
            root.formOpen = false;
            root.listening = false;
            root.conflict = "";
            bindsFile.reload();
            root.refresh();
        }
        onSaveFailed: (err) => {
            root.conflict = "write failed";
            console.log("keybinds: write failed: " + err);
        }
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
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

        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "鍵"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KEYBINDS"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-left"
                color: Theme.iconDim
                stroke: 2.2
            }
        }

        Item { width: 1; height: 8 * root.s }

        Item {
            width: parent.width
            height: 28 * root.s
            visible: !root.formOpen

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "探"
                color: Theme.dim
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 15 * root.s
            }

            TextField {
                id: searchField
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                background: null
                padding: 0
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                placeholderText: "search binds"
                placeholderTextColor: Theme.faint
                selectByMouse: true
                selectionColor: Theme.verm
                onTextChanged: {
                    root.query = text;
                    root.focusIndex = 0;
                }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.move(1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.move(-1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activate();
                        e.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.left: searchField.left
                anchors.right: searchField.right
                anchors.top: searchField.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: Theme.faint
                opacity: searchField.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 8 * root.s }

        ListView {
            id: list
            width: parent.width
            height: visible ? Math.min(contentHeight, 250 * root.s) : 0
            visible: !root.formOpen
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered

            property Item focusRowItem: null

            delegate: Item {
                id: brow
                required property int index
                required property var modelData

                readonly property bool focused: root.focusIndex === brow.index

                width: ListView.view.width
                height: 38 * root.s

                onFocusedChanged: if (focused) list.focusRowItem = brow

                HoverHandler {
                    id: rowHover
                    onHoveredChanged: if (hovered && !root.listening) root.focusIndex = brow.index
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3 * root.s
                    anchors.bottomMargin: 3 * root.s
                    radius: 9 * root.s
                    color: (rowHover.hovered || brow.focused) ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    id: comboChip
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: comboText.implicitWidth + 16 * root.s
                    height: comboText.implicitHeight + 8 * root.s
                    radius: 7 * root.s
                    color: brow.focused ? Qt.alpha(Theme.vermLit, 0.16) : Theme.frameBg
                    border.width: 1
                    border.color: brow.focused ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        id: comboText
                        anchors.centerIn: parent
                        text: root.comboPretty(brow.modelData.combo)
                        color: brow.focused ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }
                }

                Column {
                    anchors.left: comboChip.right
                    anchors.leftMargin: 12 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        anchors.right: parent.right
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: brow.modelData.label
                        color: brow.focused ? Theme.subtle : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        visible: rowHover.hovered && brow.modelData.cmd.length > 0
                        text: brow.modelData.cmd
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Normal
                        elide: Text.ElideLeft
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.listening
                    cursorShape: brow.modelData.isMouse ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        root.focusIndex = brow.index;
                        root.openEdit(brow.modelData);
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 38 * root.s
            visible: !root.formOpen

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 5 * root.s
                anchors.bottomMargin: 5 * root.s
                radius: 9 * root.s
                color: addArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.1) : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, addArea.containsMouse ? 0.6 : 0.32)

                Row {
                    anchors.centerIn: parent
                    spacing: 6 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add keybind"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5 * root.s
                    }
                }

                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAdd()
                }
            }
        }

        Column {
            id: form
            width: parent.width
            visible: root.formOpen
            spacing: 10 * root.s

            Item {
                width: parent.width
                height: 22 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * root.s

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * root.s
                        height: 16 * root.s

                        GlyphIcon {
                            anchors.fill: parent
                            name: "chevron-left"
                            color: formBackArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 1.8
                        }

                        MouseArea {
                            id: formBackArea
                            anchors.fill: parent
                            anchors.margins: -6 * root.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeForm()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formAdd ? "NEW BIND" : "EDIT BIND"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.4 * root.s
                    }
                }
            }

            Item {
                width: parent.width
                height: 40 * root.s

                Text {
                    id: keyLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "KEY"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 26 * root.s
                    radius: 8 * root.s
                    color: root.listening ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
                    border.width: 1
                    border.color: root.listening ? Qt.alpha(Theme.vermLit, 0.55) : Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.listening ? "press keys…  esc cancels"
                            : (root.formCombo.length ? root.formCombo : "tap to set a key")
                        color: root.listening ? Theme.flameGlow
                            : (root.formCombo.length ? Theme.cream : Theme.faint)
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: root.formCombo.length ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.conflict = "";
                            root.listening = true;
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 40 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "NAME"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 26 * root.s
                    radius: 8 * root.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: nameField.activeFocus ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft

                    TextField {
                        id: nameField
                        anchors.left: parent.left
                        anchors.leftMargin: 11 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        placeholderText: "label (optional)"
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        text: root.formName
                        onTextEdited: root.formName = text
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) { root.closeForm(); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.save(); e.accepted = true; }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 40 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: root.formCmdEditable ? "COMMAND" : "ACTION"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 26 * root.s
                    radius: 8 * root.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: (cmdField.activeFocus || actionField.activeFocus) ? Qt.alpha(Theme.vermLit, 0.45) : Theme.hairSoft

                    TextField {
                        id: cmdField
                        visible: root.formCmdEditable
                        anchors.left: parent.left
                        anchors.leftMargin: 11 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        placeholderText: "shell command"
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        text: root.formCmd
                        onTextEdited: root.formCmd = text
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) { root.closeForm(); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.save(); e.accepted = true; }
                        }
                    }

                    TextField {
                        id: actionField
                        visible: !root.formCmdEditable
                        anchors.left: parent.left
                        anchors.leftMargin: 11 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        placeholderText: "lua dispatch"
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        text: root.formAction
                        onTextEdited: root.formAction = text
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) { root.closeForm(); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.save(); e.accepted = true; }
                        }
                    }
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
                    id: deleteBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.formAdd
                    width: deleteLabel.implicitWidth + 24 * root.s
                    height: 28 * root.s
                    radius: 8 * root.s
                    color: deleteArea.containsMouse ? Qt.alpha(Theme.verm, 0.2) : Qt.alpha(Theme.verm, 0.1)
                    border.width: 1
                    border.color: Qt.alpha(Theme.vermLit, 0.45)

                    Text {
                        id: deleteLabel
                        anchors.centerIn: parent
                        text: "Delete"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.3 * root.s
                    }

                    MouseArea {
                        id: deleteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeBind()
                    }
                }

                Rectangle {
                    id: saveBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: saveLabel.implicitWidth + 30 * root.s
                    height: 28 * root.s
                    radius: 8 * root.s
                    color: saveArea.containsMouse ? Theme.vermLit : Theme.verm

                    Text {
                        id: saveLabel
                        anchors.centerIn: parent
                        text: "Save"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.4 * root.s
                    }

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.save()
                    }
                }
            }
        }

        Item { width: 1; height: 9 * root.s }

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
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.formOpen ? "save · delete · esc back" : "tap edit · + add · esc close"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s
            }
        }
    }
}
