#!/bin/sh
#
# Fails when an init-system, login-manager or system-bus command shows up in the
# shipped configs outside configs/hypr/scripts/ricelin-sys. That helper is the one
# place allowed to name them; everything else must call it. The installer is out
# of scope on purpose: it is the one program that has to know which init it is
# running on.

root="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
pattern='systemctl|loginctl|systemd-inhibit|elogind-inhibit|busctl|journalctl|systemd-run'

hits="$(grep -rInE "$pattern" "$root/configs" \
    --exclude=ricelin-sys --exclude-dir=systemd 2>/dev/null)"

if [ -n "$hits" ]; then
    printf 'init-specific calls outside ricelin-sys:\n%s\n' "$hits" | sed "s#$root/##" >&2
    echo "Route them through configs/hypr/scripts/ricelin-sys instead." >&2
    exit 1
fi
echo "lint-init-calls: ok"
