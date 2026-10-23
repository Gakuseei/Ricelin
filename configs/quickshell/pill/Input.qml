pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setInput.js" as SetInput
import "Singletons"

/**
 * 操 INPUT: pointer and keyboard fields in input.lua, cursor size and theme applied live through hyprctl setcursor and persisted to env and autostart.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    /**
     * An exotic current layout joins the layout row's vals at the end, so a click wraps back to the curated list.
     */
    rows: [
        { item: sensRow, kind: "scrub", bump: function (d) { sensScrub.bump(d); } },
        { item: accelRow, kind: "seg", vals: ["flat", "adaptive"], get: function () { return root.accelProfile; }, set: function (v) { root.accelProfile = v; root.writeInputField("accel_profile", "\"" + v + "\""); } },
        { item: layoutRow, kind: "seg", vals: root.kbLayoutVals, get: function () { return root.kbLayout; }, set: function (v) { root.setKbLayout(v); } },
        { item: rateRow, kind: "scrub", bump: function (d) { rateScrub.bump(d); } },
        { item: delayRow, kind: "scrub", bump: function (d) { delayScrub.bump(d); } },
        { item: numlockRow, kind: "toggle", get: function () { return root.numlockOn; }, set: function (v) { root.numlockOn = v; root.writeInputField("numlock_by_default", v ? "true" : "false"); } },
        { item: sizeRow, kind: "scrub", bump: function (d) { sizeScrub.bump(d); } },
        { item: themePick.row, kind: "scrub", bump: function (d) { root.bumpTheme(d); }, activate: function () { root.themeOpen = !root.themeOpen; } }
    ]

    readonly property string note: HyprReload.failed ? "Hyprland reload failed. The change is saved but not applied." : ""

    readonly property string inputPath: Quickshell.env("HOME") + "/.config/hypr/modules/input.lua"
    readonly property string envPath: Quickshell.env("HOME") + "/.config/hypr/modules/env.lua"
    readonly property string autostartPath: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"

    property real sensitivity: 0
    property string accelProfile: "flat"
    property string kbLayout: "de"
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool numlockOn: false
    property int cursorSize: 24
    property string cursorTheme: "Bibata-Modern-Ice"
    property var cursorThemes: []
    property bool themeOpen: false

    property string inputText: ""
    property string envText: ""
    property string autostartText: ""

    /**
     * Per-field values captured on each open; the ScrubValue undo glyphs revert to these.
     */
    property var base: ({})

    readonly property var accelOptions: [
        { label: "Flat", value: "flat" },
        { label: "Adaptive", value: "adaptive" }
    ]

    readonly property var kbLayouts: ["de", "us", "gb", "fr", "es", "it", "tr"]

    function cycleLayout() {
        var i = root.kbLayoutVals.indexOf(root.kbLayout);
        root.setKbLayout(root.kbLayoutVals[(i + 1) % root.kbLayoutVals.length]);
    }

    function bumpTheme(d) {
        var n = root.cursorThemes.length;
        if (n === 0)
            return;
        var i = Math.max(0, Math.min(n - 1, root.cursorThemes.indexOf(root.cursorTheme) + d));
        if (root.cursorThemes[i] === root.cursorTheme)
            return;
        root.cursorTheme = root.cursorThemes[i];
        root.applyCursor(root.cursorTheme, root.cursorSize);
    }
    readonly property var kbLayoutVals: kbLayouts.indexOf(kbLayout) >= 0 ? kbLayouts : kbLayouts.concat([kbLayout])

    onActiveChanged: {
        if (active) {
            inputFile.reload();
            envFile.reload();
            autostartFile.reload();
            seed();
            themeProc.running = true;
        } else {
            themeOpen = false;
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Seeds every control from the live files, falling back to defaults for missing fields.
     */
    function seed() {
        root.inputText = inputFile.text();
        root.envText = envFile.text();
        root.autostartText = autostartFile.text();

        var inp = root.inputText;
        var sens = parseFloat(SetInput.getField(inp, "sensitivity"));
        root.sensitivity = isNaN(sens) ? 0 : sens;
        var ap = SetInput.getField(inp, "accel_profile");
        root.accelProfile = ap.length > 0 ? ap : "flat";
        var kl = SetInput.getField(inp, "kb_layout");
        root.kbLayout = kl.length > 0 ? kl : "de";
        var rr = parseInt(SetInput.getField(inp, "repeat_rate"), 10);
        root.repeatRate = isNaN(rr) ? 25 : rr;
        var rd = parseInt(SetInput.getField(inp, "repeat_delay"), 10);
        root.repeatDelay = isNaN(rd) ? 600 : rd;
        root.numlockOn = SetInput.getField(inp, "numlock_by_default") === "true";

        var env = root.envText;
        var cs = parseInt(SetInput.getField(env, "XCURSOR_SIZE"), 10);
        root.cursorSize = isNaN(cs) ? 24 : cs;
        var ct = SetInput.getField(env, "XCURSOR_THEME");
        root.cursorTheme = ct.length > 0 ? ct : "Bibata-Modern-Ice";

        root.base = {
            sensitivity: root.sensitivity,
            repeatRate: root.repeatRate,
            repeatDelay: root.repeatDelay,
            cursorSize: root.cursorSize
        };
    }

    function writeInputField(name, literal) {
        var res = SetInput.setField(root.inputText, name, literal);
        if (!res.ok)
            return;
        root.inputText = res.text;
        inputWriter.setText(res.text);
    }

    function setKbLayout(v) {
        root.kbLayout = v;
        root.writeInputField("kb_layout", "\"" + v + "\"");
    }

    /**
     * Applies the cursor live via hyprctl setcursor, then persists it to env and autostart; no reload needed.
     */
    function applyCursor(theme, size) {
        setcursorProc.theme = theme;
        setcursorProc.size = size;
        setcursorProc.rerun();

        var env = root.envText;
        var e1 = SetInput.setEnv(env, "XCURSOR_THEME", theme);
        var e2 = SetInput.setEnv(e1.ok ? e1.text : env, "XCURSOR_SIZE", String(size));
        var e3 = SetInput.setEnv(e2.ok ? e2.text : (e1.ok ? e1.text : env), "HYPRCURSOR_SIZE", String(size));
        if (e3.ok || e2.ok || e1.ok) {
            root.envText = e3.ok ? e3.text : (e2.ok ? e2.text : e1.text);
            envWriter.setText(root.envText);
        }

        var auto = SetInput.setCursorLine(root.autostartText, theme, size);
        if (auto.ok) {
            root.autostartText = auto.text;
            autostartWriter.setText(auto.text);
        }
    }

    FileView {
        id: inputFile
        path: root.inputPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: inputWriter
        path: root.inputPath
        atomicWrites: true
        printErrors: false
        onSaved: HyprReload.request()
    }

    FileView {
        id: envFile
        path: root.envPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: envWriter
        path: root.envPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: autostartFile
        path: root.autostartPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: autostartWriter
        path: root.autostartPath
        atomicWrites: true
        printErrors: false
    }

    LatestProcess {
        id: setcursorProc
        property string theme: ""
        property int size: 24
        command: ["hyprctl", "setcursor", theme, String(size)]
    }

    Process {
        id: themeProc
        command: ["sh", "-c", "{ printf '%s\\n' \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/share/icons; printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' '\\n' | sed 's#/*$#/icons#'; } | sort -u | while IFS= read -r d; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n").filter(function (l) { return l.trim().length > 0; });
                root.cursorThemes = lines;
            }
        }
    }

    component GroupLabel: SettingsLabel { s: root.s; leftPadding: Theme.sp.m * root.s }

    component FieldRow: SettingsRow { surface: root }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SurfaceHeader {
            s: root.s
            glyph: "操"
            title: "INPUT"
            canBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            GroupLabel { text: "Pointer" }

            FieldRow {
                id: sensRow
                label: "Sensitivity"
                caption: "Pointer speed offset"
                icon: "mouse"
                ScrubValue {
                    id: sensScrub
                    s: root.s
                    value: root.sensitivity
                    openValue: root.base.sensitivity
                    from: -1; to: 1; step: 0.1; decimals: 1
                    onEdited: v => {
                        root.sensitivity = v;
                        root.writeInputField("sensitivity", String(v));
                    }
                }
            }

            FieldRow {
                id: accelRow
                label: "Acceleration"
                caption: "How pointer speed follows motion"
                icon: "bolt"
                SettingsSeg {
                    s: root.s
                    options: root.accelOptions
                    value: root.accelProfile
                    onPicked: (v) => {
                        root.accelProfile = v;
                        root.writeInputField("accel_profile", "\"" + v + "\"");
                    }
                }
            }

            GroupLabel { text: "Keyboard" }

            FieldRow {
                id: layoutRow
                label: "Layout"
                caption: "Click to cycle common layouts"
                icon: "language"

                Button {
                    s: root.s
                    text: root.kbLayout
                    lit: root.focusRowItem === layoutRow
                    onClicked: root.cycleLayout()
                }
            }

            FieldRow {
                id: rateRow
                label: "Repeat rate"
                caption: "Key repeats per second when held"
                icon: "keyboard"
                ScrubValue {
                    id: rateScrub
                    s: root.s
                    value: root.repeatRate
                    openValue: root.base.repeatRate
                    from: 10; to: 80; step: 1; unit: "Hz"
                    onEdited: v => {
                        root.repeatRate = v;
                        root.writeInputField("repeat_rate", String(v));
                    }
                }
            }

            FieldRow {
                id: delayRow
                label: "Repeat delay"
                caption: "Hold time before a key repeats"
                icon: "stopwatch"
                ScrubValue {
                    id: delayScrub
                    s: root.s
                    value: root.repeatDelay
                    openValue: root.base.repeatDelay
                    from: 150; to: 1000; step: 25; unit: "ms"
                    onEdited: v => {
                        root.repeatDelay = v;
                        root.writeInputField("repeat_delay", String(v));
                    }
                }
            }

            FieldRow {
                id: numlockRow
                label: "Numlock"
                caption: "Numlock on at startup"
                icon: "lock"
                LinkToggle {
                    s: root.s
                    on: root.numlockOn
                    onToggled: {
                        root.numlockOn = !root.numlockOn;
                        root.writeInputField("numlock_by_default", root.numlockOn ? "true" : "false");
                    }
                }
            }

            GroupLabel { text: "Cursor" }

            FieldRow {
                id: sizeRow
                label: "Size"
                caption: "Cursor size in pixels"
                icon: "scaling"
                ScrubValue {
                    id: sizeScrub
                    s: root.s
                    value: root.cursorSize
                    openValue: root.base.cursorSize
                    from: 12; to: 96; step: 4; unit: "px"
                    onEdited: v => {
                        root.cursorSize = v;
                        root.applyCursor(root.cursorTheme, v);
                    }
                }
            }

            DisplayPicker {
                id: themePick
                surface: root
                icon: "cursor"
                name: "Theme"
                last: true
                chipWidth: 176
                options: root.cursorThemes.map(function (t) { return { label: t, value: t }; })
                value: root.cursorTheme
                open: root.themeOpen
                onRequestToggle: root.themeOpen = !root.themeOpen
                onPicked: (v) => {
                    root.cursorTheme = v;
                    root.themeOpen = false;
                    root.applyCursor(v, root.cursorSize);
                }
            }

            Text {
                width: parent.width
                topPadding: Theme.sp.s * root.s
                leftPadding: Theme.sp.m * root.s
                rightPadding: Theme.sp.m * root.s
                visible: root.note.length > 0
                text: root.note
                color: Theme.danger
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }
        }
    }
}
