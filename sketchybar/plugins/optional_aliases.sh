#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

CC_OWNER="${CC_OWNER:-Centre de contrôle}"
menu_items="$(sketchybar --query default_menu_items 2>/dev/null || printf '[]')"

# `sketchybar --query default_menu_items` enumerates the real menu bar and comes
# back EMPTY on ~1/3 of calls. Treating that as "the apps are gone" removes the
# aliases, then the next good tick re-adds them -> visible flicker. Bail unless
# the enumeration is trustworthy (non-empty); a flaky tick becomes a no-op.
if [[ "$(printf '%s' "$menu_items" | jq 'length' 2>/dev/null || echo 0)" -eq 0 ]]; then
	exit 0
fi

has_menu_item() {
	local target="$1"
	printf '%s\n' "$menu_items" | jq -e --arg target "$target" \
		'any(.[]; . == $target or startswith($target + "("))' >/dev/null
}

has_item() {
	sketchybar --query "$1" >/dev/null 2>&1
}

remove_if_missing() {
	local target="$1"
	local name="$2"

	if ! has_menu_item "$target" && has_item "$name"; then
		sketchybar --remove "$name" >/dev/null 2>&1 || true
	fi
}

ensure_amphetamine() {
	local target="$CC_OWNER,Amphetamine"
	remove_if_missing "$target" amphetamine
	if has_menu_item "$target" && ! has_item amphetamine; then
		sketchybar --add alias "$target" right \
			--rename "$target" amphetamine \
			--set amphetamine \
			update_freq=3 \
			click_script="$PLUGIN_DIR/amphetamine_click.sh" \
			padding_left=-9 \
			padding_right=-9 \
			alias.color="$LABEL_COLOR" \
			--subscribe amphetamine amphetamine_change
	fi
}

ensure_codexbar() {
	local target="$CC_OWNER,codexbar-merged"
	remove_if_missing "$target" codexbar
	if has_menu_item "$target" && ! has_item codexbar; then
		sketchybar --add alias "$target" right \
			--rename "$target" codexbar \
			--set codexbar \
			update_freq=10 \
			click_script="$PLUGIN_DIR/alias_click.sh CodexBar Codex" \
			padding_left=-9 \
			padding_right=-9 \
			alias.color="$LABEL_COLOR"
	fi
}

ensure_amphetamine
ensure_codexbar
