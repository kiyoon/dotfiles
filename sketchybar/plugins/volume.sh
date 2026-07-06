#!/usr/bin/env bash
# Output volume with level icon.

source "$CONFIG_DIR/colors.sh"

if [[ "$SENDER" == "volume_change" ]]; then
	volume="$INFO"
else
	# Initial fill; plain osascript volume query needs no permissions.
	volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi

[[ -z "$volume" ]] && exit 0

muted="$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)"
if [[ "$muted" == "true" ]]; then
	sketchybar --set "$NAME" icon=󰝟 icon.color="$MUTED_COLOR" label="${volume}%"
	exit 0
fi

case $((volume)) in
0) icon=󰝟 ;;
[1-3][0-9] | [1-9]) icon=󰕿 ;;
[4-6][0-9]) icon=󰖀 ;;
*) icon=󰕾 ;;
esac

sketchybar --set "$NAME" icon="$icon" icon.color="$LABEL_COLOR" label="${volume}%"
