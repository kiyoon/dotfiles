#!/usr/bin/env bash
# Battery percentage with charge-level icon. Hides itself on desktops.

source "$CONFIG_DIR/colors.sh"

batt_info="$(pmset -g batt)"
percentage="$(grep -Eo '[0-9]+%' <<<"$batt_info" | head -1 | tr -d '%')"

if [[ -z "$percentage" ]]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

color=$LABEL_COLOR
if grep -q 'AC Power' <<<"$batt_info"; then
	icon=󰂄
	color=$GREEN
else
	case $((percentage)) in
	9[0-9] | 100) icon=󰁹 ;;
	[6-8][0-9]) icon=󰂀 ;;
	[4-5][0-9]) icon=󰁾 ;;
	[2-3][0-9]) icon=󰁼 color=$YELLOW ;;
	*) icon=󰁺 color=$RED ;;
	esac
fi

sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="${percentage}%"
