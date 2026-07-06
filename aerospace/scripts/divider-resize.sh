#!/usr/bin/env bash
# divider-resize.sh <left|right|down|up> <amount>
# Moves the divider next to the focused window in a fixed screen direction,
# like yabai edge-resize: probe for a neighbor (invisible focus round-trip)
# and flip the resize sign on the last window. Same logic as the fallback
# bindings in aerospace.toml; skhd calls this so holding the key repeats.
set -euo pipefail

# skhd's launchd environment has no homebrew in PATH.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
AEROSPACE="${AEROSPACE:-aerospace}"

dir="${1:-}"
amount="${2:-20}"

case "$dir" in
	left)  probe=right back=left  hit="resize width -$amount"  miss="resize width +$amount" ;;
	right) probe=right back=left  hit="resize width +$amount"  miss="resize width -$amount" ;;
	down)  probe=down  back=up    hit="resize height +$amount" miss="resize height -$amount" ;;
	up)    probe=down  back=up    hit="resize height -$amount" miss="resize height +$amount" ;;
	*)
		echo "usage: $0 {left|right|down|up} [amount]" >&2
		exit 2
		;;
esac

exec "$AEROSPACE" eval "focus $probe --boundaries-action fail --ignore-floating && focus $back --ignore-floating && $hit || $miss"
