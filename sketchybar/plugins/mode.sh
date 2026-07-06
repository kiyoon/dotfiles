#!/usr/bin/env bash
# AeroSpace binding-mode badge. Hidden in the default main mode.
# MODE comes from the aerospace_mode_change trigger (fired by the mode-switch
# keybindings in aerospace.toml); on forced/startup query aerospace directly.

source "$CONFIG_DIR/colors.sh"

mode="${MODE:-}"
if [[ -z "$mode" ]] && command -v aerospace >/dev/null 2>&1; then
	mode="$(aerospace list-modes --current 2>/dev/null)"
fi

case "$mode" in
passthrough)
	sketchybar --set "$NAME" drawing=on label="PASSTHROUGH" \
		background.color="$RED" label.color="$BG_DARK"
	;;
resize)
	sketchybar --set "$NAME" drawing=on label="RESIZE" \
		background.color="$YELLOW" label.color="$BG_DARK"
	;;
*)
	sketchybar --set "$NAME" drawing=off
	;;
esac
