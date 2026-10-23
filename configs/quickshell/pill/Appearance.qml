pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

/**
 * 相 APPEARANCE: clock, glyphs, palette, app theme, wallpaper scope, UI scale, motion and font; Manual palette opens a hue editor debounced into wallcolors.py.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        var c = accentColor;
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        satArg = String(Flags.manualSat);
        applyTimer.restart();
    }

    function applyMode(v) {
        Flags.paletteMode = v;
        if (v === "manual")
            applyManual();
        else if (v === "dynamic")
            dynamicProc.rerun();
        else if (Flags.appTheme)
            syncApps();
    }

    function setAppTheme(v) {
        if (Flags.appTheme === v)
            return;
        Flags.appTheme = v;
        syncApps();
    }

    function syncApps() {
        appsProc.rerun();
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.rerun()
    }

    LatestProcess {
        id: appsProc
        environment: ({ RICELIN_PALETTE: Flags.paletteMode })
        command: ["sh", "-c", "python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" --apps \"$1\"",
            "sh", Flags.appTheme ? "on" : "off"]
    }

    LatestProcess {
        id: paletteProc
        environment: ({ RICELIN_PALETTE: Flags.paletteMode })
        command: ["sh", "-c",
            "python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" --hue \"$1\" \"$2\" \"$3\"; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    LatestProcess {
        id: dynamicProc
        environment: ({ RICELIN_PALETTE: Flags.paletteMode })
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper\"; pic=$(cat \"$f\" 2>/dev/null); case \"$pic\" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic=\"${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper-still.png\";; esac; [ -f \"$pic\" ] && python3 \"$HOME/.config/hypr/scripts/wallcolors.py\" \"$pic\" >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true"]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
    }

    rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: vizRow, kind: "toggle", get: function () { return Flags.musicViz; }, set: function (v) { Flags.musicViz = v; } },
        { item: paletteRow, kind: "seg", vals: ["static", "dynamic", "manual"], get: function () { return Flags.paletteMode; }, set: function (v) { root.applyMode(v); } },
        { item: appRow, kind: "toggle", get: function () { return Flags.appTheme; }, set: function (v) { root.setAppTheme(v); } },
        { item: randomRow, kind: "seg", vals: ["all", "cursor"], get: function () { return Flags.randomScope; }, set: function (v) { Flags.randomScope = v; } },
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: fontRow, kind: "nav", surface: "fontpicker" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            s: root.s
            glyph: "相"
            title: "APPEARANCE"
            canBack: true
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            icon: "clock"

            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: "Clock seconds"
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: glyphRow
            surface: root
            name: "Japanese glyphs"
            icon: "language"

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        SettingsRow {
            id: vizRow
            surface: root
            name: "Music visualizer"
            icon: "music"

            LinkToggle {
                s: root.s
                on: Flags.musicViz
                onToggled: Flags.musicViz = !Flags.musicViz
            }
        }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Palette"
            icon: "palette"

            SettingsSeg {
                s: root.s
                options: [{ label: "Static", value: "static" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: Flags.paletteMode
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, open only on the Manual palette; mouse-only, so it stays out of the row registry.
         */
        Item {
            id: manualSection
            width: parent.width
            height: Flags.paletteMode === "manual" ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.sp.m * root.s
                anchors.rightMargin: Theme.sp.m * root.s
                topPadding: Theme.sp.xs * root.s
                bottomPadding: Theme.sp.l * root.s
                spacing: Theme.sp.m * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: root.accentColor
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                            scale: hueArea.pressed && !Motion.calm ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: hueArea
                            anchors.fill: parent
                            anchors.topMargin: -Theme.sp.xs * root.s
                            anchors.bottomMargin: -Theme.sp.xs * root.s
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                if (Flags.manualSat < 0.05)
                                    Flags.manualSat = 0.5;
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(36 * root.s, toneSeg.implicitHeight)

                    Column {
                        anchors.left: parent.left
                        anchors.right: toneSeg.left
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp.xxs * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: Font.Medium
                        }
                        Row {
                            spacing: Theme.sp.xs * root.s

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8 * root.s
                                height: 8 * root.s
                                radius: height / 2
                                color: root.accentColor
                            }
                            Text {
                                text: root.currentHex + " · " + (Flags.manualDark ? "dark" : "light")
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.meta * root.s
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.manualDark
                        onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                    }
                }

                Item {
                    width: parent.width
                    height: 30 * root.s

                    Text {
                        id: hexHint
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: hexField
                        anchors.left: hexHint.right
                        anchors.leftMargin: Theme.sp.xs * root.s
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: root.currentHex.slice(1)
                        placeholderTextColor: Theme.textFaint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 7

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                var c = Qt.color("#" + clean);
                                if (c.hslHue >= 0) {
                                    Flags.manualHue = Math.round(c.hslHue * 359);
                                    Flags.manualSat = c.hslSaturation;
                                } else {
                                    Flags.manualSat = 0;
                                }
                                root.applyManual();
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()
                    }

                    Rectangle {
                        anchors.left: hexField.left
                        anchors.right: hexField.right
                        anchors.top: hexField.bottom
                        anchors.topMargin: Theme.sp.xs * root.s
                        height: 1
                        color: Theme.faint
                        opacity: hexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        SettingsRow {
            id: appRow
            surface: root
            name: "App theme"
            icon: "app-window"

            LinkToggle {
                s: root.s
                on: Flags.appTheme
                onToggled: root.setAppTheme(!Flags.appTheme)
            }
        }

        SettingsRow {
            id: randomRow
            surface: root
            name: "Random wallpaper"
            icon: "monitor"

            SettingsSeg {
                s: root.s
                options: [{ label: "All screens", value: "all" }, { label: "Cursor screen", value: "cursor" }]
                value: Flags.randomScope
                onPicked: (v) => Flags.randomScope = v
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            SettingsSeg {
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Reduce motion"
            icon: "pause"

            LinkToggle {
                s: root.s
                on: Flags.reduceMotion
                onToggled: Flags.reduceMotion = !Flags.reduceMotion
            }
        }

        SettingsRow {
            id: fontRow
            surface: root
            name: "Font"
            icon: "type"
            sub: Flags.uiFont.length > 0 ? Flags.uiFont : "Inter"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: fontRow.lit ? Theme.cream : Theme.iconDim
                stroke: 2
            }
        }
    }
}
