#!/usr/bin/env bash
# Wi-Fi status. Recent macOS redacts the SSID from CLI tools unless the caller
# has Location Services permission, so when the name is unavailable fall back
# to an icon-only "connected" state (detected via the interface's IP).

source "$CONFIG_DIR/colors.sh"

# Find the Wi-Fi device (usually en0).
dev="$(networksetup -listallhardwareports 2>/dev/null |
	awk '/Wi-Fi|AirPort/{getline; print $2; exit}')"

if [[ -z "$dev" ]]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

ssid="$(ipconfig getsummary "$dev" 2>/dev/null |
	awk -F ' SSID : ' '/ SSID : / {print $2; exit}')"
if [[ -z "$ssid" ]]; then
	ssid="$(networksetup -getairportnetwork "$dev" 2>/dev/null |
		sed -n 's/^Current Wi-Fi Network: //p')"
fi
[[ "$ssid" == "<redacted>" ]] && ssid=""

if [[ -n "$ssid" ]]; then
	sketchybar --set "$NAME" drawing=on icon=󰤨 icon.color="$ACCENT_COLOR" \
		label.drawing=on label="$ssid"
elif [[ -n "$(ipconfig getifaddr "$dev" 2>/dev/null)" ]]; then
	# Connected, but macOS hides the network name: show the icon alone.
	sketchybar --set "$NAME" drawing=on icon=󰤨 icon.color="$ACCENT_COLOR" \
		label.drawing=off
else
	sketchybar --set "$NAME" drawing=on icon=󰤭 icon.color="$MUTED_COLOR" \
		label.drawing=off
fi
