#!/bin/sh
name="$1"
run="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$run/${name}-${HYPRLAND_INSTANCE_SIGNATURE}-watchdog.lock"
flock -n 9 || exit 0

while :; do
    qs -c "$name" 9>&- >/dev/null 2>&1
    [ -S "$run/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ] || exit 0
    sleep 1
done
