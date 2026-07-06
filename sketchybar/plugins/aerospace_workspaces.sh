#!/usr/bin/env bash
# Toggle visibility/highlight of the pre-created space.1..30 items and render
# each visible workspace's app icons (sketchybar-app-font ligatures) so the
# bar is a live map of what's where.
# Visible = non-empty workspaces (all monitors) + the focused one.
# Runs on: aerospace_workspace_change (FOCUSED_WORKSPACE env from aerospace),
# forced, system_woke, display_change, space_windows_change.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

if ! command -v aerospace >/dev/null 2>&1; then
	exit 0
fi

focused="${FOCUSED_WORKSPACE:-}"
if [[ -z "$focused" ]]; then
	focused="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

# AeroSpace not running: hide everything.
if [[ -z "$focused" ]]; then
	args=()
	for sid in $(seq 1 30); do
		args+=(--set "space.$sid" drawing=off)
	done
	sketchybar "${args[@]}"
	exit 0
fi

nonempty="$(aerospace list-workspaces --monitor all --empty no 2>/dev/null)"
windows="$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)"

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

args=()
for sid in $(seq 1 30); do
	if [[ "$sid" == "$focused" ]] || grep -Fxq "$sid" <<<"$nonempty"; then
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
sketchybar "${args[@]}"
