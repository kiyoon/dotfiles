#!/usr/bin/env bash
# Bluetooth status for the paired "Boucles soniques" device.

source "$CONFIG_DIR/colors.sh"

DEVICE_NAME="${BOUCLES_DEVICE_NAME:-Boucles soniques}"
LOCK_DIR="${TMPDIR:-/tmp}/sketchybar-bluetooth-boucles.lock"
CACHE_FILE="${TMPDIR:-/tmp}/sketchybar-bluetooth-boucles.state"

set_item() {
	icon="$1"
	icon_color="$2"
	label_drawing="$3"
	label="${4:-}"
	{
		printf 'icon=%q\n' "$icon"
		printf 'icon_color=%q\n' "$icon_color"
		printf 'label_drawing=%q\n' "$label_drawing"
		printf 'label=%q\n' "$label"
	} >"$CACHE_FILE"
	sketchybar --set "$NAME" icon="$icon" icon.color="$icon_color" label.drawing="$label_drawing" label="$label"
}

render_cached() {
	if [[ -f "$CACHE_FILE" ]]; then
		# shellcheck disable=SC1090
		source "$CACHE_FILE"
		sketchybar --set "$NAME" icon="$icon" icon.color="$icon_color" label.drawing="$label_drawing" label="$label"
		return 0
	fi
	return 1
}

probe_once() {
	if ! mkdir "$LOCK_DIR" 2>/dev/null; then
		if [[ -f "$LOCK_DIR/pid" ]] && ! kill -0 "$(cat "$LOCK_DIR/pid")" 2>/dev/null; then
			rm -rf "$LOCK_DIR"
			exec "$0"
		fi
		render_cached || true
		exit 0
	fi
	printf '%s\n' "$$" >"$LOCK_DIR/pid"
	trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR"' EXIT

	profile="$(system_profiler -json SPBluetoothDataType 2>/dev/null)"
	if [[ -z "$profile" ]]; then
		set_item 󰂲 "$MUTED_COLOR" off
		exit 0
	fi

	state="$(printf '%s' "$profile" |
		plutil -extract SPBluetoothDataType.0.controller_properties.controller_state raw -o - - 2>/dev/null)"

	if [[ "$state" != "attrib_on" ]]; then
		set_item 󰂲 "$MUTED_COLOR" on off
		exit 0
	fi

	connected="$(printf '%s' "$profile" |
		plutil -extract SPBluetoothDataType.0.device_connected json -o - - 2>/dev/null)"

	if printf '%s' "$connected" | grep -Fq "\"$DEVICE_NAME\""; then
		set_item 󰂱 "$ACCENT_COLOR" on 󰋋
	else
		set_item 󰂯 "$MUTED_COLOR" off
	fi
}

case "${BOUCLES_STATE:-}" in
connected)
	set_item 󰂱 "$ACCENT_COLOR" on 󰋋
	;;
disconnected)
	set_item 󰂯 "$MUTED_COLOR" off
	;;
off)
	set_item 󰂲 "$MUTED_COLOR" on off
	;;
*)
	case "${SENDER:-}" in
	forced|system_woke|bluetooth_change|bluetooth_on|bluetooth_off)
		probe_once
		;;
	*)
		render_cached || set_item 󰂯 "$MUTED_COLOR" off
		;;
	esac
	;;
esac
