#!/usr/bin/env bash
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"

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

move_window_to_new_workspace() {
	target="$(next_unused_workspace)"
	"$AEROSPACE" move-node-to-workspace --focus-follows-window "$target"
}

open_terminal_in_new_workspace() {
	target="$(next_unused_workspace)"
	"$AEROSPACE" workspace "$target"
	open -n -a "WezTerm"
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
