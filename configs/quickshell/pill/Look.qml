pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setDeco.js" as SetDeco
import "Singletons"

/**
 * 飾 LOOK: window decoration knobs in decoration.lua, written back on each change; blur and shadow fields are scoped to their own block.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    /**
     * Rebuilt when a group folds or a dependent toggle flips, so arrows never land on a hidden line.
     */
    rows: {
        var r = [];
        function head(g) {
            r.push({ item: g.header, kind: "toggle", get: function () { return g.open; }, set: function (v) { g.open = v; } });
        }
        head(winGrp);
        if (winGrp.open) {
            r.push({ item: gapsInRow, kind: "scrub", bump: function (d) { gapsInScrub.bump(d); } });
            r.push({ item: gapsOutRow, kind: "scrub", bump: function (d) { gapsOutScrub.bump(d); } });
            r.push({ item: roundRow, kind: "scrub", bump: function (d) { roundScrub.bump(d); } });
            r.push({ item: roundPowRow, kind: "scrub", bump: function (d) { roundPowScrub.bump(d); } });
            r.push({ item: borderRow, kind: "scrub", bump: function (d) { borderScrub.bump(d); } });
            r.push({ item: resizeRow, kind: "toggle", get: function () { return root.resizeOnBorder; }, set: function (v) { root.resizeOnBorder = v; root.writeDeco("resize_on_border", v ? "true" : "false"); } });
            r.push({ item: layoutRow, kind: "seg", vals: ["dwindle", "master"], get: function () { return root.layout; }, set: function (v) { root.layout = v; root.writeDeco("layout", "\"" + v + "\""); } });
        }
        head(nightGrp);
        if (nightGrp.open) {
            r.push({ item: nlModeRow, kind: "seg", vals: ["off", "on", "scheduled"], get: function () { return Flags.nightLightMode; }, set: function (v) { NightLight.setMode(v); } });
            if (Flags.nightLightMode !== "off")
                r.push({ item: nlTempRow, kind: "scrub", bump: function (d) { nlTempScrub.bump(d); } });
            if (Flags.nightLightMode === "scheduled") {
                r.push({ item: nlOnRow, kind: "scrub", bump: function (d) { nlOnScrub.bump(d); } });
                r.push({ item: nlOffRow, kind: "scrub", bump: function (d) { nlOffScrub.bump(d); } });
            }
        }
        head(shadowGrp);
        if (shadowGrp.open) {
            r.push({ item: shEnRow, kind: "toggle", get: function () { return root.shadowOn; }, set: function (v) { root.shadowOn = v; root.writeShadow("enabled", v ? "true" : "false"); } });
            if (root.shadowOn) {
                r.push({ item: shRangeRow, kind: "scrub", bump: function (d) { shRangeScrub.bump(d); } });
                r.push({ item: shPowRow, kind: "scrub", bump: function (d) { shPowScrub.bump(d); } });
            }
        }
        head(blurGrp);
        if (blurGrp.open) {
            r.push({ item: blEnRow, kind: "toggle", get: function () { return root.blurOn; }, set: function (v) { root.blurOn = v; root.writeBlur("enabled", v ? "true" : "false"); } });
            if (root.blurOn) {
                r.push({ item: blSizeRow, kind: "scrub", bump: function (d) { blSizeScrub.bump(d); } });
                r.push({ item: blPassRow, kind: "scrub", bump: function (d) { blPassScrub.bump(d); } });
                r.push({ item: blVibRow, kind: "scrub", bump: function (d) { blVibScrub.bump(d); } });
                r.push({ item: blNoiseRow, kind: "scrub", bump: function (d) { blNoiseScrub.bump(d); } });
            }
        }
        head(opGrp);
        if (opGrp.open) {
            r.push({ item: opActRow, kind: "scrub", bump: function (d) { opActScrub.bump(d); } });
            r.push({ item: opInactRow, kind: "scrub", bump: function (d) { opInactScrub.bump(d); } });
        }
        head(pillGrp);
        if (pillGrp.open) {
            r.push({ item: pillGapRow, kind: "scrub", bump: function (d) { pillGapScrub.bump(d); } });
            r.push({ item: appGapRow, kind: "scrub", bump: function (d) { appGapScrub.bump(d); } });
            r.push({ item: pillOpRow, kind: "scrub", bump: function (d) { pillOpScrub.bump(d); } });
            r.push({ item: pillBlurRow, kind: "toggle", get: function () { return Flags.pillBlur; }, set: function (v) { Flags.pillBlur = v; root.applyPillBlur(v); } });
        }
        return r;
    }

    readonly property string note: HyprReload.failed ? "Hyprland reload failed. The change is saved but not applied." : ""

    readonly property string decoPath: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    readonly property string pillBlurRule: 'hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.5 })\n'

    property int gapsIn: 6
    property int gapsOut: 12
    property int rounding: 12
    property int roundingPower: 4
    property int borderSize: 2
    property bool resizeOnBorder: true
    property string layout: "dwindle"
    property bool blurOn: true
    property int blurSize: 8
    property int blurPasses: 3
    property real blurVibrancy: 0.17
    property real blurNoise: 0.01
    property bool shadowOn: true
    property int shadowRange: 12
    property int shadowRenderPower: 3
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0

    readonly property var layoutOptions: [
        { label: "Dwindle", value: "dwindle" },
        { label: "Master", value: "master" }
    ]

    property string decoText: ""

    /**
     * Per-field values captured on each open; the ScrubValue undo glyphs revert to these.
     */
    property var base: ({})

    onActiveChanged: {
        if (active) {
            decoFile.reload();
            seed();
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Seeds every control from decoration.lua, falling back to shipped defaults for missing fields.
     */
    function seed() {
        root.decoText = decoFile.text();
        var t = root.decoText;

        var gi = parseInt(SetDeco.getField(t, "gaps_in"), 10);
        root.gapsIn = isNaN(gi) ? 6 : gi;
        var go = parseInt(SetDeco.getField(t, "gaps_out"), 10);
        root.gapsOut = isNaN(go) ? 12 : go;
        var rd = parseInt(SetDeco.getField(t, "rounding"), 10);
        root.rounding = isNaN(rd) ? 12 : rd;
        var rp = parseInt(SetDeco.getField(t, "rounding_power"), 10);
        root.roundingPower = isNaN(rp) ? 4 : rp;
        var bs = parseInt(SetDeco.getField(t, "border_size"), 10);
        root.borderSize = isNaN(bs) ? 2 : bs;
        root.resizeOnBorder = SetDeco.getField(t, "resize_on_border") === "true";
        var lo = SetDeco.getField(t, "layout");
        root.layout = lo.length > 0 ? lo : "dwindle";

        root.blurOn = SetDeco.getBlockField(t, "blur", "enabled") === "true";
        var bz = parseInt(SetDeco.getBlockField(t, "blur", "size"), 10);
        root.blurSize = isNaN(bz) ? 8 : bz;
        var bp = parseInt(SetDeco.getBlockField(t, "blur", "passes"), 10);
        root.blurPasses = isNaN(bp) ? 3 : bp;
        var vb = parseFloat(SetDeco.getBlockField(t, "blur", "vibrancy"));
        root.blurVibrancy = isNaN(vb) ? 0.17 : vb;
        var nz = parseFloat(SetDeco.getBlockField(t, "blur", "noise"));
        root.blurNoise = isNaN(nz) ? 0.01 : nz;

        root.shadowOn = SetDeco.getBlockField(t, "shadow", "enabled") === "true";
        var sr = parseInt(SetDeco.getBlockField(t, "shadow", "range"), 10);
        root.shadowRange = isNaN(sr) ? 12 : sr;
        var sp = parseInt(SetDeco.getBlockField(t, "shadow", "render_power"), 10);
        root.shadowRenderPower = isNaN(sp) ? 3 : sp;

        var ao = parseFloat(SetDeco.getField(t, "active_opacity"));
        root.activeOpacity = isNaN(ao) ? 1.0 : ao;
        var io = parseFloat(SetDeco.getField(t, "inactive_opacity"));
        root.inactiveOpacity = isNaN(io) ? 1.0 : io;

        Flags.pillBlur = SetDeco.hasNamedRule(t, "pill-blur");

        root.base = {
            gapsIn: root.gapsIn,
            gapsOut: root.gapsOut,
            rounding: root.rounding,
            roundingPower: root.roundingPower,
            borderSize: root.borderSize,
            blurSize: root.blurSize,
            blurPasses: root.blurPasses,
            blurVibrancy: root.blurVibrancy,
            blurNoise: root.blurNoise,
            shadowRange: root.shadowRange,
            shadowRenderPower: root.shadowRenderPower,
            activeOpacity: root.activeOpacity,
            inactiveOpacity: root.inactiveOpacity,
            pillOpacity: Flags.pillOpacity,
            topGap: Flags.topGap,
            appGap: Flags.appGap,
            nlTemp: Flags.nightLightTemp,
            nlOnMin: Flags.nightLightOnMin,
            nlOffMin: Flags.nightLightOffMin
        };
    }

    function fmtClock(v) {
        var h = Math.floor(v / 60);
        var m = v % 60;
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    readonly property var nightModeOptions: [
        { label: "Off", value: "off" },
        { label: "On", value: "on" },
        { label: "Scheduled", value: "scheduled" }
    ]

    function writeDeco(name, literal) {
        var res = SetDeco.setField(root.decoText, name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
    }

    /**
     * Also pushes both opacities through hl.config, since a plain reload leaves unfocused windows on their stale alpha.
     */
    function writeOpacity(name, literal) {
        writeDeco(name, literal);
        opacityRefresh.command = ["hyprctl", "eval",
            "hl.config({ decoration = { active_opacity = " + root.activeOpacity.toFixed(2)
            + ", inactive_opacity = " + root.inactiveOpacity.toFixed(2) + " } })"];
        opacityRefresh.running = true;
    }

    /**
     * Scoped to the `blur` block so `enabled` never hits the sibling `shadow` block.
     */
    function writeBlur(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "blur", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
    }

    /**
     * Scoped to the `shadow` block so `enabled` never hits the sibling `blur` block.
     */
    function writeShadow(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "shadow", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
    }

    /**
     * The pill-blur layer_rule must be written to the Lua, since the live parser rejects a runtime `layerrule`.
     */
    function applyPillBlur(on) {
        var t = root.decoText;
        var res;
        if (on) {
            if (SetDeco.hasNamedRule(t, "pill-blur"))
                return;
            res = SetDeco.addNamedRule(t, root.pillBlurRule);
        } else {
            res = SetDeco.removeNamedRule(t, "pill-blur");
        }
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
    }

    FileView {
        id: decoFile
        path: root.decoPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: decoWriter
        path: root.decoPath
        atomicWrites: true
        printErrors: false
        onSaved: HyprReload.request()
    }

    Process {
        id: opacityRefresh
        command: []
    }

    /**
     * Folding group: its header is a registry row, so arrows reach it and Enter, Space or a click folds it.
     */
    component Group: Column {
        id: grp
        property string title: ""
        property bool open: false
        readonly property alias header: head
        default property alias rows: body.data

        width: parent ? parent.width : 0
        spacing: 0

        Item { width: 1; height: Theme.sp.s * root.s }

        Item {
            id: head
            readonly property bool lit: headHover.hovered || root.focusRowItem === head

            width: parent.width
            height: 28 * root.s

            HoverHandler {
                id: headHover
                onHoveredChanged: root.reportRowHover(head, hovered)
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.r.m * root.s
                color: headPress.pressed ? Theme.pressBg : (head.lit ? Theme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            SettingsLabel {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp.m * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                topPadding: 0
                bottomPadding: 0
                text: grp.title
                color: head.lit || grp.open ? Theme.subtle : Theme.textFaint
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp.m * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * root.s
                height: 14 * root.s
                name: "chevron-down"
                color: head.lit ? Theme.cream : Theme.textFaint
                stroke: 2.0
                rotation: grp.open ? 0 : -90
                Behavior on rotation { enabled: !Motion.calm; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: headPress
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activateRow(head)
            }
        }

        Item {
            width: parent.width
            height: grp.open ? body.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

            Column {
                id: body
                width: parent.width
            }
        }
    }

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
            glyph: "飾"
            title: "LOOK"
            canBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Group { id: winGrp; title: "Window"; open: true

            FieldRow {
                id: gapsInRow
                label: "Gaps inner"
                caption: "Space between tiled windows"
                ScrubValue {
                    id: gapsInScrub
                    s: root.s
                    value: root.gapsIn
                    openValue: root.base.gapsIn
                    from: 0; to: 40; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsIn = v;
                        root.writeDeco("gaps_in", String(v));
                    }
                }
            }

            FieldRow {
                id: gapsOutRow
                label: "Gaps outer"
                caption: "Space to the screen edge"
                ScrubValue {
                    id: gapsOutScrub
                    s: root.s
                    value: root.gapsOut
                    openValue: root.base.gapsOut
                    from: 0; to: 60; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsOut = v;
                        root.writeDeco("gaps_out", String(v));
                    }
                }
            }

            FieldRow {
                id: roundRow
                label: "Rounding"
                caption: "Corner radius in pixels"
                ScrubValue {
                    id: roundScrub
                    s: root.s
                    value: root.rounding
                    openValue: root.base.rounding
                    from: 0; to: 30; step: 1; unit: "px"
                    onEdited: v => {
                        root.rounding = v;
                        root.writeDeco("rounding", String(v));
                    }
                }
            }

            FieldRow {
                id: roundPowRow
                label: "Rounding power"
                caption: "Higher bends corners to a squircle"
                ScrubValue {
                    id: roundPowScrub
                    s: root.s
                    value: root.roundingPower
                    openValue: root.base.roundingPower
                    from: 1; to: 10; step: 1
                    onEdited: v => {
                        root.roundingPower = v;
                        root.writeDeco("rounding_power", String(v));
                    }
                }
            }

            FieldRow {
                id: borderRow
                label: "Border size"
                caption: "Window outline thickness"
                ScrubValue {
                    id: borderScrub
                    s: root.s
                    value: root.borderSize
                    openValue: root.base.borderSize
                    from: 0; to: 8; step: 1; unit: "px"
                    onEdited: v => {
                        root.borderSize = v;
                        root.writeDeco("border_size", String(v));
                    }
                }
            }

            FieldRow {
                id: resizeRow
                label: "Resize on border"
                caption: "Drag a window edge to resize"
                LinkToggle {
                    s: root.s
                    on: root.resizeOnBorder
                    onToggled: {
                        root.resizeOnBorder = !root.resizeOnBorder;
                        root.writeDeco("resize_on_border", root.resizeOnBorder ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: layoutRow
                label: "Layout"
                caption: "Tiling layout for new windows"
                SettingsSeg {
                    s: root.s
                    options: root.layoutOptions
                    value: root.layout
                    onPicked: v => {
                        root.layout = v;
                        root.writeDeco("layout", "\"" + v + "\"");
                    }
                }
            }

            }

            Group { id: nightGrp; title: "Night light"

            FieldRow {
                id: nlModeRow
                label: "Mode"
                caption: "Off, always warm, or auto by time"
                SettingsSeg {
                    s: root.s
                    options: root.nightModeOptions
                    value: Flags.nightLightMode
                    onPicked: v => NightLight.setMode(v)
                }
            }

            FieldRow {
                id: nlTempRow
                label: "Temperature"
                caption: "Lower is warmer"
                collapsed: Flags.nightLightMode === "off"
                ScrubValue {
                    id: nlTempScrub
                    s: root.s
                    value: Flags.nightLightTemp
                    openValue: root.base.nlTemp
                    from: 2200; to: 6000; step: 100; unit: "K"
                    onEdited: v => NightLight.setTemp(v)
                }
            }

            FieldRow {
                id: nlOnRow
                label: "On at"
                caption: "Warm tint starts"
                collapsed: Flags.nightLightMode !== "scheduled"
                ScrubValue {
                    id: nlOnScrub
                    s: root.s
                    value: Flags.nightLightOnMin
                    openValue: root.base.nlOnMin
                    from: 0; to: 1425; step: 15
                    fmt: root.fmtClock
                    onEdited: v => NightLight.setOnMin(v)
                }
            }

            FieldRow {
                id: nlOffRow
                label: "Off at"
                caption: "Back to neutral"
                collapsed: Flags.nightLightMode !== "scheduled"
                ScrubValue {
                    id: nlOffScrub
                    s: root.s
                    value: Flags.nightLightOffMin
                    openValue: root.base.nlOffMin
                    from: 0; to: 1425; step: 15
                    fmt: root.fmtClock
                    onEdited: v => NightLight.setOffMin(v)
                }
            }

            }

            Group { id: shadowGrp; title: "Shadow"

            FieldRow {
                id: shEnRow
                label: "Enabled"
                caption: "Drop shadow under windows"
                LinkToggle {
                    s: root.s
                    on: root.shadowOn
                    onToggled: {
                        root.shadowOn = !root.shadowOn;
                        root.writeShadow("enabled", root.shadowOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: shRangeRow
                label: "Range"
                caption: "How far the shadow spreads"
                collapsed: !root.shadowOn
                ScrubValue {
                    id: shRangeScrub
                    s: root.s
                    value: root.shadowRange
                    openValue: root.base.shadowRange
                    from: 0; to: 50; step: 1; unit: "px"
                    onEdited: v => {
                        root.shadowRange = v;
                        root.writeShadow("range", String(v));
                    }
                }
            }

            FieldRow {
                id: shPowRow
                label: "Render power"
                caption: "Shadow falloff sharpness"
                collapsed: !root.shadowOn
                ScrubValue {
                    id: shPowScrub
                    s: root.s
                    value: root.shadowRenderPower
                    openValue: root.base.shadowRenderPower
                    from: 1; to: 4; step: 1
                    onEdited: v => {
                        root.shadowRenderPower = v;
                        root.writeShadow("render_power", String(v));
                    }
                }
            }

            }

            Group { id: blurGrp; title: "Blur"

            FieldRow {
                id: blEnRow
                label: "Enabled"
                caption: "Blur behind transparent windows"
                LinkToggle {
                    s: root.s
                    on: root.blurOn
                    onToggled: {
                        root.blurOn = !root.blurOn;
                        root.writeBlur("enabled", root.blurOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                id: blSizeRow
                label: "Strength"
                caption: "Blur radius"
                collapsed: !root.blurOn
                ScrubValue {
                    id: blSizeScrub
                    s: root.s
                    value: root.blurSize
                    openValue: root.base.blurSize
                    from: 1; to: 20; step: 1; unit: "px"
                    onEdited: v => {
                        root.blurSize = v;
                        root.writeBlur("size", String(v));
                    }
                }
            }

            FieldRow {
                id: blPassRow
                label: "Passes"
                caption: "More passes, smoother blur"
                collapsed: !root.blurOn
                ScrubValue {
                    id: blPassScrub
                    s: root.s
                    value: root.blurPasses
                    openValue: root.base.blurPasses
                    from: 1; to: 5; step: 1
                    onEdited: v => {
                        root.blurPasses = v;
                        root.writeBlur("passes", String(v));
                    }
                }
            }

            FieldRow {
                id: blVibRow
                label: "Vibrancy"
                caption: "Color saturation behind the blur"
                collapsed: !root.blurOn
                ScrubValue {
                    id: blVibScrub
                    s: root.s
                    value: root.blurVibrancy
                    openValue: root.base.blurVibrancy
                    from: 0; to: 1; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurVibrancy = v;
                        root.writeBlur("vibrancy", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                id: blNoiseRow
                label: "Noise"
                caption: "Grain mixed into the blur"
                collapsed: !root.blurOn
                ScrubValue {
                    id: blNoiseScrub
                    s: root.s
                    value: root.blurNoise
                    openValue: root.base.blurNoise
                    from: 0; to: 0.2; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurNoise = v;
                        root.writeBlur("noise", v.toFixed(2));
                    }
                }
            }

            }

            Group { id: opGrp; title: "Opacity"

            FieldRow {
                id: opActRow
                label: "Active window"
                caption: "Focused window transparency"
                ScrubValue {
                    id: opActScrub
                    s: root.s
                    value: root.activeOpacity
                    openValue: root.base.activeOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.activeOpacity = v;
                        root.writeOpacity("active_opacity", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                id: opInactRow
                label: "Inactive window"
                caption: "Unfocused window transparency"
                ScrubValue {
                    id: opInactScrub
                    s: root.s
                    value: root.inactiveOpacity
                    openValue: root.base.inactiveOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.inactiveOpacity = v;
                        root.writeOpacity("inactive_opacity", v.toFixed(2));
                    }
                }
            }

            }

            Group { id: pillGrp; title: "Pill"

            FieldRow {
                id: pillGapRow
                label: "Pill gap"
                caption: "Space above the pill. Lower pulls windows up with it."
                ScrubValue {
                    id: pillGapScrub
                    s: root.s
                    value: Flags.topGap
                    openValue: root.base.topGap
                    from: 0; to: 2; step: 0.1; decimals: 1
                    onEdited: v => Flags.topGap = v
                }
            }

            FieldRow {
                id: appGapRow
                label: "App gap"
                caption: "Space under the pill. Lower pulls windows up."
                ScrubValue {
                    id: appGapScrub
                    s: root.s
                    value: Flags.appGap
                    openValue: root.base.appGap
                    from: 0; to: 2; step: 0.1; decimals: 1
                    onEdited: v => Flags.appGap = v
                }
            }

            FieldRow {
                id: pillOpRow
                label: "Pill opacity"
                caption: "How see-through the pill sits"
                ScrubValue {
                    id: pillOpScrub
                    s: root.s
                    value: Flags.pillOpacity
                    openValue: root.base.pillOpacity
                    from: 0.55; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => Flags.pillOpacity = v
                }
            }

            FieldRow {
                id: pillBlurRow
                label: "Pill blur"
                caption: "Frosts behind the pill. Needs opacity under 100%."
                LinkToggle {
                    s: root.s
                    on: Flags.pillBlur
                    onToggled: {
                        Flags.pillBlur = !Flags.pillBlur;
                        root.applyPillBlur(Flags.pillBlur);
                    }
                }
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
