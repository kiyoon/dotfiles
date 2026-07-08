#!/usr/bin/env bash
# Hover highlight shared by popup menu rows. Wired as each row's `script`,
# subscribed to mouse.entered / mouse.exited ONLY.
#
# IMPORTANT: never perform an action here. `script` also fires on `forced`/routine
# updates (every bar load), so a reload/relaunch reachable from here loops
# forever. Row actions live in each menu's *_action.sh (wired to click_script).
source "$CONFIG_DIR/colors.sh"

case "$SENDER" in
	mouse.entered)
		case "$NAME" in
			restart.*) group='/^restart\..*/' ;;
			prompt.*) group='/^prompt\..*/' ;;
			display.*) group='/^display\..*/' ;;
			*) group="" ;;
		esac
		if [[ -n "$group" ]]; then
			sketchybar --set "$group" background.drawing=off \
				icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"
		fi
		sketchybar --set "$NAME" background.drawing=on background.color="$ACCENT_COLOR" \
			icon.color="$BG_DARK" label.color="$BG_DARK"
		;;
	mouse.exited)
		sketchybar --set "$NAME" background.drawing=off \
			icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"
		;;
esac
