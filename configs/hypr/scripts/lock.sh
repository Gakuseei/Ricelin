#!/bin/sh
umask 077
dir="${XDG_RUNTIME_DIR:-/tmp}"

# Grab every monitor first so the desktop is captured while it is still live and
# on screen, then lock. The lock surface reveals onto these grabs, so they must
# exist before it mounts; showing the live desktop during the grab reads as the
# desktop simply blurring into the lock, with no flash.
for out in $(hyprctl monitors -j | jq -r '.[].name'); do
    [ -n "$out" ] || continue
    rm -f "$dir/ricelin-lock-$out.png"
    grim -o "$out" "$dir/ricelin-lock-$out.png" 2>/dev/null &
done
wait

# Poke the lock daemon through its file watch instead of spawning a whole qs client,
# which shaves the Qt client startup off the lock delay.
date +%s%N > "$dir/ricelin-lock-trigger"

# Confirm the lock; a down or still-starting daemon (deaf for 800 ms) gets started and asked over IPC.
locked() {
    i=0
    while [ "$i" -lt "$1" ]; do
        [ -s "$dir/ricelin-locked" ] && return 0
        sleep 0.1
        i=$((i + 1))
    done
    return 1
}
locked 20 && exit 0
pgrep -f "qs -c lock$" >/dev/null || setsid -f "$HOME/.config/hypr/scripts/watchdog.sh" lock >/dev/null 2>&1
i=0
until qs -c lock ipc call lock lock >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && break
    sleep 0.2
done
locked 30
