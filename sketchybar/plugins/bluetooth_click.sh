#!/usr/bin/env bash
# Click on the Bluetooth item: open the native Bluetooth Control Center popup by
# AX-clicking the real Bluetooth status item, which macOS hosts inside the
# ControlCenter process' menu bar (not a separate app). The item exposes no
# usable `name`/`value` -- only its AXDescription ("Bluetooth") -- so we match on
# that. Runs as a child of sketchybar, so sketchybar itself needs Accessibility
# permission (System Settings -> Privacy & Security -> Accessibility); the System
# Events automation consent is prompted once on first use. If the popup can't be
# opened we fall back to Bluetooth Settings. Every attempt is logged.
#
# NOTE: match `description` via a plain string variable, never by iterating a
# collected list with `repeat with x in list` -- that binds `x` to a reference
# and `x is "Bluetooth"` silently compares the reference, never the value.

LOG="/tmp/sketchybar_alias_click.log"
echo "=== $(date '+%F %T') bluetooth_click" >>"$LOG"

if osascript >>"$LOG" 2>&1 <<'EOF'
tell application "System Events"
	tell process "ControlCenter"
		repeat with mbi in menu bar items of menu bar 1
			set d to ""
			try
				set d to (description of mbi as string)
			end try
			if d starts with "Bluetooth" then
				click mbi
				return "clicked CC Bluetooth item: " & d
			end if
		end repeat
		error "no CC item described 'Bluetooth'. items: " & ((description of every menu bar item of menu bar 1) as string)
	end tell
end tell
EOF
then
	exit 0
fi

open "x-apple.systempreferences:com.apple.BluetoothSettings"
