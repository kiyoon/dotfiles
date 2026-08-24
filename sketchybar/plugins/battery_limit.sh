#!/usr/bin/env bash
# Compatibility entry point: the shared renderer now updates both adjacent
# battery click zones atomically.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/battery.sh"
