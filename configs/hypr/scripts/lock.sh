#!/bin/sh

umask 077

dir="${XDG_RUNTIME_DIR:-/tmp}"
mode="${1:-lock}"

failed=0
pill_hidden=0

cleanup()
{
    if [ "$pill_hidden" -eq 1 ]; then
        qs -c pill ipc call pill captureShow >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT INT TERM

rm -f "$dir"/ricelin-lock-*.png

# Tell the Pill to enter its normal resting state first.
if qs -c pill ipc call pill captureHide >/dev/null 2>&1; then
    pill_hidden=1
    sleep 0.50
fi

# Capture the already-collapsed desktop synchronously.
for out in $(hyprctl monitors -j | jq -r '.[].name'); do
    [ -n "$out" ] || continue

    if ! grim         -o "$out"         "$dir/ricelin-lock-$out.png"         2>/dev/null
    then
        failed=1
    fi
done

for out in $(hyprctl monitors -j | jq -r '.[].name'); do
    [ -n "$out" ] || continue

    if [ ! -s "$dir/ricelin-lock-$out.png" ]; then
        failed=1
    fi
done

if [ "$failed" -ne 0 ]; then
    echo "Ricelin lock: desktop capture failed" >&2
    exit 1
fi

cleanup
pill_hidden=0

case "$mode" in
    sleep)
        qs -c lock ipc call lock sleepLock >/dev/null 2>&1 || {
            echo "Ricelin lock: failed to establish sleep lock" >&2
            exit 1
        }
        sleep 0.15
        ;;

    lock)
        date +%s%N > "$dir/ricelin-lock-trigger"
        ;;

    *)
        echo "Ricelin lock: unknown mode '$mode'" >&2
        exit 2
        ;;
esac
