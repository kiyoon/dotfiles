#!/usr/bin/env bash
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"
HIST_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace-monitor-history"

focused_monitor() {
	"$AEROSPACE" list-monitors --focused --format '%{monitor-id}'
}

monitor_count() {
	"$AEROSPACE" list-monitors | wc -l | tr -d ' '
}

# Called on every workspace change: remember the previously focused monitor so
# move-recent can bounce between the two last-used monitors (yabai's
# `window --display recent`).
track() {
	cur="$(focused_monitor)"
	last=""
	if [[ -f "$HIST_FILE" ]]; then
		last="$(awk '{print $2}' "$HIST_FILE")"
	fi
	if [[ "$cur" != "$last" ]]; then
		printf '%s %s\n' "${last:-$cur}" "$cur" >"$HIST_FILE"
	fi
}

# yabai: window --display recent (two-way bounce, regardless of monitor count).
move_recent() {
	(($(monitor_count) > 1)) || exit 0
	prev=""
	if [[ -f "$HIST_FILE" ]]; then
		prev="$(awk '{print $1}' "$HIST_FILE")"
	fi
	cur="$(focused_monitor)"
	if [[ -n "$prev" && "$prev" != "$cur" ]]; then
		"$AEROSPACE" move-node-to-monitor --focus-follows-window "$prev" 2>/dev/null && return
	fi
	"$AEROSPACE" move-node-to-monitor --focus-follows-window --wrap-around next
}

# yabai pair toggles: send the window to the target monitor; if it is already
# there, send it to the laptop display instead. Mapping from the old skhd
# setup (yabai displays: 1 laptop, 2 left external, 3 main external):
#   move-main-toggle      -> aerospace 'main'      (yabai 3 <-> 1)
#   move-secondary-toggle -> aerospace 'secondary' (yabai 2 <-> 1)
move_toggle() {
	target="$1"
	(($(monitor_count) > 1)) || exit 0
	if ! "$AEROSPACE" move-node-to-monitor --fail-if-noop --focus-follows-window "$target" 2>/dev/null; then
		"$AEROSPACE" move-node-to-monitor --fail-if-noop --focus-follows-window 'built-in' 2>/dev/null || true
	fi
}

case "${1:-}" in
track) track ;;
move-recent) move_recent ;;
move-main-toggle) move_toggle main ;;
move-secondary-toggle) move_toggle secondary ;;
*)
	echo "usage: $0 {track|move-recent|move-main-toggle|move-secondary-toggle}" >&2
	exit 1
	;;
esac
