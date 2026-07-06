#!/usr/bin/env bash
# Memory used the way Activity Monitor's "Memory Used" counts it:
#   used = app memory (anonymous - purgeable) + wired + compressed
# (memory_pressure's "free percentage" is the pressure metric instead, which
# reads misleadingly low on big-RAM machines.)
source "$CONFIG_DIR/colors.sh"
export LC_ALL=C

ram="$(vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
	/page size of/                 { psize = $8 }
	/Pages wired down:/            { wired = $4 }
	/Pages purgeable:/             { purgeable = $3 }
	/Anonymous pages:/             { anon = $3 }
	/Pages occupied by compressor:/ { comp = $5 }
	END {
		if (!psize || !total) { print "?"; exit }
		used = (anon - purgeable + wired + comp) * psize
		printf "%.0f", used / total * 100
	}')"
[[ "$ram" =~ ^[0-9]+$ ]] || ram="?"

color=$LABEL_COLOR
if [[ "$ram" != "?" ]]; then
	((ram >= 80)) && color=$RED || { ((ram >= 60)) && color=$YELLOW; }
fi

sketchybar --set "$NAME" label="${ram}%" label.color="$color"
