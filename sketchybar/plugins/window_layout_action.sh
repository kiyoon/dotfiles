#!/usr/bin/env bash
# Action for window layout rows in the displays popup. Dismisses the popup,
# then runs the same script as the AeroSpace keyboard shortcut.
source "$CONFIG_DIR/colors.sh"

sketchybar --set displays popup.drawing=off

case "$1" in
	toggle-monitor-floating)
		"$HOME/.config/aerospace/scripts/window_layout.sh" toggle-monitor-floating
		;;
esac
