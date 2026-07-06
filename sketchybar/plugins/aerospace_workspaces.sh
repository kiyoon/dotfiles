#!/usr/bin/env bash
# Toggle visibility/highlight of the pre-created space.1..30 items, group them
# by monitor (divider.1..3 between groups, positioned via --reorder), and
# render each visible workspace's app icons (sketchybar-app-font ligatures) so
# the bar is a live map of what's where.
# Visible = non-empty workspaces (all monitors) + the focused one.
# Runs on: aerospace_workspace_change (FOCUSED_WORKSPACE env from aerospace),
# forced, system_woke, display_change, space_windows_change.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"

if ! command -v "$AEROSPACE" >/dev/null 2>&1; then
	exit 0
fi

hide_all() {
	local args=() sid d
	for sid in $(seq 1 30); do
		args+=(--set "space.$sid" drawing=off)
	done
	for d in 1 2 3; do
		args+=(--set "divider.$d" drawing=off)
	done
	"$SKETCHYBAR" "${args[@]}"
}

# Focused workspace and its monitor. The FOCUSED_WORKSPACE env var (fast path
# from aerospace's exec-on-workspace-change) wins for the id and is assumed to
# live on the focused monitor.
focused_line="$("$AEROSPACE" list-workspaces --focused --format '%{workspace}|%{monitor-id}' 2>/dev/null)"
focused="${FOCUSED_WORKSPACE:-${focused_line%%|*}}"
focused_monitor="${focused_line##*|}"

# AeroSpace not running: hide everything.
if [[ -z "$focused" ]]; then
	hide_all
	exit 0
fi

# workspace|monitor-id pairs for every workspace that should be visible.
pairs="$("$AEROSPACE" list-workspaces --monitor all --empty no --format '%{workspace}|%{monitor-id}' 2>/dev/null)"
if [[ -z "$pairs" ]]; then
	pairs="$focused|${focused_monitor:-1}"
elif ! grep -q "^$focused|" <<<"$pairs"; then
	pairs+=$'\n'"$focused|${focused_monitor:-1}"
fi

windows="$("$AEROSPACE" list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)"

app_icons() {
	local sid="$1" app out=""
	while IFS= read -r app; do
		[[ -z "$app" ]] && continue
		icon_result=":default:"
		__icon_map "$app"
		out+="$icon_result "
	done < <(awk -F'|' -v ws="$sid" '$1 == ws { print substr($0, index($0, "|") + 1) }' <<<"$windows")
	printf '%s' "${out% }"
}

# Group by monitor: monitors ascending, workspaces numeric within each group.
# order = item names in the desired visual sequence, dividers between groups.
# Ids outside 1..30 have no bar item (date +%s fallback) and are skipped.
order=()
vis_lines=""
args=()
d=0
for mon in $(cut -d'|' -f2 <<<"$pairs" | sort -n | uniq); do
	group="$(awk -F'|' -v m="$mon" '$2 == m && $1 ~ /^[0-9]+$/ && $1 >= 1 && $1 <= 30 { print $1 }' <<<"$pairs" | sort -n | uniq)"
	[[ -z "$group" ]] && continue
	if (( ${#order[@]} > 0 && d < 3 )); then
		d=$((d + 1))
		order+=("divider.$d")
		args+=(--set "divider.$d" drawing=on)
	fi
	for sid in $group; do
		order+=("space.$sid")
		vis_lines+="$sid"$'\n'
	done
done
# Dividers after the last used group (d) stay hidden. Built with a guarded
# plain loop (not `seq $((d + 1)) 3`): BSD seq counts DOWN when start > end
# (e.g. `seq 4 3` -> "4 3"), which at d=3 would reference a nonexistent
# divider.4 and re-emit `--set divider.3 drawing=off` after the drawing=on
# above. Reused below for the reorder block.
unused_dividers=()
for dd in 1 2 3; do
	if (( dd > d )); then
		unused_dividers+=("divider.$dd")
	fi
done
for dv in "${unused_dividers[@]}"; do
	args+=(--set "$dv" drawing=off)
done

# Nothing visible (e.g. only an out-of-range focused id): treat as hidden bar.
if (( ${#order[@]} == 0 )); then
	hide_all
	exit 0
fi

for sid in $(seq 1 30); do
	if grep -Fxq "$sid" <<<"$vis_lines"; then
		icons="$(app_icons "$sid")"
		if [[ -n "$icons" ]]; then
			label_args=(label="$icons" label.drawing=on)
		else
			label_args=(label.drawing=off)
		fi
		if [[ "$sid" == "$focused" ]]; then
			args+=(--set "space.$sid" drawing=on
				background.color="$ACCENT_COLOR"
				icon.color="$BG_DARK" label.color="$BG_DARK"
				"${label_args[@]}")
		else
			args+=(--set "space.$sid" drawing=on
				background.color="$ITEM_BG_COLOR"
				icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"
				"${label_args[@]}")
		fi
	else
		args+=(--set "space.$sid" drawing=off)
	fi
done

# One batched call. The reorder block names all 33 items (visible sequence
# first, then hidden spaces and unused dividers) so the space/divider block
# stays contiguous and deterministic between aero_mode and front_app.
reorder=("${order[@]}")
for sid in $(seq 1 30); do
	grep -Fxq "$sid" <<<"$vis_lines" || reorder+=("space.$sid")
done
for dv in "${unused_dividers[@]}"; do
	reorder+=("$dv")
done

"$SKETCHYBAR" --reorder "${reorder[@]}" "${args[@]}"
