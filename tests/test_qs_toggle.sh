#!/bin/sh
#
# Self-check for configs/hypr/scripts/qs-toggle.sh. pgrep, pkill and the
# Quickshell binary are stubs on a PATH that holds nothing else, so no real
# process is started or killed.

# The stub generators write scripts through single-quoted printf formats on
# purpose: $* and $LOG must expand when the stub runs, not when it is written.
# shellcheck disable=SC2016
here="$(cd "$(dirname "$0")" && pwd)"
toggle="$here/../configs/hypr/scripts/qs-toggle.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
n=0

stub() {
    printf '#!/bin/sh\necho "%s $*" >>"$LOG"\nexit %s\n' "$1" "${2:-0}" >"$fake/bin/$1"
    chmod +x "$fake/bin/$1"
}

new_env() {
    n=$((n + 1))
    fake="$work/env$n"
    mkdir -p "$fake/bin" "$fake/home"
    LOG="$fake/log"
    : >"$LOG"
    export LOG HOME="$fake/home"
    for t in sed printf dirname cat setsid nohup grep id; do
        p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$fake/bin/$t"
    done
    unset RICELIN_BOOMBOX_QML RICELIN_PERSONA_DIR
    # Match the fixture command line using the same ERE pattern as pgrep.
    printf '#!/bin/sh\necho "pgrep $*" >>"$LOG"\npattern=""\nwhile [ "$#" -gt 0 ]; do\n  if [ "$1" = "--" ]; then shift; pattern="${1:-}"; break; fi\n  shift\ndone\n[ -n "$pattern" ] && [ -n "${FAKE_CMDLINE:-}" ] || exit 1\nprintf "%%s\\n" "$FAKE_CMDLINE" | grep -E -- "$pattern" >/dev/null\n' >"$fake/bin/pgrep"
    chmod +x "$fake/bin/pgrep"
    unset FAKE_CMDLINE
    stub pkill
    stub notify-send
}

run() { PATH="$fake/bin" "$toggle" "$@" >/dev/null 2>&1; }
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
status() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (exit $2, wanted $1)"; fi; }
# The instance is started in the background, so give it a moment to log.
await() {
    i=0
    while ! logged "$2" && [ "$i" -lt 30 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    expect "$1" "$2"
}

echo "boombox"
new_env; stub quickshell
mkdir -p "$HOME/Development/Qt6-Cava-plugin"; : >"$HOME/Development/Qt6-Cava-plugin/main.qml"
run boombox; status 0 $? "starts when it is not running"
expect "pgrep is scoped to the current uid" '^pgrep -u [0-9][0-9]* -f'
await "uses -p with the default entry file" "^quickshell -p $HOME/Development/Qt6-Cava-plugin/main.qml"

new_env; stub quickshell
: >"$fake/box.qml"; export RICELIN_BOOMBOX_QML="$fake/box.qml"
run boombox
await "RICELIN_BOOMBOX_QML overrides the path" "^quickshell -p $fake/box.qml"

new_env; stub quickshell
: >"$fake/box.qml"; export RICELIN_BOOMBOX_QML="$fake/box.qml"
export FAKE_CMDLINE="/usr/bin/quickshell -p $fake/box.qml"
run boombox; status 0 $? "running: the same call stops it"
expect "pkill is scoped to the current uid" '^pkill -u [0-9][0-9]* -f'
sleep 0.3
refute "stop does not start a second copy" '^quickshell'

new_env; stub quickshell
run boombox; status 1 $? "missing main.qml exits 1"
expect "and says so on screen" '^notify-send'
refute "and starts nothing" '^quickshell'

echo "persona"
new_env; stub qs
mkdir -p "$fake/persona"; export RICELIN_PERSONA_DIR="$fake/persona"
run persona
await "starts with -c <dir>" "^qs -c $fake/persona"

new_env; stub quickshell
mkdir -p "$fake/persona"; export RICELIN_PERSONA_DIR="$fake/persona"
run persona; sleep 0.2
await "prefers the quickshell binary" "^quickshell -c $fake/persona"

new_env
mkdir -p "$fake/persona"; export RICELIN_PERSONA_DIR="$fake/persona"
run persona; status 1 $? "no quickshell installed exits 1"

echo "generic"
new_env; stub quickshell
mkdir -p "$fake/cfg"
run config "$fake/cfg"
await "config <dir> starts any config" "^quickshell -c $fake/cfg"
new_env; run path; status 2 $? "path without an argument is a usage error"
new_env; run nonsense; status 2 $? "unknown verb is a usage error"

echo "start, stop and status"
new_env; stub quickshell
mkdir -p "$fake/cfg"; export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/cfg"
run --start config "$fake/cfg"; status 0 $? "--start on a running instance is a no-op"
sleep 0.3
refute "and does not launch a second copy" '^quickshell'
refute "and does not kill it" '^pkill'

new_env; stub quickshell
mkdir -p "$fake/cfg"
run --start config "$fake/cfg"
await "--start launches a stopped instance" "^quickshell -c $fake/cfg"

new_env; stub quickshell
mkdir -p "$fake/cfg"; export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/cfg"
run --stop config "$fake/cfg"; status 0 $? "--stop on a running instance succeeds"
expect "and kills it" '^pkill -u [0-9][0-9]* -f'

new_env; stub quickshell
mkdir -p "$fake/cfg"
run --stop config "$fake/cfg"; status 0 $? "--stop on a stopped instance is a no-op"
refute "and kills nothing" '^pkill'

new_env; stub quickshell
mkdir -p "$fake/cfg"; export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/cfg"
run --status config "$fake/cfg"; status 0 $? "--status exits 0 when running"
sleep 0.2
refute "and starts nothing" '^quickshell'
new_env; stub quickshell
run --status config "$fake/never-made"; status 1 $? "--status exits 1 when stopped, even for a missing directory"
refute "and does not complain on screen" '^notify-send'

echo "pattern safety"
new_env
mkdir -p "$fake/odd.dir+1"; export RICELIN_PERSONA_DIR="$fake/odd.dir+1"
export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/odd.dir+1"
run --status persona; status 0 $? "escaped metacharacters match the actual command line"
export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/oddXdirrr1"
run --status persona; status 1 $? "metacharacter lookalikes do not match"
export FAKE_CMDLINE="/usr/bin/quickshell -c $fake/odd.dir+1.bak"
run --status persona; status 1 $? "path suffixes do not match"

echo
if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi
