#!/usr/bin/env bash
# Show the focused application name.

source "$CONFIG_DIR/colors.sh"

if [[ "$SENDER" == "front_app_switched" ]]; then
	app="$INFO"
else
	# Initial fill (forced): ask aerospace instead of System Events to avoid
	# macOS automation permission prompts from a launchd daemon.
	app="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null)"
fi

if [[ -n "$app" ]]; then
	sketchybar --set "$NAME" label="$app"
fi
