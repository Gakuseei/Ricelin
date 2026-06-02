#!/bin/sh
i=0
while [ "$i" -lt 10 ]; do
    pgrep -f "qs -c sidebar" >/dev/null && exit 0
    qs -c sidebar -d 2>/dev/null
    sleep 2
    i=$((i + 1))
done
