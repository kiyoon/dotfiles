#!/usr/bin/env bash
# Click on the Wi-Fi item: open the native Wi-Fi Control Center popup by
# AX-clicking the real Wi-Fi status item hosted by ControlCenter. This mirrors
# bluetooth_click.sh and falls back to Wi-Fi Settings if the native item cannot
# be found or clicked.

LOG="/tmp/sketchybar_alias_click.log"
STATE="${TMPDIR:-/tmp}/sketchybar_wifi_click_ms"
SETTINGS_URL="x-apple.systempreferences:com.apple.wifi-settings-extension"

now_ms() {
	perl -MTime::HiRes=time -e 'printf "%d\n", time() * 1000' 2>/dev/null || {
		printf '%s000\n' "$(date +%s)"
	}
}

now="$(now_ms)"
last="$(cat "$STATE" 2>/dev/null || printf 0)"
printf '%s\n' "$now" >"$STATE"
echo "=== $(date '+%F %T') wifi_click" >>"$LOG"

if (( now - last <= 700 )); then
	echo "double-click: opening Wi-Fi Settings" >>"$LOG"
	open "$SETTINGS_URL"
	exit 0
fi

if osascript >>"$LOG" 2>&1 <<'EOF'
tell application "System Events"
	tell process "ControlCenter"
		repeat with mbi in menu bar items of menu bar 1
			set d to ""
			try
				set d to (description of mbi as string)
			end try
			if d contains "Wi-Fi" or d contains "Wi‑Fi" or d contains "AirPort" then
				click mbi
				return "clicked CC Wi-Fi item: " & d
			end if
		end repeat
		error "no CC item described 'Wi-Fi'. items: " & ((description of every menu bar item of menu bar 1) as string)
	end tell
end tell
EOF
then
	exit 0
fi

open "$SETTINGS_URL"
