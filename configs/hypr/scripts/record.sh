#!/bin/sh
mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
exec /usr/bin/qs -c pill ipc call pill quickRecord "$mon"
