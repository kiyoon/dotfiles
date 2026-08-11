#!/usr/bin/env bash
# Render Amphetamine's session state without capturing its menu bar item.

source "$CONFIG_DIR/colors.sh"

# Avoid launching Amphetamine merely to populate the bar.
if ! pgrep -x Amphetamine >/dev/null; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

state="$(osascript -e 'tell application id "com.if.Amphetamine" to return session is active' 2>/dev/null || true)"

case "$state" in
true)
	# Amphetamine is preventing sleep.
	sketchybar --set "$NAME" \
		drawing=on \
		icon=󰒳 \
		icon.color="$ACCENT_COLOR" \
		label.drawing=off
	;;
false)
	sketchybar --set "$NAME" \
		drawing=on \
		icon=󰒲 \
		icon.color="$MUTED_COLOR" \
		label.drawing=off
	;;
*)
	# Automation permission may be missing; do not display a false state.
	sketchybar --set "$NAME" drawing=off
	;;
esac
