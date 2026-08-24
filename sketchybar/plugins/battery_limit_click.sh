#!/usr/bin/env bash
# Cycle the native macOS charge limit while keeping Optimized Battery Charging
# active, including for the 100-percent target.

# shellcheck source=colors.sh
source "$CONFIG_DIR/colors.sh"

HELPER="${BATTERY_LIMIT_HELPER:-$CONFIG_DIR/helpers/battery_charge_limit}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
LOG="${BATTERY_LIMIT_LOG:-${TMPDIR:-/tmp}/sketchybar_battery_limit.log}"
ITEM="${NAME:-battery_limit}"

status="$("$HELPER" status 2>>"$LOG")" || {
	"$SKETCHYBAR" --set "$ITEM" \
		drawing=on icon.drawing=off label="Limit!" label.color="$RED"
	exit 1
}

read -r limit_field _ <<<"$status"
limit="${limit_field#limit=}"

case "$limit" in
80) next=90 ;;
85) next=90 ;;
90) next=95 ;;
95) next=100 ;;
100) next=80 ;;
*) next=80 ;;
esac

if ! "$HELPER" set "$next" >>"$LOG" 2>&1; then
	"$SKETCHYBAR" --set "$ITEM" \
		drawing=on icon.drawing=off label="Limit!" label.color="$RED"
	exit 1
fi

"$SKETCHYBAR" --trigger battery_limit_change
