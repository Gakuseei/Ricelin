verb=$1
out=$2

old_file="${XDG_RUNTIME_DIR:-/tmp}/ricelin-display-$out.old"
pending_file="${XDG_RUNTIME_DIR:-/tmp}/ricelin-display-$out.pending"

snapshot_old() {
    spec=$(hyprctl monitors -j | jq -r --arg o "$out" '
        .[] | select(.name == $o) |
        "hl.monitor({ output = \"" + .name +
        "\", mode = \"" + (.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate*1000|round)/1000|tostring) +
        "\", position = \"" + (.x|tostring) + "x" + (.y|tostring) +
        "\", scale = " + (.scale|tostring) + " }) return \"ok\""')
    [ -n "$spec" ] || return 1
    printf '%s' "$spec" > "$old_file"
}

case "$verb" in
apply)
    mode=$3
    position=$4
    scale=$5
    if [ ! -e "$old_file" ]; then
        snapshot_old || exit 1
    fi
    token=$(date +%s%N)
    printf '%s' "$token" > "$pending_file"
    new_spec="hl.monitor({ output = \"$out\", mode = \"$mode\", position = \"$position\", scale = $scale }) return \"ok\""
    hyprctl eval "$new_spec" >/dev/null 2>&1
    setsid -f sh -c '
        pending=$1
        old=$2
        token=$3
        sleep 14
        if [ "$(cat "$pending" 2>/dev/null)" = "$token" ]; then
            hyprctl eval "$(cat "$old")" >/dev/null 2>&1
            rm -f "$pending" "$old"
        fi
    ' sh "$pending_file" "$old_file" "$token" >/dev/null 2>&1
    ;;
keep)
    rm -f "$pending_file" "$old_file"
    ;;
revert)
    if [ -e "$old_file" ]; then
        hyprctl eval "$(cat "$old_file")" >/dev/null 2>&1
    fi
    rm -f "$pending_file" "$old_file"
    ;;
*)
    exit 2
    ;;
esac
