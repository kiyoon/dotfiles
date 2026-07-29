#!/usr/bin/env bash
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
OPEN="${OPEN:-open}"

used_workspaces_on_focused_monitor() {
	"$AEROSPACE" list-workspaces --monitor focused --empty no
}

focus_used_workspace() {
	direction="$1"
	workspaces="$(used_workspaces_on_focused_monitor)"
	[[ -n "$workspaces" ]] || exit 0
	printf "%s\n" "$workspaces" | "$AEROSPACE" workspace --stdin --wrap-around "$direction"
}

move_window_to_used_workspace() {
	direction="$1"
	workspaces="$(used_workspaces_on_focused_monitor)"
	[[ -n "$workspaces" ]] || exit 0
	printf "%s\n" "$workspaces" | "$AEROSPACE" move-node-to-workspace --focus-follows-window --stdin --wrap-around "$direction"
	refresh_sketchybar
}

next_unused_workspace() {
	existing="$("$AEROSPACE" list-workspaces --all)"

	i=1
	while (( i <= 30 )); do
		if ! printf "%s\n" "$existing" | grep -Fxq "$i"; then
			printf "%s\n" "$i"
			return 0
		fi
		((i++))
	done

	date +%s
}

focused_window_id() {
	local window_id="${AEROSPACE_WINDOW_ID:-}"

	# Hotkey bindings normally have no forwarded window context, so capture the
	# currently focused id. Keep the env path for contextual/manual callers.
	if [[ ! "$window_id" =~ ^[0-9]+$ ]]; then
		window_id="$("$AEROSPACE" list-windows --focused --format '%{window-id}')"
	fi

	[[ "$window_id" =~ ^[0-9]+$ ]] || {
		echo "could not determine the focused window" >&2
		return 1
	}
	printf '%s\n' "$window_id"
}

refresh_sketchybar() {
	local focused="${1:-}"
	local args=(--trigger aerospace_workspace_change)

	# The AeroSpace command has returned before this event is emitted. It
	# therefore supersedes callbacks from intermediate command state and lets
	# the bar snapshot the final app -> workspace mapping.
	if [[ "$focused" =~ ^[0-9]+$ ]]; then
		args+=(FOCUSED_WORKSPACE="$focused")
	fi
	args+=(REFRESH_NOW=1)
	"$SKETCHYBAR" "${args[@]}" >/dev/null 2>&1 || true
}

move_window_to_new_workspace() {
	local window_id target
	window_id="$(focused_window_id)"
	target="$(next_unused_workspace)"

	# summon-workspace creates the target directly on the focused window's
	# monitor. Focusing the captured id first closes the async-process race;
	# && prevents a failed summon from moving the window to a default monitor.
	"$AEROSPACE" eval \
		"focus --window-id $window_id && summon-workspace -- $target && move-node-to-workspace --window-id $window_id --focus-follows-window -- $target"
	refresh_sketchybar "$target"
}

open_terminal_in_new_workspace() {
	local source_monitor target
	source_monitor="$("$AEROSPACE" list-monitors --focused --format '%{monitor-id}')"
	[[ "$source_monitor" =~ ^[0-9]+$ ]] || {
		echo "could not determine the focused monitor" >&2
		return 1
	}
	target="$(next_unused_workspace)"

	# Re-establish the originating monitor, then create/focus the empty
	# workspace there in one native operation. This never activates the new
	# workspace on macOS's main monitor and never displaces that monitor.
	"$AEROSPACE" eval \
		"focus-monitor -- $source_monitor && summon-workspace -- $target"
	refresh_sketchybar "$target"
	"$OPEN" -n -a "WezTerm"
}

case "${1:-}" in
	focus-prev-used)
		focus_used_workspace prev
		;;
	focus-next-used)
		focus_used_workspace next
		;;
	move-window-prev-used)
		move_window_to_used_workspace prev
		;;
	move-window-next-used)
		move_window_to_used_workspace next
		;;
	move-window-new)
		move_window_to_new_workspace
		;;
	open-terminal-new)
		open_terminal_in_new_workspace
		;;
	*)
		echo "usage: $0 {focus-prev-used|focus-next-used|move-window-prev-used|move-window-next-used|move-window-new|open-terminal-new}" >&2
		exit 2
		;;
esac
