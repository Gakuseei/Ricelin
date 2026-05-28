#!/usr/bin/env bash
# Install the Torii GRUB theme + enable dual/triple-boot detection.
# Run as root:  sudo bash configs/grub/install-torii.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/themes/torii"
DEST="/boot/grub/themes/torii"
GRUBDEF="/etc/default/grub"

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo bash $0"; exit 1; }

echo "==> install theme files -> $DEST"
mkdir -p "$DEST"
cp -f "$SRC"/theme.txt "$SRC"/background.png "$SRC"/*.pf2 "$DEST/"

echo "==> backup + set GRUB_THEME"
cp -n "$GRUBDEF" "$GRUBDEF.bak-pre-torii" || true
if grep -q '^GRUB_THEME=' "$GRUBDEF"; then
  sed -i "s|^GRUB_THEME=.*|GRUB_THEME='$DEST/theme.txt'|" "$GRUBDEF"
else
  echo "GRUB_THEME='$DEST/theme.txt'" >> "$GRUBDEF"
fi
grep '^GRUB_THEME=' "$GRUBDEF"

echo "==> enable os-prober + deps (Windows + old CachyOS on sda4)"
sed -i "s|^#*GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|" "$GRUBDEF" \
  || echo "GRUB_DISABLE_OS_PROBER=false" >> "$GRUBDEF"
pacman -S --needed --noconfirm os-prober ntfs-3g >/dev/null

echo "==> os-prober scan (other OS detected?):"
os-prober || true

echo "==> regenerate grub.cfg"
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> boot menu entries now:"
grep -E "^menuentry|^submenu" /boot/grub/grub.cfg | sed -E "s/ \{.*//"
echo "==> DONE. Theme=torii. Reboot to see it."
