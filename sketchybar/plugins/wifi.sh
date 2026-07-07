#!/usr/bin/env bash
# Wi-Fi status. Recent macOS (Sonoma+) redacts the SSID from every unprivileged
# tool -- ipconfig, networksetup, system_profiler, even `sudo wdutil` -- unless
# the caller holds Location Services permission. The only reliable reader is a
# Location-authorized .app; we use noperator/wifi-unredactor:
#   git clone https://github.com/noperator/wifi-unredactor
#   cd wifi-unredactor && ./build-and-install.sh   # installs to ~/Applications
#   open ~/Applications/wifi-unredactor.app        # click Allow, then enable it
#                                                  # under Location Services
# It prints {"ssid":...,"bssid":...}. If it is missing or unauthorized we fall
# back to an icon-only "connected" state.
#
# Launching a GUI app on every routine 30s poll would be wasteful, so we only
# query it on real Wi-Fi changes (wifi_change / system_woke) or a cold cache,
# and reuse the cached name on routine polls.

source "$CONFIG_DIR/colors.sh"

UNREDACTOR="$HOME/Applications/wifi-unredactor.app/Contents/MacOS/wifi-unredactor"
CACHE="$HOME/.cache/sketchybar_wifi_ssid"

# Find the Wi-Fi device (usually en0).
dev="$(networksetup -listallhardwareports 2>/dev/null |
	awk '/Wi-Fi|AirPort/{getline; print $2; exit}')"

if [[ -z "$dev" ]]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

# Disconnected -> muted icon, and drop any stale cached name.
if [[ -z "$(ipconfig getifaddr "$dev" 2>/dev/null)" ]]; then
	rm -f "$CACHE"
	sketchybar --set "$NAME" drawing=on icon=󰤭 icon.color="$MUTED_COLOR" label.drawing=off
	exit 0
fi

# Connected. Refresh the (Location-gated) name only when it can have changed:
# a wifi_change/system_woke/forced event, or a cold cache. Routine polls reuse it.
ssid="$(cat "$CACHE" 2>/dev/null)"
if [[ "$SENDER" != "routine" || -z "$ssid" ]]; then
	if [[ -x "$UNREDACTOR" ]]; then
		ssid="$("$UNREDACTOR" 2>/dev/null | sed -n 's/.*"ssid" : "\([^"]*\)".*/\1/p')"
		[[ "$ssid" == "failed to retrieve SSID" ]] && ssid=""
		mkdir -p "$(dirname "$CACHE")"
		printf '%s' "$ssid" > "$CACHE"
	fi
fi

if [[ -n "$ssid" ]]; then
	sketchybar --set "$NAME" drawing=on icon=󰤨 icon.color="$ACCENT_COLOR" \
		label.drawing=on label="$ssid"
else
	# Connected but the name is unavailable (app missing or not yet authorized).
	sketchybar --set "$NAME" drawing=on icon=󰤨 icon.color="$ACCENT_COLOR" \
		label.drawing=off
fi
