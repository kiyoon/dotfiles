#!/usr/bin/env bash
# Atomically render the two click zones of the combined battery readout:
# current charge opens Battery Settings; the blue maximum suffix cycles limits.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(dirname "$SCRIPT_DIR")}"
# shellcheck source=colors.sh
source "$CONFIG_DIR/colors.sh"

HELPER="${BATTERY_LIMIT_HELPER:-$CONFIG_DIR/helpers/battery_charge_limit}"
PMSET_BIN="${BATTERY_PMSET_BIN:-/usr/bin/pmset}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
BATTERY_ITEM="${BATTERY_ITEM_NAME:-battery}"
LIMIT_ITEM="${BATTERY_LIMIT_ITEM_NAME:-battery_limit}"

batt_info="$("$PMSET_BIN" -g batt 2>/dev/null)"
percentage="$(grep -Eo '[0-9]+%' <<<"$batt_info" | head -1 | tr -d '%')"

if [[ -z "$percentage" ]]; then
	"$SKETCHYBAR" \
		--set "$BATTERY_ITEM" drawing=off \
		--set "$LIMIT_ITEM" drawing=off icon.drawing=off
	exit 0
fi

icon_color=$LABEL_COLOR
if grep -q 'AC Power' <<<"$batt_info"; then
	icon=󰂄
	icon_color=$GREEN
else
	case $((percentage)) in
	9[0-9] | 100) icon=󰁹 ;;
	[6-8][0-9]) icon=󰂀 ;;
	[4-5][0-9]) icon=󰁾 ;;
	[2-3][0-9]) icon=󰁼 icon_color=$YELLOW ;;
	*) icon=󰁺 icon_color=$RED ;;
	esac
fi

limit_available=0
limit_label=""
limit_color=$ACCENT_COLOR
if status="$("$HELPER" status 2>/dev/null)"; then
	read -r limit_field manual_field optimized_field <<<"$status"
	limit="${limit_field#limit=}"
	manual_state="${manual_field#mcl=}"
	optimized_state="${optimized_field#optimized=}"

	case "$limit" in
	80 | 85 | 90 | 95 | 100)
		limit_available=1
		limit_label="≤${limit}%"
		if [[ "$optimized_state" != 1 || ( "$limit" != 100 && "$manual_state" != 1 ) ]]; then
			# Do not present a configured-but-inactive policy as protected.
			limit_color=$RED
			limit_label="!${limit}%"
		fi
		;;
	esac
fi

if [[ "$limit_available" -eq 1 ]]; then
	# The suffix carries the shared percent unit: 74 + ≤80% -> 74≤80%.
	"$SKETCHYBAR" \
		--set "$BATTERY_ITEM" \
			drawing=on icon="$icon" icon.color="$icon_color" \
			label="$percentage" label.color="$LABEL_COLOR" \
		--set "$LIMIT_ITEM" \
			drawing=on icon.drawing=off \
			label="$limit_label" label.color="$limit_color"
else
	# If PowerUI is unsupported or temporarily unavailable, retain an ordinary,
	# self-contained battery percentage rather than leaving a unitless number.
	"$SKETCHYBAR" \
		--set "$BATTERY_ITEM" \
			drawing=on icon="$icon" icon.color="$icon_color" \
			label="${percentage}%" label.color="$LABEL_COLOR" \
		--set "$LIMIT_ITEM" drawing=off icon.drawing=off
fi
