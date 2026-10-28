pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../lib/setInput.js" as SetInput
import "../Singletons"

AppPage {
    id: page
    pageId: "input"

    readonly property string inputPath: Quickshell.env("HOME") + "/.config/hypr/modules/input.lua"
    readonly property string envPath: Quickshell.env("HOME") + "/.config/hypr/modules/env.lua"
    readonly property string autostartPath: Quickshell.env("HOME") + "/.config/hypr/modules/autostart.lua"

    property string inputText: ""
    property string envText: ""
    property string autostartText: ""

    property real sensitivity: 0
    property string accelProfile: "flat"
    property string kbLayout: "de"
    property int repeatRate: 40
    property int repeatDelay: 400
    property bool numlockOn: false
    property int cursorSize: 24
    property string cursorTheme: "Bibata-Modern-Ice"
    property var cursorThemes: []

    readonly property var defaults: ({ sensitivity: 0, accelProfile: "flat", repeatRate: 40, repeatDelay: 400, numlockOn: false, cursorSize: 24, cursorTheme: "Bibata-Modern-Ice" })

    readonly property var layouts: [
        { label: "German", value: "de" }, { label: "English (US)", value: "us" }, { label: "English (UK)", value: "gb" },
        { label: "French", value: "fr" }, { label: "Spanish", value: "es" }, { label: "Italian", value: "it" },
        { label: "Turkish", value: "tr" }
    ]
    readonly property var layoutOptions: layouts.some(o => o.value === kbLayout) ? layouts : layouts.concat([{ label: kbLayout, value: kbLayout }])

    readonly property var themeOptions: {
        const list = cursorThemes.indexOf(cursorTheme) >= 0 || cursorTheme.length === 0 ? cursorThemes : cursorThemes.concat([cursorTheme]);
        return list.map(t => ({ label: t.replace(/[-_]+/g, " "), value: t }));
    }

    Component.onCompleted: seed()

    function num(v, fallback) {
        const n = parseFloat(v);
        return isNaN(n) ? fallback : n;
    }

    /** env.lua holds `hl.env("KEY", "value")` calls, which the `key = value` reader cannot see. */
    function envValue(text, key) {
        const m = new RegExp("hl\\.env\\(\\s*\"" + key + "\"\\s*,\\s*\"([^\"]*)\"").exec(text);
        return m ? m[1] : "";
    }

    function seed() {
        inputText = inputFile.text();
        envText = envFile.text();
        autostartText = autostartFile.text();
        const t = inputText;
        const d = defaults;
        sensitivity = num(SetInput.getField(t, "sensitivity"), d.sensitivity);
        const ap = SetInput.getField(t, "accel_profile");
        accelProfile = ap.length > 0 ? ap : d.accelProfile;
        const kl = SetInput.getField(t, "kb_layout");
        kbLayout = kl.length > 0 ? kl : "de";
        repeatRate = num(SetInput.getField(t, "repeat_rate"), d.repeatRate);
        repeatDelay = num(SetInput.getField(t, "repeat_delay"), d.repeatDelay);
        numlockOn = SetInput.getField(t, "numlock_by_default") === "true";
        cursorSize = num(envValue(envText, "XCURSOR_SIZE"), d.cursorSize);
        const ct = envValue(envText, "XCURSOR_THEME");
        cursorTheme = ct.length > 0 ? ct : d.cursorTheme;
    }

    function writeInputField(name, literal) {
        const r = SetInput.setField(inputText, name, literal);
        if (!r.ok)
            return;
        inputText = r.text;
        inputWriter.put(r.text);
    }

    function applyCursor(theme, size) {
        setcursorProc.theme = theme;
        setcursorProc.size = size;
        setcursorProc.rerun();

        let env = envText;
        let wrote = false;
        const pairs = [["XCURSOR_THEME", theme], ["XCURSOR_SIZE", String(size)], ["HYPRCURSOR_SIZE", String(size)]];
        for (let i = 0; i < pairs.length; i++) {
            const r = SetInput.setEnv(env, pairs[i][0], pairs[i][1]);
            if (r.ok) {
                env = r.text;
                wrote = true;
            }
        }
        if (wrote) {
            envText = env;
            envWriter.put(env);
        }
        const auto = SetInput.setCursorLine(autostartText, theme, size);
        if (auto.ok) {
            autostartText = auto.text;
            autostartWriter.put(auto.text);
        }
    }

    function reset() {
        const d = defaults;
        let t = inputText;
        const fields = [["sensitivity", String(d.sensitivity)], ["accel_profile", "\"" + d.accelProfile + "\""],
            ["repeat_rate", String(d.repeatRate)], ["repeat_delay", String(d.repeatDelay)], ["numlock_by_default", String(d.numlockOn)]];
        for (let i = 0; i < fields.length; i++) {
            const r = SetInput.setField(t, fields[i][0], fields[i][1]);
            if (r.ok)
                t = r.text;
        }
        sensitivity = d.sensitivity;
        accelProfile = d.accelProfile;
        repeatRate = d.repeatRate;
        repeatDelay = d.repeatDelay;
        numlockOn = d.numlockOn;
        if (t !== inputText) {
            inputText = t;
            inputWriter.put(t);
        }
        const theme = cursorThemes.indexOf(d.cursorTheme) >= 0 ? d.cursorTheme : cursorTheme;
        if (theme !== cursorTheme || cursorSize !== d.cursorSize) {
            cursorTheme = theme;
            cursorSize = d.cursorSize;
            applyCursor(theme, d.cursorSize);
        }
    }

    FileView {
        id: inputFile
        path: page.inputPath
        blockLoading: true
        printErrors: false
    }
    Writer {
        id: inputWriter
        path: page.inputPath
        onWritten: HyprReload.request()
    }
    FileView {
        id: envFile
        path: page.envPath
        blockLoading: true
        printErrors: false
    }
    Writer {
        id: envWriter
        path: page.envPath
    }
    FileView {
        id: autostartFile
        path: page.autostartPath
        blockLoading: true
        printErrors: false
    }
    Writer {
        id: autostartWriter
        path: page.autostartPath
    }

    /** Atomic writer that keeps one write in flight, so a quick second edit can never land before the first. */
    component Writer: FileView {
        property string queued: ""
        property bool busy: false
        property bool more: false
        signal written()
        preload: false
        atomicWrites: true
        printErrors: false
        function put(t) {
            if (busy) {
                queued = t;
                more = true;
                return;
            }
            busy = true;
            setText(t);
        }
        function settle() {
            busy = false;
            if (more) {
                more = false;
                put(queued);
            } else {
                written();
            }
        }
        onSaved: Qt.callLater(settle)
        onSaveFailed: Qt.callLater(settle)
    }

    LatestProcess {
        id: setcursorProc
        property string theme: ""
        property int size: 24
        command: ["hyprctl", "setcursor", theme, String(size)]
    }

    Process {
        id: themeProc
        running: true
        command: ["sh", "-c", "{ printf '%s\\n' \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/share/icons; printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' '\\n' | sed 's#/*$#/icons#'; } | sort -u | while IFS= read -r d; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t/cursors\" ] && basename \"$t\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: page.cursorThemes = this.text.split("\n").filter(l => l.trim().length > 0)
        }
    }

    Text {
        x: 12 * page.s
        width: parent.width - 24 * page.s
        topPadding: 16 * page.s
        visible: HyprReload.failed
        text: "Hyprland could not reload. Changes are saved but not applied yet."
        color: Theme.danger
        wrapMode: Text.WordWrap
        font.family: Theme.font
        font.pixelSize: 12 * page.s
    }

    AppGroup {
        title: "Devices"

        AppRow {
            label: "Connected devices"
            sub: "Polling rate is set on the device itself"
            key: "input.devices"
            block: true
            PageInputDevices {}
        }
    }

    AppGroup {
        title: "Pointer"

        AppRow {
            label: "Sensitivity"
            sub: "How fast the pointer moves, 0 is unchanged"
            key: "input.sensitivity"
            AppSlider {
                from: -1; to: 1; step: 0.05; decimals: 2
                value: page.sensitivity
                onMoved: (v) => { page.sensitivity = v; page.writeInputField("sensitivity", String(v)); }
            }
        }
        AppRow {
            label: "Acceleration"
            sub: "Adaptive speeds up quick flicks, flat keeps it even"
            key: "input.accel"
            AppSeg {
                options: [{ label: "Flat", value: "flat" }, { label: "Adaptive", value: "adaptive" }]
                value: page.accelProfile
                onPicked: (v) => { page.accelProfile = v; page.writeInputField("accel_profile", "\"" + v + "\""); }
            }
        }
    }

    AppGroup {
        title: "Keyboard"

        AppRow {
            label: "Layout"
            sub: "Which letters your keys type"
            key: "input.layout"
            AppSelect {
                options: page.layoutOptions
                value: page.kbLayout
                onPicked: (v) => { page.kbLayout = v; page.writeInputField("kb_layout", "\"" + v + "\""); }
            }
        }

        advanced: [
            AppRow {
                label: "Repeat rate"
                sub: "Characters per second while a key is held"
                key: "input.repeatRate"
                AppSlider {
                    from: 10; to: 80; step: 1
                    fmt: (v) => v + "/s"
                    value: page.repeatRate
                    onMoved: (v) => { page.repeatRate = v; page.writeInputField("repeat_rate", String(v)); }
                }
            },
            AppRow {
                label: "Repeat delay"
                sub: "How long to hold a key before it repeats"
                key: "input.repeatDelay"
                AppSlider {
                    from: 150; to: 1000; step: 25; unit: "ms"
                    value: page.repeatDelay
                    onMoved: (v) => { page.repeatDelay = v; page.writeInputField("repeat_delay", String(v)); }
                }
            },
            AppRow {
                label: "Numlock on start"
                sub: "Turn numlock on when you log in"
                key: "input.numlock"
                clickable: true
                onClicked: numlockToggle.flip()
                AppToggle {
                    id: numlockToggle
                    checked: page.numlockOn
                    onToggled: (on) => { page.numlockOn = on; page.writeInputField("numlock_by_default", on ? "true" : "false"); }
                }
            }
        ]
    }

    AppGroup {
        title: "Cursor"

        AppRow {
            label: "Cursor size"
            sub: "How big the mouse pointer is"
            key: "input.cursorSize"
            AppSlider {
                from: 12; to: 96; step: 4; unit: "px"
                value: page.cursorSize
                onMoved: (v) => { page.cursorSize = v; page.applyCursor(page.cursorTheme, v); }
            }
        }
        AppRow {
            label: "Cursor theme"
            sub: "The look of the mouse pointer, from your installed themes"
            key: "input.cursorTheme"
            AppSelect {
                minWidth: 240
                options: page.themeOptions
                value: page.cursorTheme
                placeholder: "No cursor themes found"
                onPicked: (v) => { page.cursorTheme = v; page.applyCursor(v, page.cursorSize); }
            }
        }
    }
}
