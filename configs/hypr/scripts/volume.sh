#!/bin/sh
# Raise the default output up to its boost from the sound surface instead of a hard 100%.
f="${XDG_STATE_HOME:-$HOME/.local/state}/ricelin/sound.json"
sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/^[ *]*node\.name = "\(.*\)"$/\1/p' | head -n 1)
lim=$(jq -r --arg s "$sink" '((.devices[$s].boost // 100) / 100)' "$f" 2>/dev/null)
exec wpctl set-volume -l "${lim:-1}" @DEFAULT_AUDIO_SINK@ 5%+
