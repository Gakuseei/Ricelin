function readMod(luaText) {
    var m = luaText.match(/^\s*local\s+mod\s*=\s*"([^"]*)"/m);
    return m ? m[1] : "SUPER";
}

function isMouseCombo(combo) {
    return /mouse:|mouse_up|mouse_down/.test(combo);
}

function optsHasMouse(opts) {
    return /\bmouse\s*=\s*true\b/.test(opts);
}

/**
 * Index of the quote closing the string that opens at i, skipping backslash escapes; -1 when unterminated.
 */
function strEnd(s, i) {
    for (var j = i + 1; j < s.length; j++) {
        if (s[j] === "\\") j++;
        else if (s[j] === '"') return j;
    }
    return -1;
}

function splitArgs(inner) {
    var args = [];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < inner.length; i++) {
        var c = inner[i];
        if (c === '"') {
            i = strEnd(inner, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') depth--;
        else if (c === ',' && depth === 0) {
            args.push(inner.slice(start, i));
            start = i + 1;
        }
    }
    args.push(inner.slice(start));
    return args.map(function (a) { return a.trim(); });
}

function resolveCombo(firstArg, modValue) {
    var modMatch = firstArg.match(/^mod\s*\.\.\s*"([^"]*)"$/);
    if (modMatch) {
        return { combo: modValue + modMatch[1] };
    }
    var litMatch = firstArg.match(/^"([^"]*)"$/);
    if (litMatch) {
        return { combo: litMatch[1] };
    }
    return { combo: firstArg };
}

function deriveLabel(action) {
    var exec = action.match(/exec_cmd\(\s*"([^"]*)"\s*\)/);
    if (exec) {
        var cmd = exec[1];
        var script = cmd.match(/\/scripts\/([^\/]+)\.sh\b/);
        if (script) return script[1];
        return cmd.split(/\s+/)[0];
    }
    var execEnv = action.match(/exec_cmd\(\s*os\.getenv\([^)]*\)\s*\.\.\s*"([^"]*)"/);
    if (execEnv) {
        var path = execEnv[1];
        var s = path.match(/\/scripts\/([^\/]+)\.sh\b/);
        if (s) return s[1];
        return path;
    }

    if (/window\.kill\b/.test(action)) return "kill window";
    if (/window\.close\b/.test(action)) return "close window";
    if (/window\.fullscreen\b/.test(action)) return "fullscreen";
    if (/window\.float\b/.test(action)) return "float";
    if (/window\.move\b/.test(action)) return "move to workspace";
    if (/window\.drag\b/.test(action)) return "drag window";
    if (/window\.resize\b/.test(action)) return "resize window";

    var ws = action.match(/focus\(\s*{\s*workspace\s*=\s*"r([+-]\d+)"/);
    if (ws) return "workspace " + ws[1];

    return action.replace(/^hl\.dsp\./, "").replace(/\(\)$/, "");
}

/**
 * Scans only past `closeIndex` so a `--` inside a quoted string arg is never taken for the trailing name comment.
 */
function nameComment(raw, closeIndex) {
    var rest = raw.slice(closeIndex + 1);
    var m = rest.match(/--\s?(.*)$/);
    return m ? m[1].trim() : "";
}

function isExecAction(action) {
    return /exec_cmd\s*\(/.test(action);
}

/**
 * Returns "" for an env-prefixed or non-exec dispatch, since that is not a single editable command literal.
 */
function execCmd(action) {
    var m = action.match(/exec_cmd\(\s*"((?:[^"\\]|\\.)*)"\s*\)/);
    if (!m) return "";
    return m[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\");
}

function parseLine(raw, lineIndex, modValue) {
    var open = raw.indexOf("hl.bind(");
    if (open === -1) return null;

    var depth = 0;
    var startInner = open + "hl.bind(".length;
    var endInner = -1;
    for (var i = startInner - 1; i < raw.length; i++) {
        var c = raw[i];
        if (c === '"') {
            i = strEnd(raw, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(') depth++;
        else if (c === ')') {
            depth--;
            if (depth === 0) { endInner = i; break; }
        }
    }
    if (endInner === -1) return null;

    var inner = raw.slice(startInner, endInner);
    var args = splitArgs(inner);
    if (args.length < 2) return null;

    var resolved = resolveCombo(args[0], modValue);
    var action = args[1];
    var opts = args.length >= 3 ? args.slice(2).join(", ") : "";

    var name = nameComment(raw, endInner);
    var mouse = isMouseCombo(resolved.combo) || optsHasMouse(opts);

    return {
        combo: resolved.combo,
        label: name.length ? name : deriveLabel(action),
        name: name,
        action: action,
        cmd: execCmd(action),
        isExec: isExecAction(action),
        isMouse: mouse,
        lineIndex: lineIndex
    };
}

function parse(luaText) {
    var modValue = readMod(luaText);
    var lines = luaText.split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var entry = parseLine(lines[i], i, modValue);
        if (entry) out.push(entry);
    }
    return out;
}

function rebind(luaText, lineIndex, newCombo) {
    var modValue = readMod(luaText);
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length) {
        return { text: luaText, ok: false, error: "invalid lineIndex" };
    }

    var raw = lines[lineIndex];
    var open = raw.indexOf("hl.bind(");
    if (open === -1) {
        return { text: luaText, ok: false, error: "no hl.bind on line" };
    }

    var startInner = open + "hl.bind(".length;
    var firstEnd = -1;
    var depth = 0;
    for (var i = startInner; i < raw.length; i++) {
        var c = raw[i];
        if (c === '"') {
            i = strEnd(raw, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') depth--;
        else if (c === ',' && depth === 0) { firstEnd = i; break; }
    }
    if (firstEnd === -1) {
        return { text: luaText, ok: false, error: "could not isolate first arg" };
    }

    var firstRaw = raw.slice(startInner, firstEnd);
    var leading = firstRaw.match(/^\s*/)[0];
    var trailing = firstRaw.match(/\s*$/)[0];

    var modPrefix = modValue + " + ";
    var firstArg;
    if (newCombo.indexOf(modPrefix) === 0) {
        firstArg = 'mod .. " + ' + newCombo.slice(modPrefix.length) + '"';
    } else {
        firstArg = '"' + newCombo + '"';
    }

    var newFirstRaw = leading + firstArg + trailing;
    var newLine = raw.slice(0, startInner) + newFirstRaw + raw.slice(firstEnd);
    lines[lineIndex] = newLine;

    return { text: lines.join("\n"), ok: true, error: "" };
}

function inUse(luaText, newCombo, exceptLineIndex) {
    var entries = parse(luaText);
    for (var i = 0; i < entries.length; i++) {
        if (entries[i].lineIndex === exceptLineIndex) continue;
        if (entries[i].combo === newCombo) return true;
    }
    return false;
}

/**
 * Builds the lua combo argument like rebind's firstArg: `mod .. " + X"` when the combo starts with the modifier, else a quoted literal.
 */
function comboExpr(combo, modValue) {
    var modPrefix = modValue + " + ";
    if (combo.indexOf(modPrefix) === 0)
        return 'mod .. " + ' + combo.slice(modPrefix.length) + '"';
    return '"' + combo + '"';
}

function escapeCmd(cmd) {
    return cmd.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

/**
 * Skips quoted strings so a paren inside an arg never closes the `hl.bind(` call early, returning -1 when malformed.
 */
function closeParenIndex(raw, open) {
    var depth = 0;
    for (var i = open + "hl.bind(".length - 1; i < raw.length; i++) {
        var c = raw[i];
        if (c === '"') {
            i = strEnd(raw, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(') depth++;
        else if (c === ')') {
            depth--;
            if (depth === 0) return i;
        }
    }
    return -1;
}

/**
 * Returns the absolute index where the argument after the nth top-level comma (0-based) begins, or -1, using the same depth and quote scan as rebind.
 */
function argStart(raw, innerStart, nth) {
    var depth = 0;
    var seen = -1;
    for (var i = innerStart; i < raw.length; i++) {
        var c = raw[i];
        if (c === '"') {
            i = strEnd(raw, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') {
            if (depth === 0) return -1;
            depth--;
        } else if (c === ',' && depth === 0) {
            seen++;
            if (seen === nth) return i + 1;
        }
    }
    return -1;
}

/**
 * Returns the half-open { start, end } range of top-level argument `argIndex` in the `hl.bind(...)` call, or null.
 */
function argRange(raw, argIndex) {
    var open = raw.indexOf("hl.bind(");
    if (open === -1) return null;
    var innerStart = open + "hl.bind(".length;
    var close = closeParenIndex(raw, open);
    if (close === -1) return null;

    var start = argIndex === 0 ? innerStart : argStart(raw, innerStart, argIndex - 1);
    if (start === -1) return null;

    var end = argStart(raw, start, 0);
    if (end === -1) end = close;
    else end = end - 1;
    return { start: start, end: end };
}

/**
 * Appends an exec bind after the last non-empty line, with a non-empty `name` as a trailing `-- name` comment.
 */
function add(luaText, combo, cmd, name) {
    if (!combo || !combo.length)
        return { text: luaText, ok: false, error: "empty combo" };
    if (!cmd || !cmd.length)
        return { text: luaText, ok: false, error: "empty command" };

    var modValue = readMod(luaText);
    var lines = luaText.split("\n");

    var first = comboExpr(combo, modValue);
    var line = "hl.bind(" + first + ', hl.dsp.exec_cmd("' + escapeCmd(cmd) + '"))';
    if (name && name.length)
        line += " -- " + name;

    var insertAt = lines.length;
    for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trim().length) { insertAt = i + 1; break; }
        insertAt = i;
    }
    lines.splice(insertAt, 0, line);
    return { text: lines.join("\n"), ok: true, error: "" };
}

function del(luaText, lineIndex) {
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length)
        return { text: luaText, ok: false, error: "invalid lineIndex" };
    lines.splice(lineIndex, 1);
    return { text: lines.join("\n"), ok: true, error: "" };
}

/**
 * Rewrites only the dispatch (arg 1) to `exec_cmd("<cmd>")`, leaving combo and opts untouched.
 */
function editCmd(luaText, lineIndex, cmd) {
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length)
        return { text: luaText, ok: false, error: "invalid lineIndex" };

    var raw = lines[lineIndex];
    var range = argRange(raw, 1);
    if (!range)
        return { text: luaText, ok: false, error: "could not isolate dispatch arg" };

    var slice = raw.slice(range.start, range.end);
    var leading = slice.match(/^\s*/)[0];
    var trailing = slice.match(/\s*$/)[0];
    var dispatch = 'hl.dsp.exec_cmd("' + escapeCmd(cmd) + '")';

    lines[lineIndex] = raw.slice(0, range.start) + leading + dispatch + trailing + raw.slice(range.end);
    return { text: lines.join("\n"), ok: true, error: "" };
}

/**
 * Guards editAction against writing a dispatch with unbalanced brackets or quotes, which would break the whole lua config.
 */
function balanceOk(s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
        var c = s[i];
        if (c === '"') {
            i = strEnd(s, i);
            if (i < 0) break;
            continue;
        }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') {
            depth--;
            if (depth < 0) return false;
        }
    }
    return depth === 0 && i === s.length;
}

/**
 * Replaces the dispatch verbatim for what the command field cannot express (window.*, focus, os.getenv path), refusing unbalanced input so a stray edit cannot break the config.
 */
function editAction(luaText, lineIndex, action) {
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length)
        return { text: luaText, ok: false, error: "invalid lineIndex" };
    if (!balanceOk(action))
        return { text: luaText, ok: false, error: "unbalanced () or quote" };

    var raw = lines[lineIndex];
    var range = argRange(raw, 1);
    if (!range)
        return { text: luaText, ok: false, error: "could not isolate dispatch arg" };

    var slice = raw.slice(range.start, range.end);
    var leading = slice.match(/^\s*/)[0];
    var trailing = slice.match(/\s*$/)[0];

    lines[lineIndex] = raw.slice(0, range.start) + leading + action + trailing + raw.slice(range.end);
    return { text: lines.join("\n"), ok: true, error: "" };
}

/**
 * Strips any existing comment after the closing paren, then appends ` -- name` when `name` is non-empty.
 */
function editName(luaText, lineIndex, name) {
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length)
        return { text: luaText, ok: false, error: "invalid lineIndex" };

    var raw = lines[lineIndex];
    var open = raw.indexOf("hl.bind(");
    if (open === -1)
        return { text: luaText, ok: false, error: "no hl.bind on line" };
    var close = closeParenIndex(raw, open);
    if (close === -1)
        return { text: luaText, ok: false, error: "unterminated bind" };

    var head = raw.slice(0, close + 1);
    var rest = raw.slice(close + 1).replace(/\s*--.*$/, "");
    var line = head + rest;
    if (name && name.length)
        line += " -- " + name;

    lines[lineIndex] = line;
    return { text: lines.join("\n"), ok: true, error: "" };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parse, rebind, add, del, editCmd, editAction, execCmd, balanceOk };
}
