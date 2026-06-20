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

function splitArgs(inner) {
    var args = [];
    var depth = 0;
    var inStr = false;
    var start = 0;
    for (var i = 0; i < inner.length; i++) {
        var c = inner[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
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
        return { combo: modValue + modMatch[1], comboForm: "mod" };
    }
    var litMatch = firstArg.match(/^"([^"]*)"$/);
    if (litMatch) {
        return { combo: litMatch[1], comboForm: "literal" };
    }
    return { combo: firstArg, comboForm: "literal" };
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
 * Reads a trailing lua line-comment that sits AFTER the bind statement's closing
 * paren, i.e. `hl.bind(...)  -- my name`. The scan starts past `closeIndex` (the
 * outer close paren) so a `--` inside a quoted string arg can never be mistaken
 * for the name. Returns the trimmed comment text, or "" when there is none.
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
 * Pulls the inner shell command out of an `exec_cmd("...")` dispatch. Returns ""
 * for an env-prefixed or non-exec dispatch, where the command is not a single
 * editable literal.
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
    var inStr = false;
    var startInner = open + "hl.bind(".length;
    var endInner = -1;
    for (var i = startInner - 1; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
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
        opts: opts,
        lineIndex: lineIndex,
        raw: raw,
        comboForm: resolved.comboForm
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
    var inStr = false;
    for (var i = startInner; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
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
 * Builds the lua first-argument source for a combo: `mod .. " + X"` when the
 * combo starts with the configured modifier followed by " + ", else a literal
 * `"COMBO"`. Mirrors the firstArg construction in rebind.
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
 * Locates the outer closing paren of the `hl.bind(...)` call on `raw`, starting
 * the scan at the opening paren index. Returns the index of the close paren, or
 * -1 when the statement is malformed. Quoted strings are skipped so a paren
 * inside an arg never closes the call early.
 */
function closeParenIndex(raw, open) {
    var depth = 0;
    var inStr = false;
    for (var i = open + "hl.bind(".length - 1; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
        if (c === '(') depth++;
        else if (c === ')') {
            depth--;
            if (depth === 0) return i;
        }
    }
    return -1;
}

/**
 * Walks the call inner from `from` to the index just past the `nth` top-level
 * comma (0-based: nth=0 stops past the first comma). Returns the absolute index
 * into `raw` where the argument after that comma begins, or -1 when there are
 * fewer top-level commas. Depth and quoting match the rebind/splitArgs scan.
 */
function argStart(raw, innerStart, nth) {
    var depth = 0;
    var inStr = false;
    var seen = -1;
    for (var i = innerStart; i < raw.length; i++) {
        var c = raw[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
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
 * Finds the half-open range of the top-level argument at `argIndex` (0-based)
 * within the `hl.bind(...)` call on `raw`. Returns { start, end } as absolute
 * indices into `raw`, or null when the argument does not exist.
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
 * Appends a new exec bind. `combo` becomes a `mod .. " + X"` or literal first
 * arg via comboExpr; `cmd` is escaped into an `exec_cmd("...")` dispatch; a
 * non-empty `name` is added as a trailing `-- name` comment. The line is
 * inserted after the last non-empty line of the file. Returns { text, ok,
 * error }.
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

/**
 * Removes the bind on `lineIndex` entirely and rejoins the file. Returns
 * { text, ok }.
 */
function del(luaText, lineIndex) {
    var lines = luaText.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length)
        return { text: luaText, ok: false, error: "invalid lineIndex" };
    lines.splice(lineIndex, 1);
    return { text: lines.join("\n"), ok: true, error: "" };
}

/**
 * Rewrites the dispatch (second top-level argument) of the bind on `lineIndex`
 * to `exec_cmd("<cmd>")`, leaving the combo (arg 0) and opts (arg 2) untouched.
 * The argument range is found with the same depth/quote scanner rebind uses.
 * Returns { text, ok, error }.
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
 * True when every bracket and quote in `s` is balanced, treating text inside a
 * double-quoted string as opaque. Guards editAction against writing a dispatch
 * that would unbalance the hl.bind call and break the whole lua config.
 */
function balanceOk(s) {
    var depth = 0;
    var inStr = false;
    for (var i = 0; i < s.length; i++) {
        var c = s[i];
        if (inStr) {
            if (c === '"') inStr = false;
            continue;
        }
        if (c === '"') { inStr = true; continue; }
        if (c === '(' || c === '{' || c === '[') depth++;
        else if (c === ')' || c === '}' || c === ']') {
            depth--;
            if (depth < 0) return false;
        }
    }
    return depth === 0 && !inStr;
}

/**
 * Replaces the dispatch (second top-level argument) of the bind on `lineIndex`
 * with `action` verbatim, leaving the combo (arg 0) and opts (arg 2) intact. Use
 * for non-exec or env-prefixed dispatches the simple command field cannot express
 * (window.*, focus, os.getenv path); the caller passes the full lua source. The
 * action is refused when its brackets or quotes are unbalanced so a stray edit
 * cannot break the config. Returns { text, ok, error }.
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
 * Replaces the trailing `-- ...` name comment on the bind at `lineIndex`. Any
 * existing comment after the closing paren is stripped first, then ` -- name`
 * is appended when `name` is non-empty. Returns { text, ok }.
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

var Binds = {
    parse: parse,
    rebind: rebind,
    inUse: inUse,
    readMod: readMod,
    deriveLabel: deriveLabel,
    add: add,
    del: del,
    editCmd: editCmd,
    editAction: editAction,
    editName: editName
};

if (typeof module !== "undefined" && module.exports) {
    module.exports = Binds;
}
