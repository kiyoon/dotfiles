#!/usr/bin/env bash
# Close a top-level popup and clear stale row hover state.

source "$CONFIG_DIR/colors.sh"

target="${1:-}"
state_file="${TMPDIR:-/tmp}/sketchybar_open_menu"

case "$target" in
	restart | prompts | displays)
		sketchybar --set "$target" popup.drawing=off
		if [[ -f "$state_file" && "$(cat "$state_file" 2>/dev/null)" == "$target" ]]; then
			rm -f "$state_file"
		fi
		;;
	all | "")
		sketchybar --set restart popup.drawing=off \
			--set prompts popup.drawing=off \
			--set displays popup.drawing=off
		rm -f "$state_file"
		;;
esac

sketchybar --set '/^restart\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR" \
	--set '/^prompt\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR" \
	--set '/^display\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"
