#!/usr/bin/env bash
# Both cached usage meters open CodexBar's merged native menu. This uses
# Accessibility to click the real status item; it does not capture its pixels.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

if ! /usr/bin/pgrep -x CodexBar >/dev/null 2>&1; then
	open -gj -a CodexBar || exit 0
	for _ in {1..20}; do
		/usr/bin/pgrep -x CodexBar >/dev/null 2>&1 && break
		sleep 0.1
	done
fi

exec "$CONFIG_DIR/plugins/alias_click.sh" CodexBar Codex
