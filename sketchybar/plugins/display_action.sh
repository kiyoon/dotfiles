#!/usr/bin/env bash
# Action for the displays popup menu. $1 = target external: "left" | "right".
# Dismisses the popup, then runs the SAME AeroSpace toggle the keyboard shortcut
# runs -- these mirror the existing bindings, no new keys:
#   left  = ⌥⇧A = scripts/monitor.sh move-secondary-toggle (leftmost external)
#   right = ⌥⇧T = scripts/monitor.sh move-main-toggle      (rightmost external)
# Each moves the focused window to that external display, or back to the built-in
# display if it is already there. Wired ONLY to click_script (real clicks).
source "$CONFIG_DIR/colors.sh"  # robust PATH so `aerospace` resolves

sketchybar --set displays popup.drawing=off
case "$1" in
	left)  "$HOME/.config/aerospace/scripts/monitor.sh" move-secondary-toggle ;;
	right) "$HOME/.config/aerospace/scripts/monitor.sh" move-main-toggle ;;
esac
