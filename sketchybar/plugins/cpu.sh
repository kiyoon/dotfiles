#!/usr/bin/env bash
# CPU usage as a normalized process sum. This matches tmux-style readings more
# closely than `top` on this setup, and avoids a slow two-sample `top` run.
source "$CONFIG_DIR/colors.sh"
export LC_ALL=C

cores="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 1)"
cpu="$(ps -A -o %cpu= 2>/dev/null | awk -v cores="$cores" '
	{ sum += $1 }
	END {
		if (!cores) { print "?"; exit }
		usage = sum / cores
		if (usage > 100) usage = 100
		printf "%.0f", usage
	}')"

color=$LABEL_COLOR
if [[ "$cpu" != "?" ]]; then
	((cpu >= 80)) && color=$RED || { ((cpu >= 60)) && color=$YELLOW; }
fi

sketchybar --set "$NAME" label="${cpu}%" label.color="$color"
