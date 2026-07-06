#!/usr/bin/env bash
# Date + time, e.g. "Mon 06 Jul 11:42".

source "$CONFIG_DIR/colors.sh"

sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')"
