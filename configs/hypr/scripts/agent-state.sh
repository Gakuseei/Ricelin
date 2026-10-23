#!/bin/sh
# Claude Code hook: notes whether a session waits for Erik or is done, for the pill. Usage: agent-state.sh wait|done|clear|reset|end
[ -n "$XDG_RUNTIME_DIR" ] || exit 0
umask 077
dir="$XDG_RUNTIME_DIR/ricelin-agents"
in=$(cat)
sid=$(printf '%s' "$in" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$sid" ] || exit 0
f="$dir/$sid.json"

case "$1" in
    wait|done)
        mkdir -p "$dir"
        cwd=$(printf '%s' "$in" | jq -r '.cwd // empty')
        cwd=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
        msg=$(printf '%s' "$in" | jq -r '.message // empty')
        # The terminal window is the first ancestor of this hook that owns a Hyprland client.
        clients=$(hyprctl clients -j | jq -r '.[] | "\(.pid) \(.address)"')
        p=$PPID
        addr=""
        while [ "${p:-0}" -gt 1 ]; do
            addr=$(printf '%s\n' "$clients" | awk -v p="$p" '$1 == p { print $2; exit }')
            [ -n "$addr" ] && break
            p=$(awk '{ print $4 }' "/proc/$p/stat" 2>/dev/null)
        done
        # Nothing to announce when Erik is already looking at that terminal.
        [ -n "$addr" ] && [ "$addr" = "$(hyprctl activewindow -j | jq -r '.address // empty')" ] && { rm -f "$f"; date +%s%N > "$dir/.bump"; exit 0; }
        jq -nc --arg s "$1" --arg c "$cwd" --arg m "$msg" --arg w "$addr" --argjson t "$(date +%s)" \
            '{status: $s, cwd: $c, message: $m, window: $w, at: $t}' > "$f.tmp" && mv "$f.tmp" "$f"
        ;;
    clear)
        grep -q '"status":"wait"' "$f" 2>/dev/null || exit 0
        rm -f "$f"
        ;;
    reset|end)
        [ -f "$f" ] || exit 0
        rm -f "$f"
        ;;
    *)
        exit 0
        ;;
esac
date +%s%N > "$dir/.bump"
