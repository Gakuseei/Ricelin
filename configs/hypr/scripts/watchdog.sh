#!/bin/sh
name="$1"
run="${XDG_RUNTIME_DIR:-/tmp}"
beat="$run/ricelin-$name-alive"
ref="$run/ricelin-$name-check"
exec 9>"$run/${name}-${HYPRLAND_INSTANCE_SIGNATURE}-watchdog.lock"
flock -n 9 || exit 0

while :; do
    qs -c "$name" 9>&- >/dev/null 2>&1 &
    pid=$!
    # A shell whose heartbeat stops twice in a row is hung (two misses ride out a suspend); kill it so it can never hold the screen.
    misses=0
    while kill -0 "$pid" 2>/dev/null; do
        touch "$ref"
        sleep 3
        kill -0 "$pid" 2>/dev/null || break
        if [ "$beat" -nt "$ref" ]; then
            misses=0
        else
            misses=$((misses + 1))
            if [ "$misses" -ge 2 ]; then
                echo "$(date '+%F %T') $name hung, restarted" >> "$run/ricelin-watchdog.log"
                kill -9 "$pid"
            fi
        fi
    done
    wait "$pid"
    [ -S "$run/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ] || exit 0
    sleep 1
done
