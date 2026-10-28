import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/setDeco.js" as SetDeco
import "../Singletons"
import "PillDefaults.js" as Defaults

/** Reads and writes the Hyprland look in decoration.lua: the preset fields and the `pill-blur` layer rule; `rev` bumps whenever the file changes. */
Item {
    id: deco

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"
    readonly property string blurRule: 'hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.5 })\n'
    property int rev: 0

    function text() {
        return file.text() || "";
    }

    function values() {
        const t = text();
        void rev;
        const o = {};
        for (const f of Defaults.decoFields) {
            const raw = f.block.length > 0 ? SetDeco.getBlockField(t, f.block, f.name) : SetDeco.getField(t, f.name);
            if (f.type === "bool") {
                o[f.key] = raw.length > 0 ? raw === "true" : f.def;
            } else {
                const n = f.type === "int" ? parseInt(raw, 10) : parseFloat(raw);
                o[f.key] = isNaN(n) ? f.def : n;
            }
        }
        return o;
    }

    function hasBlurRule() {
        const t = text();
        void rev;
        return SetDeco.hasNamedRule(t, "pill-blur");
    }

    function literal(f, v) {
        if (f.type === "bool")
            return v ? "true" : "false";
        if (f.type === "int")
            return String(Math.round(Number(v)));
        return Number(v).toFixed(2);
    }

    function withBlurRule(t, on) {
        const has = SetDeco.hasNamedRule(t, "pill-blur");
        if (on === has)
            return t;
        const res = on ? SetDeco.addNamedRule(t, blurRule) : SetDeco.removeNamedRule(t, "pill-blur");
        return res.ok ? res.text : t;
    }

    function save(t) {
        if (t === text())
            return false;
        file.setText(t);
        rev++;
        return true;
    }

    /** Writes every preset field in `vals` plus the blur rule in one atomic save; opacities also go live through hl.config, which a reload alone leaves stale on unfocused windows. */
    function apply(vals, pillBlur) {
        const before = values();
        let t = text();
        if (t.length === 0)
            return false;
        for (const f of Defaults.decoFields) {
            if (!vals || !vals.hasOwnProperty(f.key))
                continue;
            const lit = literal(f, vals[f.key]);
            const res = f.block.length > 0 ? SetDeco.setBlockField(t, f.block, f.name, lit) : SetDeco.setField(t, f.name, lit);
            if (res.ok)
                t = res.text;
        }
        if (pillBlur !== undefined)
            t = withBlurRule(t, pillBlur === true);
        const wrote = save(t);
        if (wrote && vals && (!Defaults.same(before.active_opacity, vals.active_opacity) || !Defaults.same(before.inactive_opacity, vals.inactive_opacity)))
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { active_opacity = " + Number(vals.active_opacity).toFixed(2)
                + ", inactive_opacity = " + Number(vals.inactive_opacity).toFixed(2) + " } })"]);
        return wrote;
    }

    /** The live parser rejects a runtime layerrule, so the pill blur only takes hold through the Lua file. */
    function setPillBlur(on) {
        const t = text();
        if (t.length > 0)
            save(withBlurRule(t, on));
    }

    FileView {
        id: file
        path: deco.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: deco.rev++
        onSaved: HyprReload.request()
    }
}
