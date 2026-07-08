#!/usr/bin/env bash
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"

toggle_monitor_floating() {
	focused="$("$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
	rows="$("$AEROSPACE" list-windows --monitor focused --format '%{window-id}|%{window-layout}' 2>/dev/null || true)"
	[[ -n "$rows" ]] || exit 0

	target=floating
	seen_managed=0
	all_floating=1
	while IFS='|' read -r id layout; do
		[[ -n "$id" ]] || continue
		[[ "$layout" == macos_native_* ]] && continue
		seen_managed=1
		[[ "$layout" == floating ]] || all_floating=0
	done <<<"$rows"

	if ((seen_managed)) && ((all_floating)); then
		target=tiling
	fi

	while IFS='|' read -r id _layout; do
		[[ -n "$id" ]] || continue
		"$AEROSPACE" layout --window-id "$id" "$target" 2>/dev/null || true
	done <<<"$rows"

	if [[ -n "$focused" ]]; then
		"$AEROSPACE" focus --window-id "$focused" 2>/dev/null || true
	fi
}

case "${1:-}" in
toggle-monitor-floating) toggle_monitor_floating ;;
float-monitor) toggle_monitor_floating ;;
*)
	echo "usage: $0 {toggle-monitor-floating}" >&2
	exit 1
	;;
esac
