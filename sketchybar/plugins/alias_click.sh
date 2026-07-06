#!/usr/bin/env bash
# Click handler for the menu bar aliases: pops the aliased item's real
# dropdown by AX-clicking the true status item. Runs as a child of
# sketchybar, so sketchybar itself needs Accessibility permission
# (System Settings -> Privacy & Security -> Accessibility); the System
# Events automation consent is prompted on first use.
# Every attempt is logged so failed lookups can be diagnosed.
#
# $1: process name owning the status item (as System Events sees it)
# $2: fallback substring matched against Control Center's menu bar items,
#     for status items hosted by Control Center instead of the app process.

LOG="/tmp/sketchybar_alias_click.log"
proc="$1"
match="$2"

echo "=== $(date '+%F %T') proc=$proc match=$match" >>"$LOG"
osascript >>"$LOG" 2>&1 <<EOF
tell application "System Events"
	-- Normal case: a third-party status item is "menu bar 2" of its app.
	try
		tell process "$proc"
			click menu bar item 1 of menu bar 2
		end tell
		return "clicked: menu bar 2 of $proc"
	on error errApp
	end try

	-- Fallback: status items hosted by Control Center.
	try
		tell process "ControlCenter"
			repeat with mbi in menu bar items of menu bar 1
				set d to ""
				try
					set d to (name of mbi as string)
				end try
				try
					set d to d & " " & (description of mbi as string)
				end try
				if d contains "$match" then
					click mbi
					return "clicked CC item: " & d
				end if
			end repeat
			return "no CC match for '$match'. app err: " & errApp & ". CC items: " & ((name of every menu bar item of menu bar 1) as string)
		end tell
	on error errCC
		return "failed. app err: " & errApp & ". CC err: " & errCC
	end try
end tell
EOF
