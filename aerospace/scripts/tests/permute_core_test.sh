#!/usr/bin/env bash
# Tests for permute_core.js. Pure math cases inject geometry; no window manager needed.
set -euo pipefail

CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/permute_core.js"
pass=0
fail=0

check() { # name expected actual
	if [[ "$2" == "$3" ]]; then
		pass=$(( pass + 1 ))
	else
		fail=$(( fail + 1 ))
		echo "FAIL $1"
		echo "  expected: $2"
		echo "  actual:   $3"
	fi
}

# 2x2 grid in a 100x100 space: 1=top-left 2=top-right 3=bottom-left 4=bottom-right
GRID='[{"id":1,"x":0,"y":0,"w":50,"h":50},{"id":2,"x":50,"y":0,"w":50,"h":50},{"id":3,"x":0,"y":50,"w":50,"h":50},{"id":4,"x":50,"y":50,"w":50,"h":50}]'

# cw: TL→TR, TR→BR, BR→BL, BL→TL (true circle, like yabai's angular sort)
check rotate-cw-grid '{"moveTo":{"1":2,"2":4,"3":1,"4":3}}' \
	"$(osascript "$CORE" plan rotate-cw "$GRID")"

# ccw: TR→TL, TL→BL, BL→BR, BR→TR
check rotate-ccw-grid '{"moveTo":{"1":3,"2":1,"3":4,"4":2}}' \
	"$(osascript "$CORE" plan rotate-ccw "$GRID")"

# main+stack: 1=left main, 2=top-right, 3=bottom-right.
# cw: left→top-right→bottom-right→left (matches the yabai script's behavior)
MAINSTACK='[{"id":1,"x":0,"y":0,"w":50,"h":100},{"id":2,"x":50,"y":0,"w":50,"h":50},{"id":3,"x":50,"y":50,"w":50,"h":50}]'
check rotate-cw-mainstack '{"moveTo":{"1":2,"2":3,"3":1}}' \
	"$(osascript "$CORE" plan rotate-cw "$MAINSTACK")"

# mirror-y on the grid: swap columns
check mirror-y-grid '{"moveTo":{"1":2,"2":1,"3":4,"4":3}}' \
	"$(osascript "$CORE" plan mirror-y "$GRID")"

# mirror-x on the grid: swap rows
check mirror-x-grid '{"moveTo":{"1":3,"2":4,"3":1,"4":2}}' \
	"$(osascript "$CORE" plan mirror-x "$GRID")"

# mirror-x on a flat row: nothing crosses the horizontal midline -> identity
ROW='[{"id":1,"x":0,"y":0,"w":50,"h":100},{"id":2,"x":50,"y":0,"w":50,"h":100}]'
check mirror-x-row-identity '{"identity":true}' \
	"$(osascript "$CORE" plan mirror-x "$ROW")"

# mirror-y on asymmetric main+stack: greedy pairing swaps main with nearest
# reflected partner (deterministic tiebreak by id), the leftover stays put.
check mirror-y-mainstack '{"moveTo":{"1":2,"2":1,"3":3}}' \
	"$(osascript "$CORE" plan mirror-y "$MAINSTACK")"

# unknown op reports an error (osascript prints the JSON we return)
check unknown-op '{"error":"unknown op sideways"}' \
	"$(osascript "$CORE" plan sideways "$ROW")"

# frames: live smoke test only - valid JSON object with numeric rects
FRAMES="$(osascript "$CORE" frames)"
check frames-shape true \
	"$(printf '%s' "$FRAMES" | jq -c 'type == "object" and (to_entries | all(.value | (has("x") and has("y") and has("w") and has("h"))))')"

echo "pass=$pass fail=$fail"
(( fail == 0 ))
