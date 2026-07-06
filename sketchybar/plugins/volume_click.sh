#!/usr/bin/env bash
# Click on the volume item: toggle mute, then refresh the display.

source "$CONFIG_DIR/colors.sh"

osascript -e 'set volume output muted (not (output muted of (get volume settings)))'
exec "$CONFIG_DIR/plugins/volume.sh"
