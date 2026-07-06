# AeroSpace rotate & mirror (yabai parity) — design

Date: 2026-07-06
Status: approved

## Problem

The AeroSpace port (`aerospace/aerospace.toml`) mapped yabai's rotate/mirror
bindings to commands that change container orientation instead of moving
windows:

- `alt-shift-r`, `ctrl-shift-f2`, `ctrl-shift-f6` → `layout horizontal vertical`
  (toggles one container's split; yabai ran
  `yabai/scripts/rotate_without_changing_layout.sh cw|ccw`, which cycles
  windows through their existing frames).
- `alt-shift-z` → `layout h_tiles`, `alt-shift-x` → `layout v_tiles`
  (yabai ran `--mirror y-axis` / `--mirror x-axis`).

AeroSpace 0.21.1 has no native rotate/mirror commands.

## Approach (chosen: geometric engine)

Keep the frame slots fixed and permute which window occupies which slot —
the same philosophy as the yabai `rotate_without_changing_layout.sh` script.
Rotation uses that script's exact angular math; mirror pairs windows across
the axis midline. True yabai `--mirror` also mirrors frame *sizes*; that is
not reachable through the AeroSpace CLI and is explicitly out of scope
(user-approved: "swap the tree and it can be similar").

Alternatives considered and rejected:
- DFS-only rotate/mirror (cycle/reverse tree order): no frame reading and no
  focus flicker, but rotate "snakes" on grids and mirror loses the per-axis
  distinction on nested layouts.
- Hybrid (DFS rotate + geometric mirror): rejected in favor of full yabai
  fidelity since the geometric machinery is shared anyway.

## Verified platform facts (AeroSpace 0.21.1-Beta, macOS)

- `aerospace list-windows --workspace focused --format '%{window-id}|%{window-layout}|...'`
  exposes per-window layout (`h_tiles`, `floating`,
  `macos_native_window_of_hidden_app`, …) but not frames and not tree order.
- Window frames are readable without extra permissions via JXA:
  `CGWindowListCopyWindowInfo` bridged with `ObjC.castRefToObject(...)`
  (`$.CFBridgingRelease` segfaults; `ObjC.deepUnwrap` alone returns a
  non-array). `kCGWindowNumber` equals AeroSpace `window-id` (verified).
- `aerospace focus --dfs-index <i>` + `aerospace list-windows --focused`
  enumerate the tiling tree's DFS order.
- `aerospace swap --window-id <id> [--wrap-around] (dfs-next|dfs-prev|…)`
  performs deterministic adjacent-in-DFS swaps that move windows between
  slots while frames stay put.
- `aerospace eval` may batch multiple commands (verify at implementation
  time; sequential CLI calls are the fallback and are fast enough).

## Components

### 1. `aerospace/scripts/permute.sh`

Subcommand style matching `aerospace/scripts/workspace.sh`
(`set -euo pipefail`, `AEROSPACE` env override):

```
permute.sh (rotate-cw|rotate-ccw|mirror-y|mirror-x)
```

Pipeline:

1. **Gather**: list windows of the focused workspace with
   `%{window-id}` + `%{window-layout}`; keep only tiling-tree windows
   (layout value `*_tiles` / `*_accordion`). If ≤ 1 remain, exit 0 silently.
2. **Frames**: one JXA invocation returns `id → (x, y, w, h)` for on-screen
   windows; compute centers. Any tiled window missing a frame → exit 0
   without swapping anything.
3. **Target permutation** (geometry only, no side effects):
   - `rotate-cw` / `rotate-ccw`: port the yabai script's math — centroid of
     centers, `atan2` angles with flipped Y normalized to [0, 2π), cw = ring
     in descending angle, ccw ascending; each window moves to the next slot
     in the ring.
   - `mirror-y` / `mirror-x`: reflect each window's center across the
     vertical / horizontal midline of the tiled windows' bounding box; build
     the assignment by greedy nearest-slot matching on reflected points
     (sort candidate pairs by distance, assign each window/slot once) —
     guarantees a bijection; exact on symmetric layouts, approximate on
     asymmetric ones. Windows may map to themselves (fixed points).
   - Identity permutation → exit 0 before any focus/swap side effects
     (e.g. `mirror-x` on a flat row).
4. **DFS order discovery** (only when there is work): remember the focused
   window id, then for each index `focus --dfs-index i` + read back the
   focused window id. If the walk yields an id outside the tiled set or
   fails to cover all tiled windows, abort without swapping (adjacent-swap
   bookkeeping assumes the walked order is exactly the tiled set). n = 2
   fast path: a single `swap --window-id <a> --wrap-around dfs-next`, no
   walk needed.
5. **Execute**: decompose the permutation into adjacent transpositions in
   DFS-index space (selection-sort bubbling, ≤ n(n−1)/2 swaps), each
   `swap --window-id <id> (dfs-prev|dfs-next)`; batch via `eval` if
   supported, else sequential. Restore focus to the originally focused
   window (focus therefore travels with it to its new slot, matching the
   yabai script).

### 2. `aerospace/aerospace.toml` binding changes

| Key | Old | New |
|---|---|---|
| `alt-shift-r` | `layout horizontal vertical` | `exec-and-forget … permute.sh rotate-cw` |
| `ctrl-shift-f2` | `layout horizontal vertical` | `… permute.sh rotate-ccw` |
| `ctrl-shift-f6` | `layout horizontal vertical` | `… permute.sh rotate-cw` |
| `alt-shift-z` | `layout h_tiles` | `… permute.sh mirror-y` |
| `alt-shift-x` | `layout v_tiles` | `… permute.sh mirror-x` |

Invocation form follows the existing bindings:
`exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/scripts/permute.sh <op>"`.

## Edge cases

- Floating, hidden, minimized, macOS-native-fullscreen windows: excluded by
  the layout filter; never swapped.
- Accordion containers: members overlap so geometry is degenerate, but swaps
  merely reorder the deck — harmless.
- AeroSpace `fullscreen`-toggled window: participates with its inflated
  frame (same rough edge as the yabai script had with zoom-fullscreen);
  rare, accepted.
- Multi-monitor: only the focused workspace's windows are listed; CG global
  coordinates are consistent within one monitor, so centroid math is safe.
- Any unexpected state (missing frames, dfs walk mismatch): exit without
  performing swaps rather than half-applying a permutation.

## Testing

Manual, on a scratch workspace:

- 2 windows: rotate swaps them; `mirror-y` swaps a side-by-side pair;
  `mirror-x` on a side-by-side pair is a no-op (identity fast path).
- Main + stack (3 windows) and 2×2 grid: `rotate-cw` then `rotate-ccw`
  restores the original arrangement; mirror twice restores the original on
  symmetric layouts; frames before/after are the same set (snapshot ids +
  frames via the JXA helper and diff).
- Focus ends on the originally focused window.
- Config: auto-reload picks up the bindings; keys fire the script
  (`aerospace trigger-binding` can drive them without the keyboard).
- Confirm the `~/.config/aerospace` symlink exposes `scripts/permute.sh`
  (`symlink.sh` already links the `aerospace/` directory).

## Out of scope

- True frame mirroring (yabai `--mirror` size semantics) — not expressible
  via the AeroSpace CLI.
- Rotating frame geometry 90° (yabai `--rotate`) — the yabai config had
  moved away from this intentionally (`rotate_without_changing_layout.sh`).
- Any change to the other ported bindings.
