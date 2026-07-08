#!/usr/bin/env bash
# Toggle one top-level popup while closing the others.

source "$CONFIG_DIR/colors.sh"

target="${1:-}"
[[ -n "$target" ]] || exit 0

state_file="${TMPDIR:-/tmp}/sketchybar_open_menu"
was_open="off"
if [[ -f "$state_file" && "$(cat "$state_file" 2>/dev/null)" == "$target" ]]; then
	was_open="on"
fi

sketchybar --set restart popup.drawing=off \
	--set prompts popup.drawing=off \
	--set displays popup.drawing=off
sketchybar --set '/^restart\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR" \
	--set '/^prompt\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR" \
	--set '/^display\..*/' background.drawing=off icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"

if [[ "$was_open" != "on" ]]; then
	sketchybar --set "$target" popup.drawing=on
	printf '%s\n' "$target" >"$state_file"
else
	rm -f "$state_file"
fi
