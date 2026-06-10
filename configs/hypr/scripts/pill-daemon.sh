#!/bin/sh
i=0
while [ "$i" -lt 10 ]; do
    pgrep -f "qs -c pill" >/dev/null && exit 0
    qs -c pill -d 2>/dev/null
    sleep 2
    i=$((i + 1))
done
