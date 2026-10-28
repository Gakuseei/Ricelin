.pragma library

/** The open settings window; set before any page loads and cleared when it closes. */
var shell = null;

/** `kind` "error" shows a failure without the check mark. */
function toast(msg, kind) {
    if (shell)
        shell.toast(String(msg), kind ? String(kind) : "");
}

function open(page, key) {
    if (shell)
        shell.openPage(String(page || ""), key ? String(key) : "", "");
}
