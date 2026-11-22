#!/usr/bin/env bash
# Sets vibrance (0..1023) with an nvibrant built for the running driver; prints "building", exits 0 ok, 2 unavailable, 3 no NVIDIA.

set -u

raw=${1:-0}
ver=$(cat /sys/module/nvidia/version 2>/dev/null) && [ -e /dev/nvidia-modeset ] || exit 3

dir=${XDG_CACHE_HOME:-$HOME/.cache}/ricelin/nvibrant
bin=$dir/nvibrant-$ver
failed=$dir/failed-$ver
ref=v1.3.1
sum=2117557edb14a11e9e9506193b896aacc446a12ab2cfd00dd3d9ec221e131d28
headers=(src/nvidia-modeset/interface src/nvidia-modeset/include src/common/inc
         src/common/sdk/nvidia/inc src/common/unix/common/inc)

build() (
    tmp=$(mktemp -d) || exit 1
    trap 'rm -rf "$tmp"' EXIT
    og=$tmp/og
    timeout 120 git clone -q -c advice.detachedHead=false --depth 1 --branch "$ver" \
        --filter=blob:none --sparse https://github.com/NVIDIA/open-gpu-kernel-modules "$og" &&
    timeout 120 git -C "$og" sparse-checkout set "${headers[@]}" &&
    curl -fsSL --max-time 30 -o "$tmp/main.cpp" \
        "https://raw.githubusercontent.com/Tremeschin/nvibrant/$ref/nvibrant/main.cpp" &&
    echo "$sum  $tmp/main.cpp" | sha256sum -c --quiet - &&
    g++ -O2 "${headers[@]/#/-I$og/}" "$tmp/main.cpp" -o "$tmp/nvibrant" &&
    mv -f "$tmp/nvibrant" "$bin"
)

if [ ! -x "$bin" ]; then
    mkdir -p "$dir"
    exec 9>"$dir/.lock"
    flock 9
    # A failed build waits ten minutes before the next try, so slider drags stay offline-friendly.
    if [ ! -x "$bin" ] && ! [ -n "$(find "$failed" -mmin -10 2>/dev/null)" ]; then
        echo building
        if build >/dev/null 2>&1; then
            find "$dir" -maxdepth 1 \( -name 'nvibrant-*' -o -name 'failed-*' \) ! -name "nvibrant-$ver" -delete
        else
            touch "$failed"
        fi
    fi
    exec 9>&-
fi

args=()
for _ in {1..16}; do args+=("$raw"); done

if [ -x "$bin" ] && out=$("$bin" "${args[@]}" 2>&1) && ! grep -qi failed <<<"$out"; then
    exit 0
fi
if command -v nvibrant >/dev/null && out=$(nvibrant "${args[@]}" 2>&1) && ! grep -qi failed <<<"$out"; then
    exit 0
fi
exit 2
