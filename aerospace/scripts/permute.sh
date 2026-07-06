#!/usr/bin/env bash
# yabai-style rotate/mirror for AeroSpace: windows keep the existing frame
# slots, only which window occupies which slot changes (the same idea as
# yabai/scripts/rotate_without_changing_layout.sh).
#
# usage: permute.sh (rotate-cw|rotate-ccw|mirror-y|mirror-x)
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"
CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/permute_core.js"

op="${1:-}"
case "$op" in
	rotate-cw | rotate-ccw | mirror-y | mirror-x) ;;
	*)
		echo "usage: $0 (rotate-cw|rotate-ccw|mirror-y|mirror-x)" >&2
		exit 2
		;;
esac

# Only windows in the tiling tree participate; floating/hidden/minimized
# windows keep their place and are never swapped.
tiled_ids=()
while IFS='|' read -r id layout; do
	case "$layout" in
	*_tiles | *_accordion) tiled_ids+=("$id") ;;
	esac
done < <("$AEROSPACE" list-windows --workspace focused --format '%{window-id}|%{window-layout}')

n="${#tiled_ids[@]}"
(( n >= 2 )) || exit 0

orig_focus="$("$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null || true)"

restore_focus() {
	if [[ -n "$orig_focus" ]]; then
		"$AEROSPACE" focus --window-id "$orig_focus" >/dev/null 2>&1 || true
	fi
}

windows_json="$(jq -cn '[$ARGS.positional[] | {id: tonumber}]' --args "${tiled_ids[@]}")"
plan_json="$(osascript "$CORE" plan "$op" "$windows_json")"

# Identity (e.g. mirror-x on a flat row) or unreadable frames: do nothing.
if jq -e '(.identity == true) or has("error")' <<<"$plan_json" >/dev/null; then
	exit 0
fi

if (( n == 2 )); then
	# Any non-identity permutation of two windows is the single swap; no tree
	# order discovery (and no focus flicker) needed.
	"$AEROSPACE" swap --window-id "${tiled_ids[0]}" --wrap-around dfs-next
	restore_focus
	exit 0
fi

# Discover tree (DFS) order by walking focus. Abort untouched on anything
# unexpected: a non-tiled id, or failing to cover every tiled window.
dfs_order=()
i=0
limit=$(( n * 3 + 4 ))
while (( ${#dfs_order[@]} < n && i < limit )); do
	"$AEROSPACE" focus --dfs-index "$i" >/dev/null 2>&1 || break
	id="$("$AEROSPACE" list-windows --focused --format '%{window-id}')"
	found=0
	for t in "${tiled_ids[@]}"; do
		if [[ "$t" == "$id" ]]; then found=1; break; fi
	done
	if (( found == 0 )); then
		restore_focus
		exit 0
	fi
	dup=0
	for t in ${dfs_order[@]+"${dfs_order[@]}"}; do
		if [[ "$t" == "$id" ]]; then dup=1; break; fi
	done
	if (( dup == 0 )); then dfs_order+=("$id"); fi
	i=$(( i + 1 ))
done
if (( ${#dfs_order[@]} != n )); then
	restore_focus
	exit 0
fi

swaps_input="$(jq -cn --argjson plan "$plan_json" \
	'{moveTo: $plan.moveTo, dfsOrder: [$ARGS.positional[] | tonumber]}' \
	--args "${dfs_order[@]}")"
swaps="$(osascript "$CORE" swaps "$swaps_input")"

while read -r wid dir; do
	[[ -n "$wid" ]] || continue
	"$AEROSPACE" swap --window-id "$wid" "$dir"
done <<<"$swaps"

restore_focus
