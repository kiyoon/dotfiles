# SketchyBar: per-monitor workspace groups + CPU/RAM/GPU stats

**Date:** 2026-07-06
**Status:** Approved (divider grouping + three-pill stats confirmed by user)
**Amendment (same day):** the "Stats pills" section below is superseded. A
parallel implementation (three plugins `cpu.sh`/`gpu.sh`/`ram.sh`, separate
timers, 60/80 label-color thresholds, vm_stat-based RAM, `?%` fallback
instead of auto-hide) was built outside this plan and adopted verbatim by
user decision. The workspace-grouping section remains authoritative.

Builds on the existing setup from
`2026-07-06-sketchybar-aerospace-design.md`.

## Goal

1. Group the AeroSpace workspace items by monitor, with a thin divider
   between groups, so the bar shows which workspace lives on which screen.
2. Add CPU / RAM / GPU usage pills to the right side of the bar.

## Decisions

- **Workspace display:** every bar shows *all* workspaces (same content on
  every display, as today), grouped by monitor-id ascending with a muted `│`
  divider between groups. Chosen over per-display filtering — user wants a
  global overview from any screen.
- **Grouping mechanism:** keep the existing `space.1..30` identity items and
  dynamically `--reorder` them. Verified live: `sketchybar --reorder` moves
  the named items into the given order within the slots they already occupy;
  unnamed neighbors are unaffected. (Rejected: anonymous positional "slot"
  items — avoids reorder but rewrites the plugin and re-sets click scripts on
  every event.)
- **Stats:** three pills (`cpu`, `ram`, `gpu`) driven by *one* script on one
  timer, per-pill color coding, click opens Activity Monitor.

## Workspace grouping

`sketchybarrc`:

- Pre-create `divider.1`..`divider.3` (supports up to 4 monitors) after the
  space loop: muted `│` icon (`MUTED_COLOR`), `background.drawing=off`,
  no label, no click script, `drawing=off`.

`plugins/aerospace_workspaces.sh`:

- Replace the visible-workspace query with
  `aerospace list-workspaces --monitor all --empty no --format '%{workspace}|%{monitor-id}'`.
- Focused workspace's monitor comes from
  `aerospace list-workspaces --focused --format '%{workspace}|%{monitor-id}'`.
  The `FOCUSED_WORKSPACE` env var (fast path from the aerospace hook) still
  decides which id gets the highlight and is assumed to live on the focused
  monitor.
- Group visible workspaces (non-empty ∪ focused) by monitor-id ascending,
  numeric sort within each group.
- Desired visual sequence: `mon1 spaces, divider.1, mon2 spaces, divider.2, …`
  — dividers only *between* non-empty groups, so a single monitor renders
  exactly as today.
- Issue one batched call: `--reorder` of the full 33-item block (visible
  sequence first, then hidden spaces and unused dividers, keeping the block
  contiguous between `aero_mode` and `front_app`) plus the existing `--set`
  drawing/highlight toggles, now including divider `drawing`. If mixing
  `--reorder` and `--set` in one invocation misbehaves, fall back to two
  calls: reorder first, then set.

## Stats pills

New `plugins/stats.sh`, sourcing `colors.sh` like every other plugin.

Items in `sketchybarrc`, added after `wifi` in creation order `gpu`, `ram`,
`cpu` → visual left-to-right: `cpu ram gpu wifi volume battery clock`.

- All three: `background.drawing=on`, `click_script="open -a 'Activity
  Monitor'"`. Icons: cpu `󰻠`, ram `󰍛`, gpu `󰢮`.
- Only `cpu` has `update_freq=5` and `script=stats.sh`; the script batch-sets
  all three items each cycle (`ram`/`gpu` have no timers of their own).

Metrics (all sudo-free, verified on this M1 Max):

- **CPU** — `top -l 2 -n 0` second `CPU usage` line, user+sys rounded to an
  integer. The first sample is a since-boot average and is discarded.
- **RAM** — `memory_pressure -Q`: shown as `100 − "System-wide memory free
  percentage"` (the kernel's own availability number; no vm_stat page math).
- **GPU** — `ioreg -r -d 1 -w 0 -c IOAccelerator`, max `"Device Utilization
  %"` across matches. Key absent (non-Apple-GPU machines) → gpu pill sets
  `drawing=off`.

Per-pill `label.color`: `LABEL_COLOR` below 70, `YELLOW` at 70–89, `RED` at
90+. On a parse failure, leave that pill unchanged for the cycle.

## Edge cases

(Stats-related items below are superseded — see the Amendment in the header.)

- **AeroSpace not running:** the existing hide-all branch now also hides the
  dividers.
- **Monitor hot-plug:** `display_change` is already subscribed → regroups.
- **>4 monitors:** groups beyond `divider.3` render unseparated (accepted).
- **launchd PATH/locale:** `stats.sh` sources `colors.sh` like the others;
  `top`, `memory_pressure`, `ioreg` are all in `/usr/bin`–`/usr/sbin`.
- No `aerospace.toml` changes required.

## Verification

(Stats-related items below are superseded — see the Amendment in the header.)

1. One monitor: bar renders identically to before (no dividers).
2. Plug an external monitor: workspaces regroup with a divider; switching
   focus (f8/f10) and clicking items still works; groups follow windows moved
   across monitors.
3. Unplug: divider disappears, flat list returns.
4. `cpu`/`ram`/`gpu` pills show numbers plausible vs Activity Monitor; CPU
   pill goes yellow/red under `yes > /dev/null` load; click opens Activity
   Monitor; on a machine without `Device Utilization %` the gpu pill hides.
5. `brew services restart sketchybar`: everything comes up cleanly from a
   cold start.
