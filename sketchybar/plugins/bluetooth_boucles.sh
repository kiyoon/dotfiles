#!/usr/bin/env bash
# Bluetooth status for the paired "Boucles soniques" device.

source "$CONFIG_DIR/colors.sh"

DEVICE_NAME="${BOUCLES_DEVICE_NAME:-Boucles soniques}"

profile="$(system_profiler -json SPBluetoothDataType 2>/dev/null)"
if [[ -z "$profile" ]]; then
	sketchybar --set "$NAME" icon=󰂲 icon.color="$MUTED_COLOR" label.drawing=off
	exit 0
fi

state="$(printf '%s' "$profile" |
	plutil -extract SPBluetoothDataType.0.controller_properties.controller_state raw -o - - 2>/dev/null)"

if [[ "$state" != "attrib_on" ]]; then
	sketchybar --set "$NAME" icon=󰂲 icon.color="$MUTED_COLOR" label.drawing=on label="off"
	exit 0
fi

connected="$(printf '%s' "$profile" |
	plutil -extract SPBluetoothDataType.0.device_connected json -o - - 2>/dev/null)"

if printf '%s' "$connected" | grep -Fq "\"$DEVICE_NAME\""; then
	sketchybar --set "$NAME" icon=󰂱 icon.color="$ACCENT_COLOR" label.drawing=on label=󰋋
else
	sketchybar --set "$NAME" icon=󰂯 icon.color="$MUTED_COLOR" label.drawing=off
fi
