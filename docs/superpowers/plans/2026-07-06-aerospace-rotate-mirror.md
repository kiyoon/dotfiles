# AeroSpace yabai-style Rotate/Mirror Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder rotate/mirror keybindings in the AeroSpace config with a script that cycles/mirrors windows through their existing frame slots, matching the yabai setup (`yabai/scripts/rotate_without_changing_layout.sh` and `--mirror y-axis`/`x-axis`).

**Architecture:** A pure computation core in JXA (`permute_core.js`: window frames via CGWindowList, angular-rotation and mirror-pairing math, permutation→swap decomposition) driven by a thin bash orchestrator (`permute.sh`: query AeroSpace, discover tree order, execute `aerospace swap` commands, restore focus). Frames stay fixed; only window occupancy permutes.

**Tech Stack:** bash, jq, JXA (`osascript -l JavaScript`, built into macOS), AeroSpace 0.21.1 CLI.

**Spec:** `docs/superpowers/specs/2026-07-06-aerospace-rotate-mirror-design.md` (approved).

## Global Constraints

- macOS only; BSD userland (no GNU-isms); JXA is the only way to read frames (no pyobjc on this machine).
- `jq` is available and may be used (already a de-facto dependency of this dotfiles setup).
- AeroSpace ≥ 0.21.1: relies on `swap --window-id … (dfs-next|dfs-prev) [--wrap-around]`, `focus --dfs-index`, `list-windows --format`.
- JXA CGWindowList bridge MUST use `ObjC.deepUnwrap(ObjC.castRefToObject(ref))` — `$.CFBridgingRelease` segfaults, bare `deepUnwrap` returns a non-array (verified on this machine).
- Failure philosophy: on ANY unexpected state (unreadable frame, DFS walk mismatch, ≤1 tiled window, identity permutation) exit 0 silently without performing any swaps — never half-apply a permutation. Only a bad CLI argument exits non-zero.
- `set -euo pipefail` in bash scripts. Beware: bare `(( i++ ))` returns status 1 when the old value is 0 and kills the script under `set -e`; always use `i=$(( i + 1 ))`.
- Window-id ↔ CGWindowNumber equality is verified on this machine; layer-0 CG windows are the app windows.
- Do not `git add` unrelated dirty files (`nvim/*`, `oh-my-zsh/.zshrc`, `symlink.sh` are dirty from other work); stage only the files each task touches.
- Live tests must run on scratch workspace **29** so the user's real workspaces are never disturbed.

---

### Task 1: `permute_core.js` — `frames` + `plan` subcommands

**Files:**
- Create: `aerospace/scripts/permute_core.js`
- Test: `aerospace/scripts/tests/permute_core_test.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `osascript aerospace/scripts/permute_core.js frames` → stdout JSON `{"<window-id>": {"x":N,"y":N,"w":N,"h":N}, ...}` for all on-screen layer-0 windows.
  - `osascript aerospace/scripts/permute_core.js plan <op> <windows-json>` where `<op>` ∈ `rotate-cw|rotate-ccw|mirror-y|mirror-x` and `<windows-json>` is `[{"id":N}, ...]` (production) or `[{"id":N,"x":N,"y":N,"w":N,"h":N}, ...]` (tests inject geometry; entries missing `x` are filled from CGWindowList) → stdout JSON, one of:
    - `{"identity":true}` — nothing to do
    - `{"moveTo":{"<id>":<id>, ...}}` — window (key) must end up in the current slot of window (value); covers every input id, self-maps allowed
    - `{"error":"..."}` — e.g. frame unavailable
  - Unknown subcommand/op: throws (osascript exits non-zero).

- [ ] **Step 1: Write the failing test**

Create `aerospace/scripts/tests/permute_core_test.sh` (chmod +x):

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash aerospace/scripts/tests/permute_core_test.sh`
Expected: FAIL — osascript can't open `permute_core.js` (No such file), script exits non-zero.

- [ ] **Step 3: Write the implementation**

Create `aerospace/scripts/permute_core.js` (chmod +x):

```javascript
#!/usr/bin/osascript -l JavaScript
// Computation core for permute.sh (yabai-style rotate/mirror for AeroSpace).
// Windows keep their frame slots; only which window occupies which slot changes.
//
//   frames                    -> {"<window-id>": {"x":N,"y":N,"w":N,"h":N}, ...}
//   plan <op> <windows-json>  -> {"identity":true} | {"moveTo":{"<id>":<id>,...}} | {"error":"..."}
//                                op: rotate-cw|rotate-ccw|mirror-y|mirror-x
//                                windows: [{"id":N, "x":N,"y":N,"w":N,"h":N}]  (geometry
//                                optional; fetched from CGWindowList when absent)
//   swaps <input-json>        -> lines "<window-id> dfs-prev"   (added in a later task)

ObjC.import('CoreGraphics')

function cgFrames() {
	const ref = $.CGWindowListCopyWindowInfo(
		$.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements,
		$.kCGNullWindowID)
	// castRefToObject is required: CFBridgingRelease segfaults under osascript,
	// and deepUnwrap alone can't take the raw CFArrayRef.
	const arr = ObjC.deepUnwrap(ObjC.castRefToObject(ref))
	const out = {}
	for (const w of arr) {
		if (w.kCGWindowLayer !== 0) continue
		const b = w.kCGWindowBounds
		out[w.kCGWindowNumber] = { x: b.X, y: b.Y, w: b.Width, h: b.Height }
	}
	return out
}

function computePlan(op, windows) {
	if (windows.some(w => w.x === undefined)) {
		const frames = cgFrames()
		for (const w of windows) {
			if (w.x !== undefined) continue
			const f = frames[w.id]
			if (!f) return { error: `no frame for window ${w.id}` }
			Object.assign(w, f)
		}
	}
	for (const w of windows) {
		w.cx = w.x + w.w / 2
		w.cy = w.y + w.h / 2
	}

	let moveTo = {}
	if (op === 'rotate-cw' || op === 'rotate-ccw') {
		// Same math as yabai/scripts/rotate_without_changing_layout.sh:
		// angle around the centroid with Y flipped (0 = right, CCW positive),
		// normalized to [0, 2pi); cw walks the ring in descending angle.
		const mx = windows.reduce((s, w) => s + w.cx, 0) / windows.length
		const my = windows.reduce((s, w) => s + w.cy, 0) / windows.length
		for (const w of windows) {
			let a = Math.atan2(my - w.cy, w.cx - mx)
			if (a < 0) a += 2 * Math.PI
			w.key = op === 'rotate-ccw' ? a : 2 * Math.PI - a
		}
		const ring = windows.slice().sort((p, q) => p.key - q.key || p.id - q.id)
		for (let i = 0; i < ring.length; i++) moveTo[ring[i].id] = ring[(i + 1) % ring.length].id
	} else if (op === 'mirror-y' || op === 'mirror-x') {
		// Reflect each center across the bounding-box midline, then greedily pair
		// windows to slots by distance (deterministic: dist, then ids). Exact on
		// symmetric layouts; nearest sensible assignment on asymmetric ones.
		const xmin = Math.min(...windows.map(w => w.x))
		const xmax = Math.max(...windows.map(w => w.x + w.w))
		const ymin = Math.min(...windows.map(w => w.y))
		const ymax = Math.max(...windows.map(w => w.y + w.h))
		const pairs = []
		for (const w of windows) {
			const rx = op === 'mirror-y' ? xmin + xmax - w.cx : w.cx
			const ry = op === 'mirror-x' ? ymin + ymax - w.cy : w.cy
			for (const v of windows) pairs.push([Math.hypot(rx - v.cx, ry - v.cy), w.id, v.id])
		}
		pairs.sort((p, q) => p[0] - q[0] || p[1] - q[1] || p[2] - q[2])
		const slotTaken = new Set()
		for (const [, src, tgt] of pairs) {
			if (moveTo[src] !== undefined || slotTaken.has(tgt)) continue
			moveTo[src] = tgt
			slotTaken.add(tgt)
		}
	} else {
		return { error: `unknown op ${op}` }
	}

	if (Object.entries(moveTo).every(([a, b]) => String(a) === String(b))) return { identity: true }
	return { moveTo }
}

function run(argv) {
	const cmd = argv[0]
	if (cmd === 'frames') return JSON.stringify(cgFrames())
	if (cmd === 'plan') return JSON.stringify(computePlan(argv[1], JSON.parse(argv[2])))
	throw new Error('usage: permute_core.js frames | plan <op> <windows-json>')
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash aerospace/scripts/tests/permute_core_test.sh`
Expected: `pass=9 fail=0`, exit 0.

If `rotate-cw-grid` fails with reversed direction, the Y flip is wrong — CG
coordinates grow downward, the flip is `my - w.cy` (not `w.cy - my`).

- [ ] **Step 5: Commit**

```bash
git add aerospace/scripts/permute_core.js aerospace/scripts/tests/permute_core_test.sh
git commit -m "feat(aerospace): permute core - frames + rotate/mirror plan math"
```

---

### Task 2: `permute_core.js` — `swaps` subcommand

**Files:**
- Modify: `aerospace/scripts/permute_core.js`
- Modify: `aerospace/scripts/tests/permute_core_test.sh`

**Interfaces:**
- Consumes: the `moveTo` JSON shape produced by `plan` (Task 1).
- Produces: `osascript aerospace/scripts/permute_core.js swaps '{"moveTo":{...},"dfsOrder":[N,...]}'` → stdout: one line per swap, `"<window-id> dfs-prev"`, in execution order. `dfsOrder` is the tiled windows in tree (DFS) order; its id set MUST equal `moveTo`'s key set, else the script throws (exit non-zero, bash side treats as abort).

- [ ] **Step 1: Add failing tests**

Append to `aerospace/scripts/tests/permute_core_test.sh`, just above the final `echo "pass=..."` line:

```bash
# swaps: decompose the cw-grid permutation into adjacent DFS transpositions.
# dfsOrder [1,3,2,4] is the grid's tree order (left column then right column).
# Worked example: desired final order is [3,4,1,2]; selection-sort bubbling
# emits: bubble 3 to slot 0, bubble 4 (twice) to slot 1.
check swaps-cw-grid '3 dfs-prev
4 dfs-prev
4 dfs-prev' \
	"$(osascript "$CORE" swaps '{"moveTo":{"1":2,"2":4,"3":1,"4":3},"dfsOrder":[1,3,2,4]}')"

# a plain 2-cycle among adjacent windows is a single swap
check swaps-adjacent-pair '2 dfs-prev' \
	"$(osascript "$CORE" swaps '{"moveTo":{"1":2,"2":1,"3":3},"dfsOrder":[1,2,3]}')"

# id-set mismatch between moveTo and dfsOrder must throw (non-zero exit)
if osascript "$CORE" swaps '{"moveTo":{"1":2,"2":1},"dfsOrder":[1,9]}' >/dev/null 2>&1; then
	fail=$(( fail + 1 ))
	echo "FAIL swaps-mismatch-throws (expected non-zero exit)"
else
	pass=$(( pass + 1 ))
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash aerospace/scripts/tests/permute_core_test.sh`
Expected: the three new checks FAIL (`swaps` hits the usage throw / mismatch case passes accidentally? No — the first two fail because `swaps` is not a known subcommand, the third passes since it exits non-zero). Expected summary: `pass=10 fail=2`, exit 1.

- [ ] **Step 3: Implement `swaps`**

In `aerospace/scripts/permute_core.js`, add after `computePlan`:

```javascript
function computeSwaps(moveTo, dfsOrder) {
	// Slots are DFS indices; "swap --window-id X dfs-prev" swaps X with the
	// window one slot earlier. Selection-sort bubbling realizes any permutation
	// as adjacent transpositions (<= n(n-1)/2 swaps).
	const slotOf = {}
	dfsOrder.forEach((id, i) => { slotOf[id] = i })
	const desired = new Array(dfsOrder.length)
	for (const [w, t] of Object.entries(moveTo)) desired[slotOf[t]] = Number(w)
	if (Object.keys(moveTo).length !== dfsOrder.length || desired.some(d => d === undefined || slotOf[d] === undefined)) {
		throw new Error('moveTo/dfsOrder id sets differ')
	}
	const current = dfsOrder.slice()
	const lines = []
	for (let i = 0; i < desired.length; i++) {
		for (let j = current.indexOf(desired[i]); j > i; j--) {
			lines.push(`${current[j]} dfs-prev`)
			const tmp = current[j - 1]
			current[j - 1] = current[j]
			current[j] = tmp
		}
	}
	return lines.join('\n')
}
```

And extend `run`:

```javascript
function run(argv) {
	const cmd = argv[0]
	if (cmd === 'frames') return JSON.stringify(cgFrames())
	if (cmd === 'plan') return JSON.stringify(computePlan(argv[1], JSON.parse(argv[2])))
	if (cmd === 'swaps') {
		const input = JSON.parse(argv[1])
		return computeSwaps(input.moveTo, input.dfsOrder)
	}
	throw new Error('usage: permute_core.js frames | plan <op> <windows-json> | swaps <input-json>')
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash aerospace/scripts/tests/permute_core_test.sh`
Expected: `pass=12 fail=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add aerospace/scripts/permute_core.js aerospace/scripts/tests/permute_core_test.sh
git commit -m "feat(aerospace): permute core - decompose permutation into dfs swaps"
```

---

### Task 3: `permute.sh` orchestrator

**Files:**
- Create: `aerospace/scripts/permute.sh`

**Interfaces:**
- Consumes: `permute_core.js` `plan` and `swaps` contracts (Tasks 1–2); `aerospace` CLI.
- Produces: `permute.sh (rotate-cw|rotate-ccw|mirror-y|mirror-x)` — the command the keybindings (Task 5) invoke. Exit 0 on success and on all no-op/abort paths; exit 2 on bad usage.

- [ ] **Step 1: Write the script**

Create `aerospace/scripts/permute.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# yabai-style rotate/mirror for AeroSpace: windows keep the existing frame
# slots, only which window occupies which slot changes (the same idea as
# yabai/scripts/rotate_without_changing_layout.sh).
#
# usage: permute.sh (rotate-cw|rotate-ccw|mirror-y|mirror-x)
set -euo pipefail

AEROSPACE="${AEROSPACE:-aerospace}"
CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/permute_core.js"

op="${1:-}"
case "$op" in
	rotate-cw | rotate-ccw | mirror-y | mirror-x) ;;
	*)
		echo "usage: $0 (rotate-cw|rotate-ccw|mirror-y|mirror-x)" >&2
		exit 2
		;;
esac

# Only windows in the tiling tree participate; floating/hidden/minimized
# windows keep their place and are never swapped.
tiled_ids=()
while IFS='|' read -r id layout; do
	case "$layout" in
	*_tiles | *_accordion) tiled_ids+=("$id") ;;
	esac
done < <("$AEROSPACE" list-windows --workspace focused --format '%{window-id}|%{window-layout}')

n="${#tiled_ids[@]}"
(( n >= 2 )) || exit 0

orig_focus="$("$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null || true)"

restore_focus() {
	if [[ -n "$orig_focus" ]]; then
		"$AEROSPACE" focus --window-id "$orig_focus" >/dev/null 2>&1 || true
	fi
}

windows_json="$(jq -cn '[$ARGS.positional[] | {id: tonumber}]' --args "${tiled_ids[@]}")"
plan_json="$(osascript "$CORE" plan "$op" "$windows_json")"

# Identity (e.g. mirror-x on a flat row) or unreadable frames: do nothing.
if jq -e '(.identity == true) or has("error")' <<<"$plan_json" >/dev/null; then
	exit 0
fi

if (( n == 2 )); then
	# Any non-identity permutation of two windows is the single swap; no tree
	# order discovery (and no focus flicker) needed.
	"$AEROSPACE" swap --window-id "${tiled_ids[0]}" --wrap-around dfs-next
	restore_focus
	exit 0
fi

# Discover tree (DFS) order by walking focus. Abort untouched on anything
# unexpected: a non-tiled id, or failing to cover every tiled window.
dfs_order=()
i=0
limit=$(( n * 3 + 4 ))
while (( ${#dfs_order[@]} < n && i < limit )); do
	"$AEROSPACE" focus --dfs-index "$i" >/dev/null 2>&1 || break
	id="$("$AEROSPACE" list-windows --focused --format '%{window-id}')"
	found=0
	for t in "${tiled_ids[@]}"; do
		if [[ "$t" == "$id" ]]; then found=1; break; fi
	done
	if (( found == 0 )); then
		restore_focus
		exit 0
	fi
	dup=0
	for t in ${dfs_order[@]+"${dfs_order[@]}"}; do
		if [[ "$t" == "$id" ]]; then dup=1; break; fi
	done
	if (( dup == 0 )); then dfs_order+=("$id"); fi
	i=$(( i + 1 ))
done
if (( ${#dfs_order[@]} != n )); then
	restore_focus
	exit 0
fi

swaps_input="$(jq -cn --argjson plan "$plan_json" \
	'{moveTo: $plan.moveTo, dfsOrder: [$ARGS.positional[] | tonumber]}' \
	--args "${dfs_order[@]}")"
swaps="$(osascript "$CORE" swaps "$swaps_input")"

while read -r wid dir; do
	[[ -n "$wid" ]] || continue
	"$AEROSPACE" swap --window-id "$wid" "$dir"
done <<<"$swaps"

restore_focus
```

- [ ] **Step 2: Safe live checks (no window movement)**

These exercise the argument validation and the ≤1-window no-op path on an
empty scratch workspace; they cannot disturb real windows.

```bash
bash -n aerospace/scripts/permute.sh   # syntax
ls -l ~/.config/aerospace/scripts/permute.sh   # reachable through the symlink (symlink.sh:47)
aerospace/scripts/permute.sh bogus; echo "exit=$?"
# Expected: usage line on stderr, exit=2

# remember where we are, then test the no-op path on empty workspace 29
aerospace list-workspaces --focused
aerospace workspace 29
aerospace/scripts/permute.sh rotate-cw; echo "exit=$?"
# Expected: exit=0 instantly, nothing else happens (0 tiled windows)
aerospace workspace-back-and-forth
```

Expected: as annotated above.

- [ ] **Step 3: Commit**

```bash
git add aerospace/scripts/permute.sh
git commit -m "feat(aerospace): permute.sh orchestrator for rotate/mirror"
```

---

### Task 4: Live verification on a scratch workspace

**Files:**
- None created/modified (verification only; fixes go into the files from Tasks 1–3 if bugs surface).

**Interfaces:**
- Consumes: `permute.sh` (Task 3), `permute_core.js frames` (Task 1).
- Produces: confirmed behavior for the two open platform assumptions — (a) `focus --dfs-index` is focused-workspace-scoped, (b) `swap --window-id … dfs-prev` matches our slot bookkeeping. If either fails, STOP and re-plan; do not proceed to Task 5.

- [ ] **Step 1: Set up three Finder windows on workspace 29**

```bash
aerospace workspace 29
open -n -a Finder ~ && sleep 1 && open -n -a Finder ~ && sleep 1 && open -n -a Finder ~
sleep 2
aerospace list-windows --workspace focused --format '%{window-id}|%{window-layout}|%{app-name}'
```

Expected: exactly 3 lines, all `|Finder`, layouts `*_tiles`. (If Finder windows
landed elsewhere, drag/move them to workspace 29 first — `aerospace
move-node-to-workspace 29` with each focused — and re-check.)

- [ ] **Step 2: Snapshot, rotate cw, verify cycle**

```bash
IDS="$(aerospace list-windows --workspace focused --format '%{window-id}' | paste -sd, -)"
osascript ~/.config/aerospace/scripts/permute_core.js frames | jq --argjson ids "[${IDS}]" \
	'with_entries(select((.key | tonumber) as $k | $ids | index($k)))' > /tmp/before.json
~/.config/aerospace/scripts/permute.sh rotate-cw
osascript ~/.config/aerospace/scripts/permute_core.js frames | jq --argjson ids "[${IDS}]" \
	'with_entries(select((.key | tonumber) as $k | $ids | index($k)))' > /tmp/after.json
jq -s '[.[0], .[1]] | map(to_entries | map(.value) | sort_by(.x, .y)) | .[0] == .[1]' /tmp/before.json /tmp/after.json
diff <(jq -S . /tmp/before.json) <(jq -S . /tmp/after.json) >/dev/null; echo "moved=$?"
```

Expected: the `jq -s` line prints `true` (same SET of frames — layout
preserved), and `moved=1` (id→frame mapping changed — windows actually
cycled). Visually: windows rotated one step clockwise.

- [ ] **Step 3: Verify ccw restores, then mirrors round-trip**

```bash
~/.config/aerospace/scripts/permute.sh rotate-ccw
osascript ~/.config/aerospace/scripts/permute_core.js frames | jq --argjson ids "[${IDS}]" \
	'with_entries(select((.key | tonumber) as $k | $ids | index($k)))' > /tmp/restored.json
diff <(jq -S . /tmp/before.json) <(jq -S . /tmp/restored.json) && echo "ccw-restores=OK"

~/.config/aerospace/scripts/permute.sh mirror-y
~/.config/aerospace/scripts/permute.sh mirror-y
osascript ~/.config/aerospace/scripts/permute_core.js frames | jq --argjson ids "[${IDS}]" \
	'with_entries(select((.key | tonumber) as $k | $ids | index($k)))' > /tmp/mirror2.json
diff <(jq -S . /tmp/before.json) <(jq -S . /tmp/mirror2.json) && echo "mirror-roundtrip=OK"
```

Expected: `ccw-restores=OK` and `mirror-roundtrip=OK`. (Note: on an
asymmetric 3-window layout mirror-y is its own inverse because the pairing is
a swap + fixed point, so twice = original.)

- [ ] **Step 4: Verify focus restoration**

```bash
FOCUS_BEFORE="$(aerospace list-windows --focused --format '%{window-id}')"
~/.config/aerospace/scripts/permute.sh rotate-cw
FOCUS_AFTER="$(aerospace list-windows --focused --format '%{window-id}')"
[[ "$FOCUS_BEFORE" == "$FOCUS_AFTER" ]] && echo "focus=OK"
~/.config/aerospace/scripts/permute.sh rotate-ccw
```

Expected: `focus=OK` (focus travels with the originally focused window).

- [ ] **Step 5: Clean up scratch workspace**

```bash
# close focuses-then-closes because `close --window-id` may not exist in 0.21
while wid="$(aerospace list-windows --workspace focused --format '%{window-id}' | head -1)" && [[ -n "$wid" ]]; do
	aerospace focus --window-id "$wid" && aerospace close
done
aerospace workspace-back-and-forth
```

Expected: Finder windows closed, back on the previous workspace. No commit
(nothing changed); if bugs were found and fixed, commit the fixes:
`git add aerospace/scripts/ && git commit -m "fix(aerospace): permute live-test fixes"`.

---

### Task 5: Rebind keys in `aerospace.toml`

**Files:**
- Modify: `aerospace/aerospace.toml` (the `alt-shift-r`/`z`/`x` lines in `[mode.main.binding]` "Layout controls." block, and the `ctrl-shift-f2`/`f6` lines near the resize block)

**Interfaces:**
- Consumes: `permute.sh` CLI (Task 3), verified live (Task 4).
- Produces: final user-facing keybindings.

- [ ] **Step 1: Update the bindings**

In `aerospace/aerospace.toml` replace:

```toml
alt-shift-r = 'layout horizontal vertical'
alt-shift-z = 'layout h_tiles'
alt-shift-x = 'layout v_tiles'
```

with:

```toml
# yabai-style rotate/mirror: windows cycle through the existing frame slots
# (scripts/permute.sh; same idea as yabai's rotate_without_changing_layout.sh).
alt-shift-r = 'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh rotate-cw"'
alt-shift-z = 'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh mirror-y"'
alt-shift-x = 'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh mirror-x"'
```

and replace:

```toml
ctrl-shift-f2 = 'layout horizontal vertical'
ctrl-shift-f6 = 'layout horizontal vertical'
```

with:

```toml
# rotate, matching the yabai ctrl-shift-f2/f6 bindings (ccw/cw)
ctrl-shift-f2 = 'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh rotate-ccw"'
ctrl-shift-f6 = 'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh rotate-cw"'
```

- [ ] **Step 2: Reload config and smoke-test a binding end-to-end**

The config has `auto-reload-config = true`, but reload explicitly and check
for errors, then fire one binding through AeroSpace itself (on the scratch
workspace with two Finder windows so it's harmless and visible):

```bash
aerospace reload-config && echo "reload=OK"
aerospace workspace 29
open -n -a Finder ~ && sleep 1 && open -n -a Finder ~ && sleep 2
aerospace trigger-binding --mode main alt-shift-r
sleep 1
aerospace list-windows --workspace focused --format '%{window-id}|%{app-name}'
```

Expected: `reload=OK` (no config errors); after `trigger-binding` the two
Finder windows have visibly swapped places. Clean up as in Task 4 Step 5.

- [ ] **Step 3: Commit**

```bash
git add aerospace/aerospace.toml
git commit -m "feat(aerospace): bind rotate/mirror keys to permute.sh (yabai parity)"
```
