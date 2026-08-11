#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

CC_OWNER="${CC_OWNER:-Centre de contrôle}"
target="$CC_OWNER,codexbar-merged"
menu_items='[]'

# This script is intentionally run only once per config load. SketchyBar 2.24
# leaks the window-info array behind `default_menu_items`, so recurring polling
# causes unbounded memory growth. The query is also flaky during startup; use a
# few tightly bounded retries instead of a permanent watcher.
for attempt in 1 2 3 4 5; do
	menu_items="$(sketchybar --query default_menu_items 2>/dev/null || printf '[]')"
	if printf '%s\n' "$menu_items" | jq -e --arg target "$target" \
		'any(.[]; . == $target or startswith($target + "("))' >/dev/null 2>&1; then
		break
	fi
	[[ "$attempt" -eq 5 ]] && exit 0
	sleep 0.2
done

has_menu_item() {
	local target="$1"
	printf '%s\n' "$menu_items" | jq -e --arg target "$target" \
		'any(.[]; . == $target or startswith($target + "("))' >/dev/null
}

has_item() {
	sketchybar --query "$1" >/dev/null 2>&1
}

ensure_codexbar() {
	if has_menu_item "$target" && ! has_item codexbar; then
		sketchybar --add alias "$target" right \
			--rename "$target" codexbar \
			--set codexbar \
			alias.update_freq=10 \
			click_script="$PLUGIN_DIR/alias_click.sh CodexBar Codex" \
			padding_left=-9 \
			padding_right=-9 \
			alias.color="$LABEL_COLOR"
	fi
}

ensure_codexbar
