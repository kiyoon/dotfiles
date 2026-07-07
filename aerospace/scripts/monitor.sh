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

# External (non built-in) monitor names sorted left->right by screen x origin.
# Names match aerospace's %{monitor-name} for externals; the built-in screen is
# excluded via CGDisplayIsBuiltin rather than by name because its NSScreen
# localizedName is locale dependent (e.g. French) while aerospace reports the
# English name.
externals_left_to_right() {
	osascript -l JavaScript -e '
		ObjC.import("AppKit"); ObjC.import("CoreGraphics");
		const screens = $.NSScreen.screens; const rows = [];
		for (let i = 0; i < screens.count; i++) {
			const s = screens.objectAtIndex(i);
			const did = ObjC.unwrap(s.deviceDescription.objectForKey("NSScreenNumber"));
			if ($.CGDisplayIsBuiltin(did)) continue;
			rows.push([s.frame.origin.x, ObjC.unwrap(s.localizedName)]);
		}
		rows.sort((a, b) => a[0] - b[0]);
		rows.map(r => r[1]).join("\n");'
}

regex_escape() {
	printf '%s' "$1" | sed -e 's/[][(){}.*+?^$|\\]/\\&/g'
}

# yabai pair toggles, arrangement based exactly like yabai display indices were
# (old setup: 1 laptop, 2 left external, 3 main external):
#   move-main-toggle      -> rightmost external (yabai 3 <-> 1)
#   move-secondary-toggle -> leftmost external  (yabai 2 <-> 1)
# From anywhere the window goes TO the target; if it is already there it goes
# back to the built-in display. AeroSpace's main/secondary patterns cannot
# express this: 'main' follows the macOS menu-bar display (the laptop here),
# and 'secondary' only matches when exactly two monitors are connected.
move_toggle() {
	role="$1"
	externals="$(externals_left_to_right)" || exit 0
	[[ -n "$externals" ]] || exit 0
	if [[ "$role" == "main" ]]; then
		target="$(printf '%s\n' "$externals" | tail -1)"
	else
		target="$(printf '%s\n' "$externals" | head -1)"
	fi
	current="$("$AEROSPACE" list-windows --focused --format '%{monitor-name}' 2>/dev/null || true)"
	[[ -n "$current" ]] || exit 0
	if [[ "$current" == "$target" ]]; then
		"$AEROSPACE" move-node-to-monitor --focus-follows-window 'built-in' 2>/dev/null || true
	else
		"$AEROSPACE" move-node-to-monitor --focus-follows-window "^$(regex_escape "$target")\$" 2>/dev/null || true
	fi
}

# Diagnostic: print the resolved toggle targets without moving anything.
targets() {
	externals="$(externals_left_to_right)"
	printf 'externals (left->right):\n%s\n' "${externals:-<none>}"
	printf 'move-main-toggle target: %s\n' "$(printf '%s\n' "$externals" | tail -1)"
	printf 'move-secondary-toggle target: %s\n' "$(printf '%s\n' "$externals" | head -1)"
	printf 'focused window monitor: %s\n' "$("$AEROSPACE" list-windows --focused --format '%{monitor-name}' 2>/dev/null || echo '<none>')"
}

case "${1:-}" in
track) track ;;
move-recent) move_recent ;;
move-main-toggle) move_toggle main ;;
move-secondary-toggle) move_toggle secondary ;;
targets) targets ;;
*)
	echo "usage: $0 {track|move-recent|move-main-toggle|move-secondary-toggle|targets}" >&2
	exit 1
	;;
esac
