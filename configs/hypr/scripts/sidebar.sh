#!/bin/sh
mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
qs -c sidebar ipc call sidebar toggle "$mon"
