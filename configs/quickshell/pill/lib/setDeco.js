/**
 * Returns a top-level Lua field's value with surrounding quotes stripped, or "" when absent.
 */
function getField(text, name) {
    var re = new RegExp("\\b" + name + "\\s*=\\s*(\"[^\"]*\"|[^,}\\n]*)");
    var m = re.exec(text);
    if (!m)
        return "";
    var v = m[1].trim();
    if (v.length >= 2 && v.charAt(0) === "\"" && v.charAt(v.length - 1) === "\"")
        return v.slice(1, -1);
    return v;
}

/**
 * `valueLiteral` comes pre-formatted (strings already double-quoted), and a quoted old value is replaced whole so its commas do not end the field.
 */
function setField(text, name, valueLiteral) {
    var re = new RegExp("(\\b" + name + "\\s*=\\s*)(\"[^\"]*\"|[^,}\\n]*)");
    if (!re.test(text))
        return { text: text, ok: false };
    return { text: text.replace(re, "$1" + valueLiteral), ok: true };
}

/**
 * Brace-balances to the matching close so a nested table (decoration holds shadow and blur) does not end the scan early.
 */
function getBlock(text, blockName) {
    var head = new RegExp(blockName + "\\s*=\\s*\\{");
    var m = head.exec(text);
    if (!m)
        return null;
    var open = m.index + m[0].length - 1;
    var depth = 0;
    for (var i = open; i < text.length; i++) {
        var c = text.charAt(i);
        if (c === "{") {
            depth++;
        } else if (c === "}") {
            depth--;
            if (depth === 0)
                return { start: open + 1, end: i, body: text.slice(open + 1, i) };
        }
    }
    return null;
}

function getBlockField(text, blockName, name) {
    var blk = getBlock(text, blockName);
    if (!blk)
        return "";
    return getField(blk.body, name);
}

/**
 * Scoping to the block keeps a name shared by siblings (`enabled` in shadow and blur) from matching the wrong one.
 */
function setBlockField(text, blockName, name, valueLiteral) {
    var blk = getBlock(text, blockName);
    if (!blk)
        return { text: text, ok: false };
    var res = setField(blk.body, name, valueLiteral);
    if (!res.ok)
        return { text: text, ok: false };
    return { text: text.slice(0, blk.start) + res.text + text.slice(blk.end), ok: true };
}

function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Returns { start, end } of the first `hl.layer_rule({ ... })` call whose body has `name = "ruleName"`, or null.
 */
function findNamedRule(text, ruleName) {
    var head = /hl\.layer_rule\s*\(\s*\{/g;
    var nameRe = new RegExp("name\\s*=\\s*\"" + escapeRe(ruleName) + "\"");
    var m;
    while ((m = head.exec(text)) !== null) {
        var open = text.indexOf("{", m.index);
        var depth = 0;
        for (var i = open; i < text.length; i++) {
            var c = text.charAt(i);
            if (c === "{") {
                depth++;
            } else if (c === "}") {
                depth--;
                if (depth === 0) {
                    var close = text.indexOf(")", i);
                    if (close === -1)
                        close = i;
                    var end = close + 1;
                    if (nameRe.test(text.slice(m.index, end)))
                        return { start: m.index, end: end };
                    break;
                }
            }
        }
    }
    return null;
}

/**
 * Reports whether an `hl.layer_rule` call named `ruleName` is present.
 */
function hasNamedRule(text, ruleName) {
    return findNamedRule(text, ruleName) !== null;
}

/**
 * Also drops one trailing newline and the blank line addNamedRule puts in front, leaving the rest of the file byte-identical.
 */
function removeNamedRule(text, ruleName) {
    var r = findNamedRule(text, ruleName);
    if (!r)
        return { text: text, ok: false };
    var start = r.start;
    if (text.charAt(start - 1) === "\n" && text.charAt(start - 2) === "\n")
        start--;
    var end = r.end;
    if (text.charAt(end) === "\n")
        end++;
    return { text: text.slice(0, start) + text.slice(end), ok: true };
}

/**
 * Appends `block` after a blank line unless that exact block is already present, in which case ok is false.
 */
function addNamedRule(text, block) {
    if (text.indexOf(block) !== -1)
        return { text: text, ok: false };
    var sep = text.length === 0 || text.charAt(text.length - 1) === "\n" ? "\n" : "\n\n";
    return { text: text + sep + block, ok: true };
}
