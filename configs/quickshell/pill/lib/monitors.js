/**
 * Parses one availableModes entry like "2560x1440@279.96Hz" into its parts. The
 * Hz is rounded to a whole number for UI grouping and the apply mode string,
 * while `raw` keeps the original entry for reference. Returns null when the
 * entry does not match the WxH@HZHz shape.
 */
function parseMode(raw) {
    var m = raw.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
    if (!m)
        return null;
    return {
        w: parseInt(m[1], 10),
        h: parseInt(m[2], 10),
        hz: Math.round(parseFloat(m[3])),
        raw: raw
    };
}

/**
 * Parses the `hyprctl monitors -j` text into the slim shape the Display surface
 * needs: per monitor its name, current width/height/refresh/scale/x/y and the
 * available modes as `{ w, h, hz, raw }`. Refresh is rounded the same way as a
 * mode's Hz so the current mode can be matched against the list. Modes that do
 * not parse are dropped. Returns [] on bad input.
 */
function parse(jsonText) {
    var data;
    try {
        data = JSON.parse(jsonText);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(data))
        return [];

    return data.map(function (mon) {
        var modes = (mon.availableModes || [])
            .map(parseMode)
            .filter(function (m) { return m !== null; });
        return {
            name: mon.name,
            width: mon.width,
            height: mon.height,
            refresh: Math.round(mon.refreshRate),
            scale: mon.scale,
            x: mon.x,
            y: mon.y,
            modes: modes
        };
    });
}

/**
 * Rewrites only the `hl.monitor({...})` block whose `output = "<output>"`,
 * replacing the `mode`, `position` and `scale` field values and leaving every
 * other character of the file byte-identical (other monitors, workspace_rule
 * loops, whitespace, field order). The block is located by its `output` field,
 * then the closest enclosing `hl.monitor({` ... `})` bounds are taken and each
 * of the three fields is substituted in place within those bounds. Returns
 * `{ text, ok, error }`; ok is false (text unchanged) when the block or any of
 * the three fields cannot be found. An output with no block yet (new monitor,
 * port swap renaming DP-1 to DP-3) gets a fresh block appended instead.
 */
function setMonitor(luaText, output, mode, position, scale) {
    var outRe = new RegExp('output\\s*=\\s*"' + escapeRe(output) + '"');
    var outMatch = outRe.exec(luaText);
    if (!outMatch)
        return appendMonitor(luaText, output, mode, position, scale);

    var blockStart = luaText.lastIndexOf("hl.monitor({", outMatch.index);
    if (blockStart === -1)
        return { text: luaText, ok: false, error: "no hl.monitor block for " + output };

    var blockEnd = luaText.indexOf("})", outMatch.index);
    if (blockEnd === -1)
        return { text: luaText, ok: false, error: "unterminated block for " + output };

    var head = luaText.slice(0, blockStart);
    var block = luaText.slice(blockStart, blockEnd);
    var tail = luaText.slice(blockEnd);

    var r1 = replaceField(block, "mode", '"' + mode + '"');
    if (!r1.ok)
        return { text: luaText, ok: false, error: "mode field not found for " + output };
    var r2 = replaceField(r1.text, "position", '"' + position + '"');
    if (!r2.ok)
        return { text: luaText, ok: false, error: "position field not found for " + output };
    var r3 = replaceField(r2.text, "scale", String(scale));
    if (!r3.ok)
        return { text: luaText, ok: false, error: "scale field not found for " + output };

    return { text: head + r3.text + tail, ok: true, error: "" };
}

/**
 * Replaces the value of a single `name = <value>` field within a hl.monitor
 * block, preserving the field name, the `=` spacing and any trailing comma. The
 * value run is a complete double-quoted string when the value is quoted (so a
 * comma inside the quotes is not mistaken for the field end), otherwise the run
 * up to the next comma or the block's closing brace. Returns `{ text, ok }`.
 */
function replaceField(block, name, value) {
    var re = new RegExp("(" + name + "\\s*=\\s*)(\"[^\"]*\"|[^,}\\n]*)");
    if (!re.test(block))
        return { text: block, ok: false };
    return { text: block.replace(re, "$1" + value), ok: true };
}

function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Appends a new `hl.monitor({...})` block for an output the file does not know
 * yet, matching the field layout the installer ships. Returns `{ text, ok,
 * error }` like setMonitor.
 */
function appendMonitor(luaText, output, mode, position, scale) {
    var text = luaText;
    if (text.length > 0 && text.charAt(text.length - 1) !== "\n")
        text += "\n";
    text += "\nhl.monitor({\n    output   = \"" + output + "\",\n    mode     = \"" + mode
        + "\",\n    position = \"" + position + "\",\n    scale    = " + scale + ",\n})\n";
    return { text: text, ok: true, error: "" };
}

/**
 * Points the two workspace_rule loops at two real outputs: the loop covering
 * workspace 1 gets `mainName`, the other gets `otherName`. Whatever names the
 * loops carried before (including stale ones for unplugged monitors) are
 * replaced. Returns `{ text, ok, error, mainRange, otherRange }`; the ranges
 * carry each loop's from/to so the caller can move live workspaces to match.
 * ok is false when the file does not hold exactly two loops.
 */
function setWorkspaceLoops(luaText, mainName, otherName) {
    var re = /(for\s+i\s*=\s*(\d+)\s*,\s*(\d+)\s+do\s*\n\s*hl\.workspace_rule\(\{[^}]*monitor\s*=\s*")([^"]+)(")/g;
    var hits = [];
    var m;
    while ((m = re.exec(luaText)) !== null)
        hits.push({ start: m.index + m[1].length, end: m.index + m[1].length + m[4].length,
            from: parseInt(m[2], 10), to: parseInt(m[3], 10) });
    if (hits.length !== 2)
        return { text: luaText, ok: false, error: "expected 2 workspace_rule loops, found " + hits.length };
    var firstIsMain = hits[0].from <= 1 && hits[0].to >= 1;
    var mainHit = firstIsMain ? hits[0] : hits[1];
    var otherHit = firstIsMain ? hits[1] : hits[0];
    var edits = [
        { start: mainHit.start, end: mainHit.end, name: mainName },
        { start: otherHit.start, end: otherHit.end, name: otherName }
    ].sort(function (a, b) { return b.start - a.start; });
    var text = luaText;
    for (var i = 0; i < edits.length; i++)
        text = text.slice(0, edits[i].start) + edits[i].name + text.slice(edits[i].end);
    return { text: text, ok: true, error: "",
        mainRange: [mainHit.from, mainHit.to], otherRange: [otherHit.from, otherHit.to] };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseMode, parse, setMonitor, appendMonitor, setWorkspaceLoops };
}
