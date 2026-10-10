#!/bin/sh
#
# Self-check for configs/hypr/scripts/ricelin-sys. Every case runs the helper with
# a PATH that holds only stubs plus a few linked coreutils, so nothing real is
# touched (no suspend, no pkill) and the result does not depend on the init system
# of the machine running it.

# The stub generators below write scripts through single-quoted printf formats on
# purpose: $* and $LOG must expand when the stub runs, not when it is written.
# shellcheck disable=SC2016
here="$(cd "$(dirname "$0")" && pwd)"
sys="$here/../configs/hypr/scripts/ricelin-sys"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
n=0

# stub NAME [EXIT]: a program that appends "NAME args" to $LOG and exits EXIT.
stub() {
    printf '#!/bin/sh\necho "%s $*" >>"$LOG"\nexit %s\n' "$1" "${2:-0}" >"$fake/bin/$1"
    chmod +x "$fake/bin/$1"
}

# Fresh sandbox. $fake/bin is the helper's whole PATH. The default is a
# non-systemd host with nothing installed; cases add what they need.
new_env() {
    n=$((n + 1))
    fake="$work/env$n"
    mkdir -p "$fake/bin" "$fake/run/pulse"
    LOG="$fake/log"
    : >"$LOG"
    export LOG
    for t in sleep id ps tr dirname cat setsid nohup; do
        p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$fake/bin/$t"
    done
    unset FAKE_RUNNING FAKE_UNITS RICELIN_SKIP_AUDIO
    export RICELIN_TEST_SYSTEMD_DIR="$fake/no-systemd"
    export XDG_RUNTIME_DIR="$fake/run"
    stub pkill
    printf '#!/bin/sh\necho "pgrep $*" >>"$LOG"\n[ "${FAKE_RUNNING:-0}" = 1 ]\n' >"$fake/bin/pgrep"
    chmod +x "$fake/bin/pgrep"
}

as_systemd() { export RICELIN_TEST_SYSTEMD_DIR="$fake/run"; }

# systemctl that answers "does this user unit exist" from $FAKE_UNITS.
stub_systemctl() {
    cat >"$fake/bin/systemctl" <<'EOF'
#!/bin/sh
echo "systemctl $*" >>"$LOG"
if [ "$1" = --user ] && [ "$2" = cat ]; then
    case " $FAKE_UNITS " in *" ${3%.service} "*) exit 0 ;; esac
    exit 1
fi
exit 0
EOF
    chmod +x "$fake/bin/systemctl"
}

run() { PATH="$fake/bin" "$sys" "$@" >/dev/null 2>&1; }

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
# Daemons are spawned in the background, so give them a moment to log.
await() {
    i=0
    while ! logged "$2" && [ "$i" -lt 30 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    expect "$1" "$2"
}

echo "power"
new_env; as_systemd; stub_systemctl; stub loginctl
run power suspend
expect "systemd uses systemctl" '^systemctl suspend'
refute "systemd leaves loginctl alone" '^loginctl'

new_env; stub_systemctl; stub loginctl
run power reboot
expect "elogind host uses loginctl" '^loginctl reboot'
refute "a systemctl shim is never called off-systemd" '^systemctl'

new_env; stub poweroff
run power poweroff
expect "no logind falls back to the plain command" '^poweroff'

new_env; stub notify-send
run power poweroff; status 1 $? "nothing usable exits 1"
expect "and says so on screen" '^notify-send -u critical'

new_env
run power explode; status 2 $? "unknown action exits 2"

echo "inhibit"
new_env; as_systemd; stub systemd-inhibit
run inhibit idle
expect "systemd-inhibit with the right arguments" \
    '^systemd-inhibit --what=idle:sleep --who=Ricelin --why=keep awake --mode=block sleep infinity'

new_env; stub systemd-inhibit; stub elogind-inhibit
run inhibit idle
expect "elogind-inhibit off-systemd" '^elogind-inhibit --what=idle:sleep'
refute "systemd-inhibit untouched off-systemd" '^systemd-inhibit'

new_env; stub wlinhibit
run inhibit idle
expect "wlinhibit as the last resort" '^wlinhibit'

new_env
run inhibit idle; status 127 $? "no inhibitor at all exits 127"

echo "service"
new_env; as_systemd; stub_systemctl; export FAKE_UNITS="hypridle"
run service restart hypridle
expect "systemd unit is restarted through systemctl" '^systemctl --user restart hypridle'
refute "and not killed by hand" '^pkill'

new_env; as_systemd; stub_systemctl; stub hyprsunset; export FAKE_UNITS=""
run service restart hyprsunset
expect "no unit: the old instance is killed" '^pkill -x hyprsunset'
await "no unit: the daemon is started directly" '^hyprsunset'
refute "no unit: systemctl never restarts it" '^systemctl --user restart'

new_env; stub hypridle; export FAKE_RUNNING=1
run service start hypridle
sleep 0.3
refute "start is a no-op when it is already running" '^hypridle'

new_env; stub hyprpolkitagent
run service start polkit
await "polkit is an alias for hyprpolkitagent" '^hyprpolkitagent'

new_env
run service restart hypridle; status 1 $? "missing daemon exits 1"

new_env
run service restart bash; status 2 $? "only the three known daemons are accepted"

echo "ghostty-reload"
new_env; stub gdbus
run ghostty-reload
expect "gdbus call with the right action" \
    '^gdbus call --session --dest com.mitchellh.ghostty .*Activate reload-config \[\] {}'

new_env; stub busctl
run ghostty-reload
expect "busctl when gdbus is missing" '^busctl --user call com.mitchellh.ghostty'

new_env
run ghostty-reload; status 0 $? "no bus tool is not an error"

echo "session-start"
new_env
for b in pipewire wireplumber pipewire-pulse hyprpolkitagent hypridle hyprsunset; do stub "$b"; done
: >"$XDG_RUNTIME_DIR/pipewire-0"
: >"$XDG_RUNTIME_DIR/pulse/native"
run session-start
for b in pipewire wireplumber pipewire-pulse hyprpolkitagent hypridle hyprsunset; do
    await "off-systemd starts $b" "^$b"
done
expect "hypridle is restarted to pick up its config" '^pkill -x hypridle'

new_env; stub pipewire; stub hypridle; stub hyprpolkitagent
export RICELIN_SKIP_AUDIO=1
run session-start
await "RICELIN_SKIP_AUDIO still starts hypridle" '^hypridle'
refute "RICELIN_SKIP_AUDIO leaves pipewire alone" '^pipewire'

new_env; as_systemd; stub_systemctl; stub pipewire; stub hyprsunset
export FAKE_UNITS="hyprpolkitagent hypridle"
run session-start
expect "systemd starts the session target" '^systemctl --user start hyprland-session.target'
expect "systemd starts the polkit unit" '^systemctl --user start hyprpolkitagent'
expect "systemd restarts hypridle" '^systemctl --user restart hypridle'
sleep 0.3
refute "systemd hosts do not spawn pipewire by hand" '^pipewire'
refute "systemd hosts leave hyprsunset to its unit" '^hyprsunset'

echo "doctor"
new_env
out="$(PATH="$fake/bin" "$sys" doctor 2>&1)"; status 0 $? "doctor exits 0"
case "$out" in *"systemd"*"no"*) ok "doctor reports a non-systemd host" ;; *) bad "doctor output: $out" ;; esac

echo
if [ "$fails" -eq 0 ]; then
    echo "all ok"
else
    echo "$fails failed"
    exit 1
fi
