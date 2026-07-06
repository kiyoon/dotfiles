#!/usr/bin/env bash
# CPU usage in percent. `top` needs two samples for a real reading (the first
# is cumulative-since-boot), so this blocks ~1s; sketchybar runs it async.
source "$CONFIG_DIR/colors.sh"
# Parse with C locale so decimal points never follow the system language.
export LC_ALL=C

cpu="$(top -l 2 -n 0 -s 1 | awk '
	/^CPU usage/ { gsub("%", "", $7); idle = $7 }
	END { if (idle == "") print "?"; else printf "%.0f", 100 - idle }')"

color=$LABEL_COLOR
if [[ "$cpu" != "?" ]]; then
	((cpu >= 80)) && color=$RED || { ((cpu >= 60)) && color=$YELLOW; }
fi

sketchybar --set "$NAME" label="${cpu}%" label.color="$color"
