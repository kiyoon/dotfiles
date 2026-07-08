#!/usr/bin/env bash
# Stop a built-in macOS screen recording. Prefer an explicit native Control
# Center stop button; fall back to interrupting screencapture if present.

LOG="/tmp/sketchybar_recording_stop.log"

echo "=== $(date '+%F %T') stop recording" >>"$LOG"

if osascript >>"$LOG" 2>&1 <<'EOF'
tell application "System Events"
	tell process "ControlCenter"
		repeat with mbi in menu bar items of menu bar 1
			set d to ""
			try
				set d to (description of mbi as string)
			end try
			if d starts with "Stop" or d starts with "Arrêter" then
				click mbi
				return "clicked native recording stop item: " & d
			end if
		end repeat
		error "no explicit recording stop item. descriptions: " & ((description of every menu bar item of menu bar 1) as string)
	end tell
end tell
EOF
then
	echo "native stop click succeeded" >>"$LOG"
	sketchybar --trigger recording_check
	exit 0
fi

echo "native stop click unavailable; trying screencapture fallback" >>"$LOG"
if pgrep -x screencapture >/dev/null; then
	pkill -INT -x screencapture >>"$LOG" 2>&1
	sleep 0.5
	pgrep -x screencapture >/dev/null && pkill -TERM -x screencapture >>"$LOG" 2>&1
else
	echo "no screencapture process to stop" >>"$LOG"
fi

sketchybar --trigger recording_check
