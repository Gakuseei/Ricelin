import QtQuick
import "../Singletons"
import "PillDefaults.js" as Defaults
import "app.js" as App

AppPage {
    id: page
    pageId: "appearance"

    readonly property bool manual: Flags.paletteMode === "manual"
    readonly property bool dynamic: Flags.paletteMode === "dynamic"

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        const c = accentColor;
        const h = (x) => ("0" + Math.round(x * 255).toString(16)).slice(-2);
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    /** The only Noto families kept; the hundreds of per-script variants never serve as a UI font. */
    readonly property var notoKeep: ["Noto Sans", "Noto Serif", "Noto Sans Mono"]
    readonly property var fontOptions: {
        const seen = {};
        const out = [];
        for (const fam of Theme.fontFamilies) {
            if (!fam || fam.charAt(0) === "." || fam === "Inter" || seen[fam])
                continue;
            if (fam.indexOf("Noto ") === 0 && notoKeep.indexOf(fam) < 0)
                continue;
            seen[fam] = true;
            out.push(fam);
        }
        out.sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : 1);
        return [{ label: "Inter (default)", value: "Inter" }].concat(out.map(f => ({ label: f, value: f })));
    }

    readonly property var allModules: (Flags.idleModules || []).concat(Flags.hoverModules || [])
    readonly property bool hasGlyph: allModules.indexOf("glyph") >= 0
    readonly property bool hasBars: hasGlyph || allModules.indexOf("musicbars") >= 0

    function glyphCount(t) {
        return Array.from(String(t)).length;
    }

    Connections {
        target: Flags
        function onRestGlyphChanged() {
            if (!glyphField.input.activeFocus)
                glyphField.text = Flags.restGlyph;
        }
    }

    function set(k, v) {
        if (!Defaults.same(Flags[k], v))
            Flags[k] = Defaults.clone(v);
    }

    /** GTK theming stays as it is: the installer turns it on, so neither state is the obvious default. */
    function reset() {
        for (const k of Defaults.appearanceKeys)
            if (k !== "appTheme")
                set(k, Defaults.flags[k]);
    }

    function setHue(fraction) {
        const hue = Math.round(Math.max(0, Math.min(1, fraction)) * 359);
        if (Flags.manualSat < 0.05)
            set("manualSat", 0.5);
        set("manualHue", hue);
    }

    function setHex(raw) {
        const t = String(raw).trim();
        const clean = t.charAt(0) === "#" ? t.slice(1) : t;
        if (!/^[0-9a-fA-F]{6}$/.test(clean))
            return false;
        const c = Qt.color("#" + clean);
        if (c.hslHue >= 0) {
            set("manualHue", Math.round(c.hslHue * 359));
            set("manualSat", Math.round(c.hslSaturation * 100) / 100);
        } else {
            set("manualSat", 0);
        }
        return true;
    }

    /** Manual-only rows hide on other palettes, so a search for them lands on the palette switch. */
    function reveal(key) {
        const manualOnly = ["app.hue", "app.tone", "app.hex"];
        if ((manualOnly.indexOf(key) >= 0 && !manual) || (key === "app.strength" && !manual && !dynamic))
            key = "app.palette";
        if (key === "app.glyphText" && !Flags.showGlyphs)
            key = "app.glyphs";
        const row = rowMap[key];
        if (!row)
            return false;
        if (row.group && row.advanced && !row.group.showMore)
            row.group.expandNow();
        if (App.shell)
            App.shell.scrollToItem(row, true);
        return true;
    }

    AppGroup {
        title: "Palette"

        AppRow {
            label: "Palette"
            sub: "Static is the washi set; dynamic follows the wallpaper"
            key: "app.palette"

            AppSeg {
                s: page.s
                options: [{ label: "Static", value: "static" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: Flags.paletteMode
                onPicked: (v) => Flags.paletteMode = v
            }
        }

        AppRow {
            visible: page.manual
            label: "Accent hue"
            sub: "The color the whole palette is tinted from"
            key: "app.hue"
            block: true

            Item {
                width: parent.width
                height: 22 * page.s

                Rectangle {
                    id: hueStrip
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 14 * page.s
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
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18 * page.s
                        height: width
                        radius: width / 2
                        x: (Flags.manualHue / 359) * (hueStrip.width - width)
                        color: page.accentColor
                        border.width: 2.5 * page.s
                        border.color: Theme.cream
                        scale: hueArea.pressed && !Motion.calm ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: hueArea
                        anchors.fill: parent
                        anchors.topMargin: -5 * page.s
                        anchors.bottomMargin: -5 * page.s
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => page.setHue(mouse.x / hueStrip.width)
                        onPositionChanged: (mouse) => page.setHue(mouse.x / hueStrip.width)
                    }
                }
            }
        }

        AppRow {
            visible: page.manual
            label: "Tone"
            sub: "Dark or light surfaces"
            key: "app.tone"

            AppSeg {
                s: page.s
                options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                value: Flags.manualDark
                onPicked: (v) => Flags.manualDark = v
            }
        }

        AppRow {
            visible: page.manual
            label: "Hex color"
            sub: "Paste a color to take its hue and strength"
            key: "app.hex"

            Row {
                spacing: 10 * page.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * page.s
                    height: width
                    radius: width / 2
                    color: page.accentColor
                    border.width: 1
                    border.color: Theme.frameBorder
                }
                AppField {
                    id: hexField
                    s: page.s
                    fieldWidth: 110
                    mono: true
                    maxLength: 7
                    placeholder: page.currentHex
                    valid: text.length === 0 || /^#?[0-9a-fA-F]{0,6}$/.test(text)
                    onAccepted: (t) => {
                        if (t.length > 0)
                            page.setHex(t);
                        hexField.text = "";
                    }
                }
            }
        }

        AppRow {
            visible: page.manual || page.dynamic
            label: "Color strength"
            sub: page.manual ? "How vivid the accent and surfaces get; 0 is grey" : "How vivid the colors from the wallpaper get"
            key: "app.strength"

            AppSlider {
                s: page.s
                from: 0
                to: 100
                step: 5
                unit: "%"
                value: Math.round((page.manual ? Flags.manualSat : Flags.paletteVibrancy) * 100)
                onCommitted: (v) => {
                    if (page.manual)
                        page.set("manualSat", v / 100);
                    else
                        page.set("paletteVibrancy", v / 100);
                }
            }
        }

        advanced: [
            AppRow {
                label: "Theme GTK apps"
                sub: "GTK apps follow the pill palette"
                key: "app.gtk"

                AppToggle {
                    s: page.s
                    checked: Flags.appTheme
                    onToggled: (on) => Flags.appTheme = on
                }
            },
            AppRow {
                label: "Random wallpaper"
                sub: "Which screens Super + B repaints"
                key: "app.wallScope"

                AppSeg {
                    s: page.s
                    options: [{ label: "All monitors", value: "all" }, { label: "Under cursor", value: "cursor" }]
                    value: Flags.randomScope
                    onPicked: (v) => Flags.randomScope = v
                }
            }
        ]
    }

    AppGroup {
        title: "Glyphs and music"

        AppRow {
            label: "Show glyphs"
            sub: Flags.showGlyphs ? "Japanese characters in the pill, its menus and page titles"
                : "Off: icons stand in for the Japanese characters"
            key: "app.glyphs"

            AppToggle {
                s: page.s
                checked: Flags.showGlyphs
                onToggled: (on) => Flags.showGlyphs = on
            }
        }

        AppRow {
            visible: Flags.showGlyphs
            label: "Rest glyph"
            sub: page.hasGlyph ? "The character the Glyph module shows, one or two"
                : "Shows in the Glyph module, which your pill doesn't use"
            key: "app.glyphText"

            AppField {
                id: glyphField
                s: page.s
                fieldWidth: 64
                glyph: true
                maxLength: 4
                text: Flags.restGlyph
                valid: page.glyphCount(text.trim()) >= 1 && page.glyphCount(text.trim()) <= 2
                onAccepted: (t) => {
                    const v = t.trim();
                    if (page.glyphCount(v) >= 1 && page.glyphCount(v) <= 2)
                        page.set("restGlyph", v);
                    else
                        glyphField.text = Flags.restGlyph;
                }
            }
        }

        AppRow {
            label: "Music visualizer"
            sub: page.hasBars ? "Bars move with the music while something plays"
                : "Needs the Glyph or Music bars module in your pill"
            key: "app.viz"

            Row {
                spacing: 12 * page.s

                AppButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !page.hasBars
                    s: page.s
                    small: true
                    icon: "plus"
                    text: "Add to idle"
                    onClicked: {
                        page.set("idleModules", (Flags.idleModules || []).concat(["musicbars"]));
                        page.set("musicViz", true);
                        App.toast("Music bars added to the idle pill");
                    }
                }
                AppToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    s: page.s
                    checked: Flags.musicViz
                    onToggled: (on) => Flags.musicViz = on
                }
            }
        }

        advanced: [
            AppRow {
                label: "Music bars"
                sub: "How many bars the visualizer draws"
                key: "app.bars"

                AppSeg {
                    s: page.s
                    options: [{ label: "3", value: 3 }, { label: "5", value: 5 }, { label: "7", value: 7 }]
                    value: Flags.musicBars
                    onPicked: (v) => Flags.musicBars = v
                }
            }
        ]
    }

    AppGroup {
        title: "Type and icons"

        AppRow {
            label: "UI font"
            sub: "Falls back to Inter when the font is missing"
            key: "app.font"

            AppSelect {
                s: page.s
                minWidth: 230
                fontPreview: true
                options: page.fontOptions
                value: Flags.uiFont.length > 0 ? Flags.uiFont : "Inter"
                onPicked: (v) => Flags.uiFont = v === "Inter" ? "" : v
            }
        }

        advanced: [
            AppRow {
                label: "Line weight"
                sub: "How thick every icon line is drawn"
                key: "app.lineWeight"

                AppSlider {
                    s: page.s
                    from: 0.75
                    to: 1.4
                    step: 0.05
                    decimals: 2
                    unit: "×"
                    value: Flags.iconWeight
                    onMoved: (v) => Flags.iconWeight = v
                    onCommitted: (v) => page.set("iconWeight", v)
                }
            }
        ]
    }

    AppGroup {
        title: "Motion"

        AppRow {
            label: "Reduce motion"
            sub: "Shapes change in place and only fade; nothing slides, bounces or loops"
            key: "app.reduceMotion"

            AppToggle {
                s: page.s
                checked: Flags.reduceMotion
                onToggled: (on) => Flags.reduceMotion = on
            }
        }
    }
}
