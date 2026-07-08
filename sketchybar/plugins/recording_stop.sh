#!/usr/bin/env bash
# Built-in macOS screen recording indicator. The Shift-Cmd-5 recorder is backed
# by screencapture while actively recording; hide the item otherwise.

source "$CONFIG_DIR/colors.sh"

if pgrep -x screencapture >/dev/null; then
	sketchybar --set "$NAME" drawing=on icon.color="$RED" label.drawing=off
else
	sketchybar --set "$NAME" drawing=off
fi
