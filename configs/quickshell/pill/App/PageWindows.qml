pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../lib/setDeco.js" as SetDeco
import "../Singletons"

AppPage {
    id: page
    pageId: "windows"

    readonly property string decoPath: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    property string decoText: ""

    property int gapsIn: 6
    property int gapsOut: 12
    property int rounding: 12
    property int roundingPower: 4
    property int borderSize: 2
    property bool resizeOnBorder: true
    property string layout: "dwindle"
    property bool shadowOn: true
    property int shadowRange: 12
    property int shadowRenderPower: 3
    property bool blurOn: true
    property int blurSize: 8
    property int blurPasses: 3
    property real blurVibrancy: 0.17
    property real blurNoise: 0.01
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0

    readonly property var defaults: ({
        gapsIn: 6, gapsOut: 12, rounding: 12, roundingPower: 4, borderSize: 2, resizeOnBorder: true, layout: "dwindle",
        shadowOn: true, shadowRange: 12, shadowRenderPower: 3,
        blurOn: true, blurSize: 8, blurPasses: 3, blurVibrancy: 0.17, blurNoise: 0.01,
        activeOpacity: 1.0, inactiveOpacity: 1.0,
        nightMode: "off", nightTemp: 4000, nightOn: 1260, nightOff: 450
    })

    Component.onCompleted: seed()

    function num(v, fallback) {
        const n = parseFloat(v);
        return isNaN(n) ? fallback : n;
    }

    function seed() {
        const t = decoFile.text();
        decoText = t;
        const d = defaults;
        gapsIn = num(SetDeco.getField(t, "gaps_in"), d.gapsIn);
        gapsOut = num(SetDeco.getField(t, "gaps_out"), d.gapsOut);
        rounding = num(SetDeco.getField(t, "rounding"), d.rounding);
        roundingPower = num(SetDeco.getField(t, "rounding_power"), d.roundingPower);
        borderSize = num(SetDeco.getField(t, "border_size"), d.borderSize);
        resizeOnBorder = SetDeco.getField(t, "resize_on_border") === "true";
        const lo = SetDeco.getField(t, "layout");
        layout = lo.length > 0 ? lo : d.layout;
        shadowOn = SetDeco.getBlockField(t, "shadow", "enabled") === "true";
        shadowRange = num(SetDeco.getBlockField(t, "shadow", "range"), d.shadowRange);
        shadowRenderPower = num(SetDeco.getBlockField(t, "shadow", "render_power"), d.shadowRenderPower);
        blurOn = SetDeco.getBlockField(t, "blur", "enabled") === "true";
        blurSize = num(SetDeco.getBlockField(t, "blur", "size"), d.blurSize);
        blurPasses = num(SetDeco.getBlockField(t, "blur", "passes"), d.blurPasses);
        blurVibrancy = num(SetDeco.getBlockField(t, "blur", "vibrancy"), d.blurVibrancy);
        blurNoise = num(SetDeco.getBlockField(t, "blur", "noise"), d.blurNoise);
        activeOpacity = num(SetDeco.getField(t, "active_opacity"), d.activeOpacity);
        inactiveOpacity = num(SetDeco.getField(t, "inactive_opacity"), d.inactiveOpacity);
    }

    function save(text) {
        decoText = text;
        decoWriter.put(text);
    }

    function writeDeco(name, literal) {
        const r = SetDeco.setField(decoText, name, literal);
        if (r.ok)
            save(r.text);
    }

    /** Blur and shadow both hold `enabled`, so their fields are scoped to the block. */
    function writeBlock(block, name, literal) {
        const r = SetDeco.setBlockField(decoText, block, name, literal);
        if (r.ok)
            save(r.text);
    }

    /** A plain reload leaves unfocused windows on their stale alpha, so both opacities also go out live. */
    function writeOpacity(name, literal) {
        writeDeco(name, literal);
        opacityLive.rerun();
    }

    function setOpacity(active, v) {
        if (active)
            activeOpacity = v;
        else
            inactiveOpacity = v;
        writeOpacity(active ? "active_opacity" : "inactive_opacity", v.toFixed(2));
    }

    function fmtClock(v) {
        const h = Math.floor(v / 60);
        const m = v % 60;
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    function reset() {
        const d = defaults;
        let t = decoText;
        const top = [["gaps_in", d.gapsIn], ["gaps_out", d.gapsOut], ["border_size", d.borderSize], ["layout", "\"" + d.layout + "\""],
            ["resize_on_border", String(d.resizeOnBorder)], ["rounding", d.rounding], ["rounding_power", d.roundingPower],
            ["active_opacity", d.activeOpacity.toFixed(2)], ["inactive_opacity", d.inactiveOpacity.toFixed(2)]];
        for (let i = 0; i < top.length; i++) {
            const r = SetDeco.setField(t, top[i][0], String(top[i][1]));
            if (r.ok)
                t = r.text;
        }
        const blocks = [["shadow", "enabled", String(d.shadowOn)], ["shadow", "range", d.shadowRange], ["shadow", "render_power", d.shadowRenderPower],
            ["blur", "enabled", String(d.blurOn)], ["blur", "size", d.blurSize], ["blur", "passes", d.blurPasses],
            ["blur", "vibrancy", d.blurVibrancy.toFixed(2)], ["blur", "noise", d.blurNoise.toFixed(2)]];
        for (let i = 0; i < blocks.length; i++) {
            const r = SetDeco.setBlockField(t, blocks[i][0], blocks[i][1], String(blocks[i][2]));
            if (r.ok)
                t = r.text;
        }
        gapsIn = d.gapsIn;
        gapsOut = d.gapsOut;
        rounding = d.rounding;
        roundingPower = d.roundingPower;
        borderSize = d.borderSize;
        resizeOnBorder = d.resizeOnBorder;
        layout = d.layout;
        shadowOn = d.shadowOn;
        shadowRange = d.shadowRange;
        shadowRenderPower = d.shadowRenderPower;
        blurOn = d.blurOn;
        blurSize = d.blurSize;
        blurPasses = d.blurPasses;
        blurVibrancy = d.blurVibrancy;
        blurNoise = d.blurNoise;
        activeOpacity = d.activeOpacity;
        inactiveOpacity = d.inactiveOpacity;
        if (t !== decoText)
            save(t);
        opacityLive.rerun();
        if (Flags.nightLightTemp !== d.nightTemp)
            NightLight.setTemp(d.nightTemp);
        if (Flags.nightLightOnMin !== d.nightOn)
            NightLight.setOnMin(d.nightOn);
        if (Flags.nightLightOffMin !== d.nightOff)
            NightLight.setOffMin(d.nightOff);
        if (Flags.nightLightMode !== d.nightMode)
            NightLight.setMode(d.nightMode);
    }

    FileView {
        id: decoFile
        path: page.decoPath
        blockLoading: true
        printErrors: false
    }

    Writer {
        id: decoWriter
        path: page.decoPath
        onWritten: HyprReload.request()
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
        id: opacityLive
        command: ["hyprctl", "eval", "hl.config({ decoration = { active_opacity = " + page.activeOpacity.toFixed(2)
            + ", inactive_opacity = " + page.inactiveOpacity.toFixed(2) + " } })"]
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
        title: "Windows"

        AppRow {
            label: "Inner gaps"
            sub: "Space between tiled windows"
            key: "windows.gapsIn"
            AppSlider {
                from: 0; to: 40; step: 1; unit: "px"
                value: page.gapsIn
                onMoved: (v) => { page.gapsIn = v; page.writeDeco("gaps_in", String(v)); }
            }
        }
        AppRow {
            label: "Outer gaps"
            sub: "Space between windows and the screen edge"
            key: "windows.gapsOut"
            AppSlider {
                from: 0; to: 60; step: 1; unit: "px"
                value: page.gapsOut
                onMoved: (v) => { page.gapsOut = v; page.writeDeco("gaps_out", String(v)); }
            }
        }
        AppRow {
            label: "Rounding"
            sub: "How round window corners are"
            key: "windows.rounding"
            AppSlider {
                from: 0; to: 30; step: 1; unit: "px"
                value: page.rounding
                onMoved: (v) => { page.rounding = v; page.writeDeco("rounding", String(v)); }
            }
        }
        AppRow {
            label: "Layout"
            sub: "How new windows split the screen"
            key: "windows.layout"
            AppSeg {
                options: [{ label: "Dwindle", value: "dwindle" }, { label: "Master", value: "master" }]
                value: page.layout
                onPicked: (v) => { page.layout = v; page.writeDeco("layout", "\"" + v + "\""); }
            }
        }

        advanced: [
            AppRow {
                label: "Border size"
                sub: "Thickness of the coloured window outline"
                key: "windows.borderSize"
                AppSlider {
                    from: 0; to: 8; step: 1; unit: "px"
                    value: page.borderSize
                    onMoved: (v) => { page.borderSize = v; page.writeDeco("border_size", String(v)); }
                }
            },
            AppRow {
                label: "Rounding power"
                sub: "Higher bends corners toward a squircle"
                key: "windows.roundingPower"
                AppSlider {
                    from: 1; to: 10; step: 1
                    value: page.roundingPower
                    onMoved: (v) => { page.roundingPower = v; page.writeDeco("rounding_power", String(v)); }
                }
            },
            AppRow {
                label: "Resize on border"
                sub: "Drag a window edge to resize it"
                key: "windows.resizeOnBorder"
                clickable: true
                onClicked: resizeToggle.flip()
                AppToggle {
                    id: resizeToggle
                    checked: page.resizeOnBorder
                    onToggled: (on) => { page.resizeOnBorder = on; page.writeDeco("resize_on_border", on ? "true" : "false"); }
                }
            }
        ]
    }

    AppGroup {
        title: "Shadow"

        AppRow {
            label: "Shadow"
            sub: "Soft shadow under every window"
            key: "windows.shadow"
            clickable: true
            onClicked: shadowToggle.flip()
            AppToggle {
                id: shadowToggle
                checked: page.shadowOn
                onToggled: (on) => { page.shadowOn = on; page.writeBlock("shadow", "enabled", on ? "true" : "false"); }
            }
        }

        advanced: [
            AppRow {
                label: "Range"
                sub: "How far the shadow spreads"
                key: "windows.shadowRange"
                enabled: page.shadowOn
                opacity: enabled ? 1 : 0.45
                AppSlider {
                    from: 0; to: 50; step: 1; unit: "px"
                    value: page.shadowRange
                    onMoved: (v) => { page.shadowRange = v; page.writeBlock("shadow", "range", String(v)); }
                }
            },
            AppRow {
                label: "Render power"
                sub: "Higher gives the shadow a harder edge"
                key: "windows.shadowPower"
                enabled: page.shadowOn
                opacity: enabled ? 1 : 0.45
                AppSlider {
                    from: 1; to: 4; step: 1
                    value: page.shadowRenderPower
                    onMoved: (v) => { page.shadowRenderPower = v; page.writeBlock("shadow", "render_power", String(v)); }
                }
            }
        ]
    }

    AppGroup {
        title: "Blur"

        AppRow {
            label: "Blur"
            sub: "Frost what shows through see-through windows"
            key: "windows.blur"
            clickable: true
            onClicked: blurToggle.flip()
            AppToggle {
                id: blurToggle
                checked: page.blurOn
                onToggled: (on) => { page.blurOn = on; page.writeBlock("blur", "enabled", on ? "true" : "false"); }
            }
        }
        AppRow {
            label: "Size"
            sub: "How strong the blur is"
            key: "windows.blurSize"
            enabled: page.blurOn
            opacity: enabled ? 1 : 0.45
            AppSlider {
                from: 1; to: 20; step: 1; unit: "px"
                value: page.blurSize
                onMoved: (v) => { page.blurSize = v; page.writeBlock("blur", "size", String(v)); }
            }
        }

        advanced: [
            AppRow {
                label: "Passes"
                sub: "More passes look smoother but cost more"
                key: "windows.blurPasses"
                enabled: page.blurOn
                opacity: enabled ? 1 : 0.45
                AppSlider {
                    from: 1; to: 5; step: 1
                    value: page.blurPasses
                    onMoved: (v) => { page.blurPasses = v; page.writeBlock("blur", "passes", String(v)); }
                }
            },
            AppRow {
                label: "Vibrancy"
                sub: "How much colour survives behind the blur"
                key: "windows.blurVibrancy"
                enabled: page.blurOn
                opacity: enabled ? 1 : 0.45
                AppSlider {
                    from: 0; to: 1; step: 0.01; decimals: 2
                    value: page.blurVibrancy
                    onMoved: (v) => { page.blurVibrancy = v; page.writeBlock("blur", "vibrancy", v.toFixed(2)); }
                }
            },
            AppRow {
                label: "Noise"
                sub: "Fine grain mixed into the blur"
                key: "windows.blurNoise"
                enabled: page.blurOn
                opacity: enabled ? 1 : 0.45
                AppSlider {
                    from: 0; to: 0.2; step: 0.01; decimals: 2
                    value: page.blurNoise
                    onMoved: (v) => { page.blurNoise = v; page.writeBlock("blur", "noise", v.toFixed(2)); }
                }
            }
        ]
    }

    AppGroup {
        title: "Opacity"
        hint: "Changes show right away"

        AppRow {
            label: "Active window"
            sub: "How solid the window you work in is"
            key: "windows.opacityActive"
            AppSlider {
                from: 50; to: 100; step: 5; unit: "%"
                value: Math.round(page.activeOpacity * 100)
                onMoved: (v) => page.setOpacity(true, v / 100)
            }
        }
        AppRow {
            label: "Inactive windows"
            sub: "How solid every other window is"
            key: "windows.opacityInactive"
            AppSlider {
                from: 50; to: 100; step: 5; unit: "%"
                value: Math.round(page.inactiveOpacity * 100)
                onMoved: (v) => page.setOpacity(false, v / 100)
            }
        }
    }

    AppGroup {
        title: "Night light"

        AppRow {
            label: "Night light"
            sub: "Warms the screen colours to ease your eyes"
            key: "windows.nightMode"
            AppSeg {
                options: [{ label: "Off", value: "off" }, { label: "On", value: "on" }, { label: "Scheduled", value: "scheduled" }]
                value: Flags.nightLightMode
                onPicked: (v) => NightLight.setMode(v)
            }
        }
        AppRow {
            label: "Temperature"
            sub: "Lower is warmer"
            key: "windows.nightTemp"
            visible: Flags.nightLightMode !== "off"
            AppSlider {
                from: 2200; to: 6000; step: 100; unit: "K"
                value: Flags.nightLightTemp
                onMoved: (v) => NightLight.setTemp(v)
            }
        }
        AppRow {
            label: "On at"
            sub: "When the warm tint starts, used by Scheduled"
            key: "windows.nightOn"
            visible: Flags.nightLightMode === "scheduled"
            AppSlider {
                from: 0; to: 1425; step: 15
                fmt: page.fmtClock
                value: Flags.nightLightOnMin
                onMoved: (v) => NightLight.setOnMin(v)
            }
        }
        AppRow {
            label: "Off at"
            sub: "When colours go back to normal, used by Scheduled"
            key: "windows.nightOff"
            visible: Flags.nightLightMode === "scheduled"
            AppSlider {
                from: 0; to: 1425; step: 15
                fmt: page.fmtClock
                value: Flags.nightLightOffMin
                onMoved: (v) => NightLight.setOffMin(v)
            }
        }
    }
}
