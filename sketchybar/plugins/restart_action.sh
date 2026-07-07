#!/usr/bin/env bash
# Action for the restart popup menu. $1 = target: "sketchybar" | "aerospace".
# Wired ONLY to click_script, which runs on a real click -- never on
# `forced`/routine updates -- so reloading/relaunching from here is safe (see
# restart_menu.sh for why that distinction matters). Dismisses the popup first.
#
# `sketchybar --reload` rebuilds the bar in place; AeroSpace gets a full relaunch
# (`aerospace reload-config` can't revive a hung server) and its after-startup
# command re-triggers the workspace refresh.
source "$CONFIG_DIR/colors.sh"  # robust PATH (brew bin) + locale, per repo convention
sketchybar --set restart popup.drawing=off

case "$1" in
	sketchybar)
		sketchybar --reload
		;;
	aerospace)
		killall AeroSpace 2>/dev/null
		open -a AeroSpace
		;;
esac
