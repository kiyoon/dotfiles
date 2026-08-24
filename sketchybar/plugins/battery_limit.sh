#!/usr/bin/env bash
# Render macOS's configured native battery charge limit. The battery fill is a
# coarse visual cue; the label keeps intermediate 85/95 percent values exact.

# shellcheck source=colors.sh
source "$CONFIG_DIR/colors.sh"

HELPER="${BATTERY_LIMIT_HELPER:-$CONFIG_DIR/helpers/battery_charge_limit}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"

status="$("$HELPER" status 2>/dev/null)" || {
	"$SKETCHYBAR" --set "$NAME" drawing=off
	exit 0
}

read -r limit_field manual_field optimized_field <<<"$status"
limit="${limit_field#limit=}"
manual_state="${manual_field#mcl=}"
optimized_state="${optimized_field#optimized=}"

case "$limit" in
80) icon=󰂁 ;;
85) icon=󰂁⁺ ;;
90) icon=󰂂 ;;
95) icon=󰂂⁺ ;;
100) icon=󰁹 ;;
*)
	"$SKETCHYBAR" --set "$NAME" drawing=off
	exit 0
	;;
esac

color=$ACCENT_COLOR
label="≤${limit}%"
if [[ "$optimized_state" != 1 || ( "$limit" != 100 && "$manual_state" != 1 ) ]]; then
	# Do not present a configured-but-inactive policy as protected.
	color=$RED
	label="!${limit}%"
fi

"$SKETCHYBAR" --set "$NAME" \
	drawing=on \
	icon="$icon" \
	icon.color="$color" \
	label="$label" \
	label.color="$color"
