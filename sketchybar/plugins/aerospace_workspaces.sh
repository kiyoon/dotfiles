#!/usr/bin/env bash
# Toggle visibility/highlight of the pre-created space.1..30 items, group them
# by monitor (divider.1..3 between groups, positioned via --reorder), and
# render each visible workspace's app icons (sketchybar-app-font ligatures) so
# the bar is a live map of what's where.
# Visible = non-empty workspaces (all monitors) + the focused one.
# Runs on: aerospace_workspace_change (FOCUSED_WORKSPACE env from aerospace),
# aerospace_started, forced, system_woke, display_change, space_windows_change.
# Focus changes update their highlight immediately from the event payload,
# without querying AeroSpace. Routine workspace/window events coalesce for a
# few milliseconds before the complete workspace/monitor/icon render.
# Active-display changes use the normal coalescer. Actual topology transitions
# are identified by Hammerspoon's recovery marker so queries cannot hit
# AeroSpace while macOS is publishing transient monitor layouts.

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"
EVENT_COALESCE_SECONDS="${AEROSPACE_WORKSPACES_EVENT_COALESCE_SECONDS:-${AEROSPACE_WORKSPACES_DEBOUNCE_SECONDS:-0.05}}"
RECOVERY_FALLBACK_SECONDS="${AEROSPACE_WORKSPACES_RECOVERY_FALLBACK_SECONDS:-12}"
RECOVERY_HOLD_MAX_SECONDS="${AEROSPACE_WORKSPACES_RECOVERY_HOLD_MAX_SECONDS:-30}"
STATE_DIR="${AEROSPACE_WORKSPACES_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar}"
TOKEN_FILE="$STATE_DIR/aerospace-workspaces.generation"
RENDER_LOCK="$STATE_DIR/aerospace-workspaces.render.lock"
REFRESH_MARKER="${AEROSPACE_WORKSPACES_REFRESH_MARKER:-${XDG_CACHE_HOME:-$HOME/.cache}/aerospace/refresh-now}"
RECOVERY_PENDING_MARKER="${AEROSPACE_WORKSPACES_RECOVERY_PENDING_MARKER:-${XDG_CACHE_HOME:-$HOME/.cache}/aerospace/recovery-pending}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
RENDER_TOKEN=""
RENDER_MODE="normal"
RENDER_PENDING_TOKEN=""

read_token() {
	local token=""
	[[ -r "$TOKEN_FILE" ]] && IFS= read -r token <"$TOKEN_FILE"
	printf '%s' "$token"
}

render_is_current() {
	[[ -z "$RENDER_TOKEN" || "$(read_token)" == "$RENDER_TOKEN" ]]
}

read_marker() {
	local marker="$1" value=""
	[[ -r "$marker" ]] && IFS= read -r value <"$marker"
	printf '%s' "$value"
}

read_recovery_token() {
	read_marker "$RECOVERY_PENDING_MARKER"
}

mark_recovery_pending() {
	local marker_dir tmp token
	marker_dir="${RECOVERY_PENDING_MARKER%/*}"
	mkdir -p "$marker_dir" 2>/dev/null || return 0
	tmp="$RECOVERY_PENDING_MARKER.$$.$RANDOM"
	token="$(/bin/date +%s).$$.${RANDOM:-0}"
	if (umask 077 && printf '%s\n' "$token" >"$tmp") && mv -f "$tmp" "$RECOVERY_PENDING_MARKER"; then
		printf '%s' "$token"
		return 0
	fi
	rm -f "$tmp"
}

clear_recovery_pending() {
	rm -f "$RECOVERY_PENDING_MARKER"
}

recovery_is_pending() {
	local modified now
	[[ -f "$RECOVERY_PENDING_MARKER" ]] || return 1

	# Do not let a marker left by a failed/reloaded recovery suppress normal
	# updates forever. A live recovery refreshes or consumes it well before
	# this ceiling.
	modified="$(/usr/bin/stat -f '%m' "$RECOVERY_PENDING_MARKER" 2>/dev/null)" || return 0
	now="$(/bin/date +%s)"
	if [[ "$modified" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]] &&
		(( now - modified >= RECOVERY_HOLD_MAX_SECONDS )); then
		clear_recovery_pending
		return 1
	fi
	return 0
}

claim_recovery_token() {
	local expected="$1" claimed actual
	[[ -n "$expected" && -f "$RECOVERY_PENDING_MARKER" ]] || return 1
	claimed="$RECOVERY_PENDING_MARKER.claim.$$.$RANDOM"
	mv "$RECOVERY_PENDING_MARKER" "$claimed" 2>/dev/null || return 1
	actual="$(read_marker "$claimed")"

	# If the contents differ, or another topology event created a new marker
	# after our mv, this worker belongs to an older recovery generation.
	if [[ "$actual" != "$expected" || -e "$RECOVERY_PENDING_MARKER" ]]; then
		if [[ ! -e "$RECOVERY_PENDING_MARKER" ]]; then
			mv "$claimed" "$RECOVERY_PENDING_MARKER" 2>/dev/null || rm -f "$claimed"
		else
			rm -f "$claimed"
		fi
		return 1
	fi
	rm -f "$claimed"
}

prepare_render() {
	case "$RENDER_MODE" in
	ready | fallback)
		claim_recovery_token "$RENDER_PENDING_TOKEN"
		;;
	*)
		! recovery_is_pending
		;;
	esac
}

render_can_commit() {
	render_is_current && ! recovery_is_pending
}

schedule_render() {
	local delay="${1:-$EVENT_COALESCE_SECONDS}"
	local mode="${2:-normal}"
	local pending_token="${3:-}"
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
		sleep "$delay"
		[[ "$(read_token)" == "$token" ]] || exit 0
		/usr/bin/lockf -k "$RENDER_LOCK" /bin/bash "$SCRIPT_PATH" \
			--render-if-current "$token" "$mode" "$pending_token"
	) </dev/null >/dev/null 2>&1 &
}

update_focus_from_event() {
	local focused="${FOCUSED_WORKSPACE:-}"
	[[ "$focused" =~ ^[0-9]+$ ]] || return 0
	(( focused >= 1 && focused <= 30 )) || return 0

	# This is one SketchyBar IPC call and zero AeroSpace calls. Reset every
	# pre-created item so rapid 1 -> 2 -> 3 events cannot leave stale accents;
	# drawing=on also makes a newly focused empty workspace visible at once.
	source "$CONFIG_DIR/colors.sh"
	"$SKETCHYBAR" \
		--set '/^space\.[0-9][0-9]*$/' \
		background.color="$ITEM_BG_COLOR" \
		icon.color="$LABEL_COLOR" \
		label.color="$LABEL_COLOR" \
		--set "space.$focused" \
		drawing=on \
		background.color="$ACCENT_COLOR" \
		icon.color="$BG_DARK" \
		label.color="$BG_DARK"
}

case "${1:-}" in
--render-now)
	# Foreground entry point for tests and manual diagnostics.
	;;
--render-if-current)
	# Recheck after acquiring RENDER_LOCK. A newer event may have arrived while
	# this worker was waiting for the previous render to finish.
	[[ -n "${2:-}" && "$(read_token)" == "$2" ]] || exit 0
	RENDER_TOKEN="$2"
	RENDER_MODE="${3:-normal}"
	RENDER_PENDING_TOKEN="${4:-}"
	;;
*)
	refresh_now="${REFRESH_NOW:-0}"
	ready_token=""
	if [[ "${SENDER:-}" == "aerospace_started" && -f "$REFRESH_MARKER" ]]; then
		consumed_marker="$REFRESH_MARKER.$$"
		if mv "$REFRESH_MARKER" "$consumed_marker" 2>/dev/null; then
			ready_token="$(read_marker "$consumed_marker")"
			rm -f "$consumed_marker"
		fi
	fi

	# Schedule first so this event's generation invalidates any older renderer
	# before the immediate focus colors are committed.
	if [[ "${SENDER:-}" == "system_woke" ]]; then
		pending_token="$(mark_recovery_pending)"
		# Hammerspoon will restart AeroSpace after the display topology settles;
		# a generation-matched startup event supersedes this fallback.
		schedule_render "$RECOVERY_FALLBACK_SECONDS" fallback "$pending_token"
	elif [[ "${SENDER:-}" == "aerospace_started" ]]; then
		pending_token="$(read_recovery_token)"
		if [[ -n "$ready_token" && "$ready_token" == "$pending_token" ]]; then
			schedule_render 0 ready "$pending_token"
		elif recovery_is_pending; then
			# A newer topology generation superseded this startup.
			schedule_render "$RECOVERY_FALLBACK_SECONDS" fallback "$(read_recovery_token)"
		else
			# Ordinary login startup has no recovery handshake.
			schedule_render 0
		fi
	elif recovery_is_pending; then
		# Workspace/window events can be emitted as a side effect of hot-plug.
		# They must not shorten the display-recovery hold.
		schedule_render "$RECOVERY_FALLBACK_SECONDS" fallback "$(read_recovery_token)"
	elif [[ "$refresh_now" == "1" || "${SENDER:-}" == "forced" ]]; then
		schedule_render 0
	else
		# Event-driven, trailing-edge coalescing only. There is no idle timer:
		# one 50 ms worker is armed by a real workspace/window/active-display
		# event. SketchyBar's display_change means active display, not topology.
		schedule_render "$EVENT_COALESCE_SECONDS"
	fi

	if [[ "${SENDER:-}" == "aerospace_workspace_change" ]]; then
		update_focus_from_event
	fi
	exit 0
	;;
esac

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

if ! command -v "$AEROSPACE" >/dev/null 2>&1; then
	exit 0
fi

prepare_render || exit 0

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

# Focused workspace and its monitor. FOCUSED_WORKSPACE belongs only to the
# immediate styling path: by the time this delayed renderer runs, a newer focus
# can exist, so the fresh AeroSpace snapshot must be authoritative.
focused_line="$("$AEROSPACE" list-workspaces --focused --format '%{workspace}|%{monitor-id}' 2>/dev/null)"
focused="${focused_line%%|*}"
focused_monitor="${focused_line##*|}"

# AeroSpace not running: hide everything.
if [[ -z "$focused" ]]; then
	render_can_commit || exit 0
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
	render_can_commit || exit 0
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

# Queries and icon mapping take time. Abort if a newer event arrived after this
# worker's first generation check so stale snapshot colors cannot overwrite the
# query-free focus update.
render_can_commit || exit 0

"$SKETCHYBAR" --reorder "${reorder[@]}" "${args[@]}"
