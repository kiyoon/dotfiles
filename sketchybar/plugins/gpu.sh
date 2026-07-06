#!/usr/bin/env bash
# GPU utilization from the IOAccelerator (AGX) performance statistics.
# Works without sudo on Apple Silicon, unlike powermetrics.
source "$CONFIG_DIR/colors.sh"
export LC_ALL=C

# The whole PerformanceStatistics dict prints as one line, so cut the one
# key out first instead of field-splitting the line.
gpu="$(ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null |
	grep -o '"Device Utilization %"=[0-9]*' | head -1 | grep -o '[0-9]*$')"
[[ "$gpu" =~ ^[0-9]+$ ]] || gpu="?"

color=$LABEL_COLOR
if [[ "$gpu" != "?" ]]; then
	((gpu >= 80)) && color=$RED || { ((gpu >= 60)) && color=$YELLOW; }
fi

sketchybar --set "$NAME" label="${gpu}%" label.color="$color"
