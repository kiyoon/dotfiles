#!/usr/bin/env bash
# Toggle visibility/highlight of the pre-created space.1..30 items, group them
# by monitor (divider.1..3 between groups, positioned via --reorder), and
# render each visible workspace's app icons (sketchybar-app-font ligatures) so
# the bar is a live map of what's where.
# Visible = non-empty workspaces (all monitors) + the focused one.
# Runs on: aerospace_workspace_change (FOCUSED_WORKSPACE env from aerospace),
# forced, system_woke, display_change, space_windows_change.
# Events are trailing-edge debounced because macOS reports multi-monitor
# hot-plug as several transient layouts. Querying AeroSpace during those
# layouts can expose its monitor/workspace reconciliation crash.

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
DEBOUNCE_SECONDS="${AEROSPACE_WORKSPACES_DEBOUNCE_SECONDS:-3}"
STATE_DIR="${AEROSPACE_WORKSPACES_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar}"
TOKEN_FILE="$STATE_DIR/aerospace-workspaces.generation"
RENDER_LOCK="$STATE_DIR/aerospace-workspaces.render.lock"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

read_token() {
	local token=""
	[[ -r "$TOKEN_FILE" ]] && IFS= read -r token <"$TOKEN_FILE"
	printf '%s' "$token"
}

schedule_render() {
	local token tmp
	mkdir -p "$STATE_DIR" 2>/dev/null || return 0
	token="$(date +%s).$$.${RANDOM:-0}"
	tmp="$TOKEN_FILE.$$.$RANDOM"
	if ! (umask 077 && printf '%s\n' "$token" >"$tmp"); then
		rm -f "$tmp"
		return 0
	fi
	if ! mv -f "$tmp" "$TOKEN_FILE"; then
		rm -f "$tmp"
		return 0
	fi

	# Every event gets a cheap sleeper, but only the newest token can reach the
	# renderer. lockf serializes the rare case where an event lands while the
	# previous render is still finishing. Redirect all descriptors so
	# SketchyBar does not wait for the background worker's pipe to close.
	(
		sleep "$DEBOUNCE_SECONDS"
		[[ "$(read_token)" == "$token" ]] || exit 0
		/usr/bin/lockf -k "$RENDER_LOCK" /bin/bash "$SCRIPT_PATH" --render-if-current "$token"
	) </dev/null >/dev/null 2>&1 &
}

case "${1:-}" in
--render-now)
	# Foreground entry point for tests and manual diagnostics.
	;;
--render-if-current)
	# Recheck after acquiring RENDER_LOCK. A newer event may have arrived while
	# this worker was waiting for the previous render to finish.
	[[ -n "${2:-}" && "$(read_token)" == "$2" ]] || exit 0
	;;
*)
	schedule_render
	exit 0
	;;
esac

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

if ! command -v "$AEROSPACE" >/dev/null 2>&1; then
	exit 0
fi

# This used to run immediately in exec-on-workspace-change, adding one CLI
# request per event while displays were still enumerating. Keep the history
# update behind the same debounce gate as the workspace renderer.
MONITOR_TRACKER="${AEROSPACE_MONITOR_TRACKER:-$HOME/.config/aerospace/scripts/monitor.sh}"
if [[ "${AEROSPACE_WORKSPACES_TRACK_MONITOR:-1}" != "0" && -f "$MONITOR_TRACKER" ]]; then
	AEROSPACE="$AEROSPACE" /bin/bash "$MONITOR_TRACKER" track >/dev/null 2>&1 || true
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
