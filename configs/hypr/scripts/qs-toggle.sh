#!/bin/sh
#
# qs-toggle: start or stop one extra Quickshell instance with a single call, so a
# keybind can summon it and the same key sends it away again.
#
#   qs-toggle boombox            the Boombox visualizer
#   qs-toggle persona            the Persona-Quickshell theme
#   qs-toggle path <main.qml>    any Quickshell entry file
#   qs-toggle config <dir>       any Quickshell config directory
#
# With no option the call toggles. --start and --stop are idempotent (starting a
# running instance or stopping a stopped one does nothing), and --status only
# reports through the exit code (0 running, 1 not), which is what the style
# switcher uses:
#
#   qs-toggle --start config <dir>
#   qs-toggle --stop config <dir>
#   qs-toggle --status config <dir>
#
# Where the named ones live can be overridden:
#   RICELIN_BOOMBOX_QML   default ~/Development/Qt6-Cava-plugin/main.qml
#   RICELIN_PERSONA_DIR   default ~/.config/quickshell/Persona-Quickshell
#
# Both of those load the CavaMonitor plugin from ~/.local/lib/qt6/qml, so the Qt
# import and library paths are extended before the instance starts.

have() { command -v "$1" >/dev/null 2>&1; }

fail() {
    printf 'qs-toggle: %s\n' "$*" >&2
    have notify-send && notify-send -u normal -a Ricelin "Cannot toggle" "$*"
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: qs-toggle [--start|--stop|--status] boombox
       qs-toggle [--start|--stop|--status] persona
       qs-toggle [--start|--stop|--status] path <main.qml>
       qs-toggle [--start|--stop|--status] config <dir>
EOF
    exit 2
}

act=toggle
case "${1:-}" in
    --start)  act=start;  shift ;;
    --stop)   act=stop;   shift ;;
    --status) act=status; shift ;;
esac

kind="${1:-}"
case "$kind" in
    boombox)
        kind=path
        target="${RICELIN_BOOMBOX_QML:-$HOME/Development/Qt6-Cava-plugin/main.qml}"
        ;;
    persona)
        kind=config
        target="${RICELIN_PERSONA_DIR:-$HOME/.config/quickshell/Persona-Quickshell}"
        ;;
    path | config)
        target="${2:-}"
        [ -n "$target" ] || usage
        ;;
    *) usage ;;
esac

# Match the exact "-p <file>" or "-c <dir>" this script starts, so an unrelated
# Quickshell (the pill itself, the lock screen) is never mistaken for it. Regex
# metacharacters in the path are escaped.
flag='-p'
[ "$kind" = config ] && flag='-c'
escaped="$(printf '%s' "$target" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
pattern="(^|/)(quickshell|qs) .*${flag} ${escaped}( |$)"

uid="$(id -u)" || fail "cannot determine the current user id"
running=0
pgrep -u "$uid" -f -- "$pattern" >/dev/null 2>&1 && running=1

case "$act" in
    status)
        [ "$running" = 1 ]
        exit $?
        ;;
    stop)
        [ "$running" = 1 ] && pkill -u "$uid" -f -- "$pattern" 2>/dev/null
        exit 0
        ;;
    start)
        [ "$running" = 1 ] && exit 0
        ;;
    toggle)
        if [ "$running" = 1 ]; then
            pkill -u "$uid" -f -- "$pattern" 2>/dev/null
            exit 0
        fi
        ;;
esac

if [ "$kind" = path ]; then
    [ -f "$target" ] || fail "$target not found. Set RICELIN_BOOMBOX_QML to its main.qml."
else
    [ -d "$target" ] || fail "$target not found. Set RICELIN_PERSONA_DIR to the config directory."
fi

if have quickshell; then
    qs_bin=quickshell
elif have qs; then
    qs_bin=qs
else
    fail "quickshell is not installed."
fi

qml_dir="$HOME/.local/lib/qt6/qml"
export QML2_IMPORT_PATH="$qml_dir${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export LD_LIBRARY_PATH="$qml_dir/CavaMonitor:$qml_dir:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Detached, in its own session: the instance must outlive the keybind that
# launched it and must not hold the compositor's stdio open.
if have setsid; then
    setsid "$qs_bin" "$flag" "$target" </dev/null >/dev/null 2>&1 &
elif have nohup; then
    nohup "$qs_bin" "$flag" "$target" </dev/null >/dev/null 2>&1 &
else
    "$qs_bin" "$flag" "$target" </dev/null >/dev/null 2>&1 &
fi
exit 0
