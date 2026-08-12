#!/usr/bin/env bash
# Optional live-capture fallback for CodexBar. This is deliberately invoked
# only when CODEXBAR_DISPLAY_MODE=alias in sketchybarrc.
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

target="${CODEXBAR_ALIAS_TARGET:-}"
menu_items='[]'

# Run only once per config load. SketchyBar 2.24 leaks the window-info array
# behind `default_menu_items`, so this must never become a recurring poll.
# A few bounded retries cover CodexBar/Control Center startup ordering.
for attempt in 1 2 3 4 5; do
	menu_items="$(sketchybar --query default_menu_items 2>/dev/null || printf '[]')"
	if [[ -z "$target" ]]; then
		candidate="$(printf '%s\n' "$menu_items" | jq -r \
			'map(select((split(",") | last) | startswith("codexbar-merged"))) | first // empty')"
		# default_menu_items appends a volatile window id such as `(36)`;
		# --add alias expects the stable owner,item pair.
		target="${candidate%%(*}"
	fi
	if [[ -n "$target" ]] && printf '%s\n' "$menu_items" | jq -e --arg target "$target" \
		'any(.[]; . == $target or startswith($target + "("))' >/dev/null 2>&1; then
		break
	fi
	[[ "$attempt" -eq 5 ]] && exit 0
	sleep 0.2
done

if ! sketchybar --query codexbar >/dev/null 2>&1; then
	sketchybar --add alias "$target" right \
		--rename "$target" codexbar \
		--set codexbar \
		alias.update_freq=10 \
		click_script="$PLUGIN_DIR/alias_click.sh CodexBar Codex" \
		padding_left=-9 \
		padding_right=-9 \
		alias.color="$LABEL_COLOR"
fi
