#!/bin/sh
#
# Self-check for configs/hypr/scripts/ricelin-style. qs-toggle is replaced by a
# stub that logs its arguments and answers --status from $FAKE_RUNNING, on a PATH
# holding only a few linked coreutils, so no real Quickshell is touched.

# The stub is written through a quoted heredoc on purpose: $LOG and $FAKE_RUNNING
# must expand when the stub runs, not when it is written.
# shellcheck disable=SC2016
here="$(cd "$(dirname "$0")" && pwd)"
style="$here/../configs/hypr/scripts/ricelin-style"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
n=0

new_env() {
    n=$((n + 1))
    fake="$work/env$n"
    mkdir -p "$fake/bin" "$fake/home/.config/quickshell" "$fake/home/.local/state"
    LOG="$fake/log"
    : >"$LOG"
    export LOG HOME="$fake/home"
    unset XDG_CONFIG_HOME XDG_STATE_HOME FAKE_RUNNING
    for t in sed tr cat mkdir rm dirname; do
        p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$fake/bin/$t"
    done
    # --status answers from FAKE_RUNNING (space separated config/path basenames).
    cat >"$fake/qs-toggle" <<'STUB'
#!/bin/sh
echo "qs-toggle $*" >>"$LOG"
if [ "$1" = --status ]; then
    b="${3##*/}"
    case " $FAKE_RUNNING " in *" $b "*) exit 0 ;; esac
    exit 1
fi
exit 0
STUB
    chmod +x "$fake/qs-toggle"
    export RICELIN_QS_TOGGLE="$fake/qs-toggle"
}

# A Quickshell folder, as another setup would leave it.
folder() { mkdir -p "$HOME/.config/quickshell/$1"; : >"$HOME/.config/quickshell/$1/shell.qml"; }

run() { PATH="$fake/bin" "$style" "$@" 2>&1; }
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fails=$((fails + 1)); }
logged() { grep -q -- "$1" "$LOG"; }
expect() {
    if logged "$2"; then ok "$1"; else
        bad "$1 (wanted: $2)"
        sed 's/^/         log: /' "$LOG"
    fi
}
refute() { if logged "$2"; then bad "$1 (unexpected: $2)"; else ok "$1"; fi; }
is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2, wanted: $3)"; fi; }
tab="$(printf '\t')"

echo "discovery"
new_env; folder Persona-Quickshell; folder pill; folder launcher; folder lock
mkdir -p "$HOME/.config/quickshell/notashell"
out="$(run list)"
is "a Quickshell folder becomes a style, -Quickshell dropped" "$out" "persona${tab}Persona${tab}stopped${tab}"
is "Ricelin's own pill, launcher and lock are not styles" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" 1

new_env; folder Persona-Quickshell
FAKE_RUNNING="Persona-Quickshell" out="$(FAKE_RUNNING="Persona-Quickshell" run list)"
is "a running style is reported as running" "$out" "persona${tab}Persona${tab}running${tab}"

new_env
mkdir -p "$HOME/.config/ricelin/styles"
printf 'name=Neon Grid\nconfig=~/rices/neon\nnote=Loud one\n' >"$HOME/.config/ricelin/styles/neon.conf"
printf 'name=Solo\npath=~/rices/solo/main.qml\n' >"$HOME/.config/ricelin/styles/solo.conf"
out="$(run list)"
is "a .conf file defines a style with its note" "$(printf '%s\n' "$out" | sed -n 1p)" "neon${tab}Neon Grid${tab}stopped${tab}Loud one"
is "path= styles are listed too" "$(printf '%s\n' "$out" | sed -n 2p)" "solo${tab}Solo${tab}stopped${tab}"

new_env; folder Persona-Quickshell
mkdir -p "$HOME/.config/ricelin/styles"
printf 'name=My Persona\nconfig=~/elsewhere/persona\n' >"$HOME/.config/ricelin/styles/persona.conf"
out="$(run list)"
is "a .conf file wins over a folder with the same id" "$out" "persona${tab}My Persona${tab}stopped${tab}"

new_env
mkdir -p "$HOME/.config/ricelin/styles"
printf 'name=Broken\n' >"$HOME/.config/ricelin/styles/broken.conf"
printf 'name=Bad id\nconfig=~/x\n' >"$HOME/.config/ricelin/styles/Bad Id.conf"
is "a .conf with no config or path, or a bad id, is skipped" "$(run list)" ""

new_env
mkdir -p "$HOME/.config/ricelin/styles"
printf 'name=Evil\nconfig=~/x\n$(touch %s/pwned)\n' "$fake" >"$HOME/.config/ricelin/styles/evil.conf"
run list >/dev/null
[ -e "$fake/pwned" ] && bad ".conf files are never executed" || ok ".conf files are never executed"

echo "switch"
new_env; folder Persona-Quickshell; folder Other-Quickshell
FAKE_RUNNING="Other-Quickshell"
export FAKE_RUNNING
run switch persona >/dev/null
expect "stops the other styles" "^qs-toggle --stop config $HOME/.config/quickshell/Other-Quickshell"
expect "starts the chosen one" "^qs-toggle --start config $HOME/.config/quickshell/Persona-Quickshell"
refute "never stops the one it starts" "^qs-toggle --stop config $HOME/.config/quickshell/Persona-Quickshell"
is "the choice is remembered" "$(cat "$HOME/.local/state/ricelin/style")" persona

new_env; folder Persona-Quickshell
run switch nonsense >/dev/null; st=$?
is "an unknown style fails" "$(PATH="$fake/bin" "$style" switch nonsense >/dev/null 2>&1; echo $?)" 1
refute "and starts nothing" "^qs-toggle --start"
mkdir -p "$HOME/.config/ricelin/styles"
printf 'name=Out\nconfig=~/x\n' >"$HOME/.config/ricelin/out.conf"
is "an id that walks out of the styles folder fails" "$(PATH="$fake/bin" "$style" switch '../out' >/dev/null 2>&1; echo $?)" 1
refute "and starts nothing from there" "^qs-toggle --start"

new_env; folder Persona-Quickshell
run switch persona >/dev/null
run switch ricelin >/dev/null
expect "switch ricelin stops every style" "^qs-toggle --stop config $HOME/.config/quickshell/Persona-Quickshell"
[ -e "$HOME/.local/state/ricelin/style" ] && bad "and forgets the choice" || ok "and forgets the choice"

echo "toggle"
new_env; folder Persona-Quickshell
run toggle persona >/dev/null
expect "toggle starts a stopped style" "^qs-toggle --start config $HOME/.config/quickshell/Persona-Quickshell"
is "and remembers it" "$(cat "$HOME/.local/state/ricelin/style")" persona

new_env; folder Persona-Quickshell
FAKE_RUNNING="Persona-Quickshell"; export FAKE_RUNNING
mkdir -p "$HOME/.local/state/ricelin"; echo persona >"$HOME/.local/state/ricelin/style"
run toggle persona >/dev/null
expect "toggle stops a running style" "^qs-toggle --stop config $HOME/.config/quickshell/Persona-Quickshell"
refute "and does not start it again" "^qs-toggle --start"
[ -e "$HOME/.local/state/ricelin/style" ] && bad "and forgets it" || ok "and forgets it"

new_env
printf '#!/bin/sh\necho "notify-send $*" >>"$LOG"\n' >"$fake/bin/notify-send"; chmod +x "$fake/bin/notify-send"
run toggle persona >/dev/null
expect "toggling a style that does not exist says so on screen" "^notify-send"

echo "current and apply"
new_env; folder Persona-Quickshell
is "current is ricelin when nothing runs" "$(run current)" ricelin
FAKE_RUNNING="Persona-Quickshell"; export FAKE_RUNNING
is "current names the running style" "$(run current)" persona

new_env; folder Persona-Quickshell
mkdir -p "$HOME/.local/state/ricelin"; echo persona >"$HOME/.local/state/ricelin/style"
run apply >/dev/null
expect "apply starts the remembered style" "^qs-toggle --start config $HOME/.config/quickshell/Persona-Quickshell"

new_env; folder Persona-Quickshell
run apply >/dev/null
refute "apply with nothing remembered starts nothing" "^qs-toggle --start"

new_env
mkdir -p "$HOME/.local/state/ricelin"; echo gone >"$HOME/.local/state/ricelin/style"
run apply >/dev/null
refute "apply ignores a style that no longer exists" "^qs-toggle --start"

new_env
is "no verb is a usage error" "$(PATH="$fake/bin" "$style" >/dev/null 2>&1; echo $?)" 2

echo
if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi
