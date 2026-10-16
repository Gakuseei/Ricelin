#!/usr/bin/env bash
#
# Self-check for launch-guard.sh: fakes notify-send and wl-copy on PATH, then
# asserts a fast non-zero exit toasts and copies, a clean exit stays silent.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT

cat >"$fake/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$@" >"$fake/notify.args"
echo copy
EOF
cat >"$fake/wl-copy" <<EOF
#!/bin/sh
cat >"$fake/clip"
EOF
chmod +x "$fake"/notify-send "$fake"/wl-copy
export PATH="$fake:$PATH"

"$here/launch-guard.sh" Broken "" "" sh -c 'echo boom >&2; exit 127'
grep -q 'Broken failed (exit 127)' "$fake/notify.args"
grep -q '^boom$' "$fake/notify.args"
grep -q '^Broken: exit 127$' "$fake/clip"
grep -q '^boom$' "$fake/clip"

rm -f "$fake/notify.args" "$fake/clip"
"$here/launch-guard.sh" Fine "" "" sh -c 'echo warn >&2; exit 0'
[ ! -e "$fake/notify.args" ]
[ ! -e "$fake/clip" ]

rm -f "$fake/notify.args"
"$here/launch-guard.sh" Missing "" "" definitely-not-a-binary-xyz
grep -q 'Missing failed (exit 127)' "$fake/notify.args"

rm -f "$fake/notify.args"
mkdir -p "$fake/Applications" "$fake/share/applications" "$fake/share/ricelin"
printf '#!/bin/sh\ntouch "%s/ran"\n' "$fake" >"$fake/Applications/Foo-1.1-x86_64.AppImage"
chmod +x "$fake/Applications/Foo-1.1-x86_64.AppImage"
printf '[Desktop Entry]\nExec="%s/Applications/Foo-1.0-x86_64.AppImage" %%U\n' "$fake" >"$fake/share/applications/ricelin-foo.desktop"
printf '{"foo":{"appimagePath":"%s/Applications/Foo-1.0-x86_64.AppImage","desktopPath":"%s/share/applications/ricelin-foo.desktop"}}' "$fake" "$fake" >"$fake/share/ricelin/appimages.json"
HOME="$fake" XDG_DATA_HOME="$fake/share" "$here/launch-guard.sh" Foo "" "" "$fake/Applications/Foo-1.0-x86_64.AppImage"
[ -e "$fake/ran" ]
[ ! -e "$fake/notify.args" ]
grep -q "Foo-1.1-x86_64.AppImage" "$fake/share/applications/ricelin-foo.desktop"
[ "$(jq -r .foo.appimagePath "$fake/share/ricelin/appimages.json")" = "$fake/Applications/Foo-1.1-x86_64.AppImage" ]

echo ok
