#!/bin/sh
name="$1"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/${name}-watchdog.lock"
flock -n 9 || exit 0

while true; do
    qs -c "$name" ipc show >/dev/null 2>&1 || qs -c "$name" -d 9>&- 2>/dev/null
    sleep 5
done
