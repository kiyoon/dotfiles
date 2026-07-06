#!/usr/bin/env bash
# Toggle Amphetamine's keep-awake session on click. Amphetamine is sandboxed
# and refuses outside AX attachment (so alias_click.sh cannot open its real
# menu like the other aliases); its AppleScript dictionary is the reliable
# hook instead. Needs the Automation consent (sketchybar -> Amphetamine),
# prompted once on first use.

osascript >>/tmp/sketchybar_alias_click.log 2>&1 <<'EOF'
tell application "Amphetamine"
	if (session is active) then
		end session
	else
		start new session
	end if
end tell
EOF
