#!/usr/bin/env bash
set -euo pipefail

flags_file="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin/flags.json"
WPDIR=$(jq -r '.wallpaperDir // ""' "$flags_file" 2>/dev/null || echo "")
[ -n "$WPDIR" ] || WPDIR="$HOME/Ricelin/wallpapers"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper"
MAP="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper-map"
BAG="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper-bag"
STILL="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin-wallpaper-still.png"

is_video() {
    case "${1##*.}" in
        [Mm][Pp]4|[Ww][Ee][Bb][Mm]|[Mm][Kk][Vv]|[Mm][Oo][Vv]) return 0 ;;
        *) return 1 ;;
    esac
}

ensure_daemon() {
    awww query >/dev/null 2>&1 && return 0
    local attempt i
    for attempt in 1 2 3 4 5; do
        awww-daemon >/dev/null 2>&1 &
        for i in $(seq 1 15); do
            awww query >/dev/null 2>&1 && return 0
            sleep 0.2
        done
    done
    return 1
}

list_pics() {
    find "$WPDIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \)
}

refill_bag() {
    local current="" shuffled
    [ -r "$STATE" ] && current=$(cat "$STATE")
    shuffled=$(list_pics | shuf)
    [ -n "$shuffled" ] || return 0
    if [ "$(printf '%s\n' "$shuffled" | head -n1)" = "$current" ] && [ "$(printf '%s\n' "$shuffled" | wc -l)" -gt 1 ]; then
        shuffled=$(printf '%s\n' "$shuffled" | tail -n +2; printf '%s\n' "$current")
    fi
    mkdir -p "$(dirname "$BAG")"
    printf '%s\n' "$shuffled" > "$BAG"
}

pop_bag() {
    local line refilled=false
    mkdir -p "$(dirname "$BAG")"
    (
        flock 9
        while :; do
            if [ ! -s "$BAG" ]; then
                [ "$refilled" = true ] && exit 1
                refill_bag
                refilled=true
                [ -s "$BAG" ] || exit 1
            fi
            line=$(head -n1 "$BAG")
            tail -n +2 "$BAG" > "$BAG.tmp" && mv "$BAG.tmp" "$BAG"
            if [ -f "$line" ]; then
                printf '%s\n' "$line"
                exit 0
            fi
        done
    ) 9>"$BAG.lock"
}

outputs() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name'
}

focused_output() {
    hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused)] | first.name // empty'
}

cursor_output() {
    local pos cx cy hit
    pos=$(hyprctl cursorpos 2>/dev/null) || { focused_output; return; }
    cx=${pos%%,*}
    cy=${pos##*, }
    hit=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson cx "$cx" --argjson cy "$cy" \
        'map(select(
            $cx >= .x and $cx < .x + ((if (.transform % 2) == 1 then .height else .width end) / .scale) and
            $cy >= .y and $cy < .y + ((if (.transform % 2) == 1 then .width else .height end) / .scale)
        )) | first.name // empty')
    [ -n "$hit" ] && printf '%s\n' "$hit" || focused_output
}

map_get() {
    awk -F'\t' -v o="$1" '$1 == o { print $2; exit }' "$MAP" 2>/dev/null || true
}

map_put() {
    mkdir -p "$(dirname "$MAP")"
    { awk -F'\t' -v o="$1" '$1 != o' "$MAP" 2>/dev/null || true; printf '%s\t%s\n' "$1" "$2"; } > "$MAP.tmp"
    mv "$MAP.tmp" "$MAP"
}

map_put_all() {
    local o
    mkdir -p "$(dirname "$MAP")"
    : > "$MAP.tmp"
    for o in $(outputs); do
        printf '%s\t%s\n' "$o" "$1" >> "$MAP.tmp"
    done
    mv "$MAP.tmp" "$MAP"
}

make_still() {
    ffmpeg -y -loglevel error -i "$1" -frames:v 1 -f image2 -c:v png "$2.tmp" && mv "$2.tmp" "$2"
}

# Animated picks wave in over their own first frame, then swap to the live
# source with no transition: the frames are identical, so the gif restart and
# the mpvpaper spawn stop reading as a flicker at the end of the wave.
apply_visual() {
    local pic="$1" out="${2:-}" show="$1" st
    local -a oflag=()
    [ -n "$out" ] && oflag=(--outputs "$out")
    case "${pic##*.}" in
        [Mm][Pp]4|[Ww][Ee][Bb][Mm]|[Mm][Kk][Vv]|[Mm][Oo][Vv]|[Gg][Ii][Ff])
            st="$STILL"
            [ -n "$out" ] && st="${STILL%.png}-$out.png"
            make_still "$pic" "$st" && show="$st"
            ;;
    esac
    awww img ${oflag[@]+"${oflag[@]}"} "$show" \
        --transition-type wave \
        --transition-angle 30 \
        --transition-wave "60,30" \
        --transition-fps 60 \
        --transition-step 90
    if [ "$show" != "$pic" ] && ! is_video "$pic"; then
        sleep 0.9
        awww img ${oflag[@]+"${oflag[@]}"} "$pic" --transition-type none
    fi
}

# The desired video set comes from the map, collapsed to one '*' instance when
# every output plays the same file so a shared video decodes once. The running
# instances are compared first and the kill/respawn skipped on a match, so
# changing one monitor's still never restarts the other monitor's video.
sync_videos() {
    local desired="" actual="" o pic outs n_out n_vid
    outs=$(outputs)
    for o in $outs; do
        pic=$(map_get "$o")
        [ -n "$pic" ] && [ -f "$pic" ] && is_video "$pic" || continue
        desired+="$o"$'\t'"$pic"$'\n'
    done
    n_out=$(printf '%s\n' "$outs" | sed '/^$/d' | wc -l)
    n_vid=$(printf '%s' "$desired" | sed '/^$/d' | wc -l)
    if [ "$n_vid" -gt 0 ] && [ "$n_vid" = "$n_out" ] && [ "$(printf '%s' "$desired" | cut -f2 | sort -u | wc -l)" = 1 ]; then
        desired="*"$'\t'"$(printf '%s' "$desired" | head -n1 | cut -f2)"$'\n'
    fi
    desired=$(printf '%s' "$desired" | sort)
    actual=$(pgrep -ax mpvpaper 2>/dev/null | awk '{ print $(NF-1) "\t" $NF }' | sort || true)
    [ "$desired" = "$actual" ] && return 0
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        pkill -x mpvpaper 2>/dev/null || true
        for _ in $(seq 1 10); do
            pgrep -x mpvpaper >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi
    [ -n "$desired" ] || return 0
    sleep 0.8
    while IFS=$'\t' read -r o pic; do
        [ -n "$o" ] || continue
        setsid -f mpvpaper -p -o "no-audio loop-file=inf hwdec=auto panscan=1.0" "$o" "$pic" >/dev/null 2>&1
    done <<< "$desired"
}

# The palette follows the focused monitor: whatever hangs there drives matugen,
# the global state file and the global still, so the Settings dynamic re-run
# and the strip's current marker stay coherent with what the user looks at.
palette_update() {
    local pmode focused pic show mh md
    focused=$(focused_output)
    pic=""
    [ -n "$focused" ] && pic=$(map_get "$focused")
    [ -n "$pic" ] || pic=$(cat "$STATE" 2>/dev/null || true)
    [ -n "$pic" ] && [ -f "$pic" ] || return 0
    show="$pic"
    if is_video "$pic"; then
        make_still "$pic" "$STILL" && show="$STILL" || return 0
    fi
    mkdir -p "$(dirname "$STATE")"
    printf '%s\n' "$pic" > "$STATE"
    pmode=$(jq -r '.paletteMode // "static"' "$flags_file" 2>/dev/null || echo static)
    if [ "$pmode" = "manual" ]; then
        mh=$(jq -r '.manualHue // 30' "$flags_file" 2>/dev/null || echo 30)
        md=$(jq -r 'if .manualDark == false then "light" else "dark" end' "$flags_file" 2>/dev/null || echo dark)
        python3 "$(dirname "$0")/wallcolors.py" --hue "$mh" "$md" >/dev/null 2>&1 || true
    else
        python3 "$(dirname "$0")/wallcolors.py" "$show" >/dev/null 2>&1 || true
    fi
    hyprctl reload >/dev/null 2>&1 || true
    busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions \
        Activate "sava{sv}" reload-config 0 0 >/dev/null 2>&1 || true
}

map_has_video() {
    local o pic
    for o in $(outputs); do
        pic=$(map_get "$o")
        if [ -n "$pic" ] && [ -f "$pic" ] && is_video "$pic"; then
            return 0
        fi
    done
    return 1
}

restore_all() {
    local o pic any=false
    for o in $(outputs); do
        pic=$(map_get "$o")
        [ -n "$pic" ] && [ -f "$pic" ] || pic=$(cat "$STATE" 2>/dev/null || true)
        [ -n "$pic" ] && [ -f "$pic" ] || pic=$(pop_bag) || continue
        map_put "$o" "$pic"
        apply_visual "$pic" "$o"
        any=true
    done
    [ "$any" = true ] || exit 0
    sync_videos
    palette_update
    exit 0
}

daemon_was_running=true
awww query >/dev/null 2>&1 || daemon_was_running=false
ensure_daemon || exit 0

cmd="${1:-}"
target=""

if [ "$cmd" = "init" ]; then
    if [ ! -s "$MAP" ] && [ -s "$STATE" ]; then
        pic=$(cat "$STATE")
        [ -f "$pic" ] && map_put_all "$pic"
    fi
    if [ "$daemon_was_running" = true ]; then
        if map_has_video && ! pgrep -x mpvpaper >/dev/null 2>&1; then
            sync_videos
        fi
        exit 0
    fi
    restore_all
elif [ "$cmd" = "set" ]; then
    pic="${2:-}"
    [ -f "$pic" ] || exit 1
    target="${3:-}"
    [ "$target" = "all" ] && target=""
else
    scope=$(jq -r '.randomScope // "all"' "$flags_file" 2>/dev/null || echo all)
    if [ "$scope" = "cursor" ]; then
        target=$(cursor_output)
    fi
    pic=$(pop_bag) || exit 0
fi

[ -n "$pic" ] || exit 0

if [ -n "$target" ]; then
    map_put "$target" "$pic"
else
    map_put_all "$pic"
fi

apply_visual "$pic" "$target"
sync_videos
palette_update
