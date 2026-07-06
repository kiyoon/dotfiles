# SketchyBar Per-Monitor Workspace Groups + CPU/RAM/GPU Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Group the AeroSpace workspace items in SketchyBar by monitor with thin dividers between groups, and add CPU / RAM / GPU usage pills to the right side of the bar.

**Architecture:** Keep the existing `space.1..30` identity items; the listener plugin groups them per monitor via `aerospace … --format '%{workspace}|%{monitor-id}'` and one batched `sketchybar --reorder … --set …` call (verified: named items rearrange within their occupied slots; `--reorder` and `--set` combine in one invocation). Three new right-side items (`cpu`, `ram`, `gpu`) are driven by a single `stats.sh` on the `cpu` item's 5-second timer. Plugins are unit-tested by stubbing the `aerospace`/`sketchybar` binaries via env-var overrides (same pattern as `aerospace/scripts/workspace.sh`'s `AEROSPACE` var). (Stats architecture superseded — see Task 2 banner.)

**Tech Stack:** bash (macOS `/bin/bash` 3.2-compatible), SketchyBar CLI, AeroSpace CLI, BSD userland (`top`, `memory_pressure`, `ioreg`, `awk`).

**Spec:** `docs/superpowers/specs/2026-07-06-sketchybar-monitor-groups-stats-design.md`

## Global Constraints

- **Live config:** `~/.config/sketchybar` is a symlink into this repo (`symlink.sh:48`), so file edits + `sketchybar --reload` apply immediately. SketchyBar is running under `brew services`.
- **Bash 3.2:** plugins run via `#!/usr/bin/env bash`; no bash-4+ features (no associative arrays, no `${var,,}`).
- **Indentation:** tabs, matching the existing `sketchybar/` files.
- **launchd PATH/locale:** every plugin sources `$CONFIG_DIR/colors.sh` first (exports PATH and a French `LANG`). Any numeric text parsing in plugins MUST force `LC_ALL=C` on the parsing command.
- **Item names (exact):** `divider.1` `divider.2` `divider.3`, `cpu`, `ram`, `gpu`.
- **Color thresholds (exact):** `label.color` = `LABEL_COLOR` below 70, `YELLOW` at 70–89, `RED` at 90+.
- **SUPERSEDED (stats only):** the two bullets above about stats thresholds do not bind — see Task 2's superseded banner; the adopted cpu.sh/gpu.sh/ram.sh use 60/80.
- **No `aerospace/aerospace.toml` changes.**
- Workspace ids outside 1..30 have no bar item and must be skipped (pre-existing v1 behavior).
- Single monitor must render with zero dividers (visually identical to today).

---

### Task 1: Per-monitor workspace grouping with dividers

**Files:**
- Create: `sketchybar/tests/test_aerospace_workspaces.sh`
- Modify: `sketchybar/sketchybarrc` (after the space-items block, line ~78)
- Modify: `sketchybar/plugins/aerospace_workspaces.sh` (full rewrite shown below)

**Interfaces:**
- Consumes: existing items `space.1..30` and events from the current `sketchybarrc`; `aerospace list-workspaces --focused|--monitor all` `--format '%{workspace}|%{monitor-id}'`.
- Produces: items `divider.1..3` (hidden by default); plugin env overrides `AEROSPACE` / `SKETCHYBAR` (default `aerospace` / `sketchybar`) that Task 2's test harness pattern reuses.

- [ ] **Step 1: Write the failing test**

Create `sketchybar/tests/test_aerospace_workspaces.sh` (mode 755):

```bash
#!/usr/bin/env bash
# Unit test for plugins/aerospace_workspaces.sh.
# Stubs the aerospace + sketchybar binaries (via the plugin's AEROSPACE /
# SKETCHYBAR overrides) and asserts on the exact argument stream the plugin
# sends to sketchybar. Run: bash sketchybar/tests/test_aerospace_workspaces.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
export CONFIG_DIR
PLUGIN="$CONFIG_DIR/plugins/aerospace_workspaces.sh"
source "$CONFIG_DIR/colors.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() {
	echo "FAIL: $1"
	fails=$((fails + 1))
}

# $1 = focused "ws|monitor" line, $2 = "ws|monitor" pairs, $3 = window lines
make_stub() {
	cat >"$TMP/aerospace" <<EOF
#!/usr/bin/env bash
case "\$*" in
	*"--focused"*) printf '%s\n' "$1" ;;
	*"--monitor all"*) printf '%s\n' "$2" ;;
	*"list-windows"*) printf '%s\n' "$3" ;;
esac
EOF
	chmod +x "$TMP/aerospace"
}

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$OUT"
EOF
chmod +x "$TMP/sketchybar"

run_plugin() {
	export OUT="$TMP/out.txt"
	: >"$OUT"
	AEROSPACE="$TMP/aerospace" SKETCHYBAR="$TMP/sketchybar" \
		FOCUSED_WORKSPACE="" bash "$PLUGIN"
	flat="$(tr '\n' ' ' <"$OUT")"
	reorder_list="$(awk '/^--reorder$/ { f = 1; next } /^--set$/ { f = 0 } f' "$OUT")"
}

# ---- Test 1: three monitors, interleaved workspace numbers ----
# mon 1: 1,4  mon 2: 3,7 (3 focused)  mon 3: 5
make_stub "3|2" "$(printf '4|1\n1|1\n3|2\n7|2\n5|3')" "$(printf '1|Firefox\n3|WezTerm')"
run_plugin

expected_head="$(printf 'space.1\nspace.4\ndivider.1\nspace.3\nspace.7\ndivider.2\nspace.5')"
[ "$(printf '%s\n' "$reorder_list" | head -7)" = "$expected_head" ] ||
	fail "multi-monitor reorder sequence, got: $(printf '%s' "$reorder_list" | head -7 | tr '\n' ' ')"
[ "$(printf '%s\n' "$reorder_list" | wc -l | tr -d ' ')" = "33" ] ||
	fail "reorder block must name all 33 items"
[[ "$flat" == *"--set divider.1 drawing=on"* ]] || fail "divider.1 should draw"
[[ "$flat" == *"--set divider.2 drawing=on"* ]] || fail "divider.2 should draw"
[[ "$flat" == *"--set divider.3 drawing=off"* ]] || fail "divider.3 should hide"
[[ "$flat" == *"--set space.3 drawing=on background.color=$ACCENT_COLOR"* ]] ||
	fail "focused space.3 should get accent background"
[[ "$flat" == *"--set space.2 drawing=off"* ]] || fail "space.2 should hide"

# ---- Test 2: single monitor -> no dividers, numeric order ----
make_stub "1|1" "$(printf '5|1\n1|1\n3|1')" ""
run_plugin

expected_head="$(printf 'space.1\nspace.3\nspace.5')"
[ "$(printf '%s\n' "$reorder_list" | head -3)" = "$expected_head" ] ||
	fail "single-monitor reorder sequence, got: $(printf '%s' "$reorder_list" | head -3 | tr '\n' ' ')"
[[ "$flat" != *"drawing=on"*"divider"* && "$flat" == *"--set divider.1 drawing=off"* &&
	"$flat" == *"--set divider.2 drawing=off"* && "$flat" == *"--set divider.3 drawing=off"* ]] ||
	fail "single monitor must hide all dividers"

# ---- Test 3: focused workspace empty (not in --empty no list) ----
# Empty focused ws 9 on mon 2 must still show, grouped on mon 2.
make_stub "9|2" "$(printf '1|1\n2|2')" ""
run_plugin

expected_head="$(printf 'space.1\ndivider.1\nspace.2\nspace.9')"
[ "$(printf '%s\n' "$reorder_list" | head -4)" = "$expected_head" ] ||
	fail "empty focused ws grouping, got: $(printf '%s' "$reorder_list" | head -4 | tr '\n' ' ')"

# ---- Test 4: aerospace not running -> everything hidden, no reorder ----
make_stub "" "" ""
run_plugin

grep -qx -- '--reorder' "$OUT" && fail "dead aerospace must not reorder"
[[ "$flat" == *"--set space.1 drawing=off"* ]] || fail "dead aerospace must hide spaces"
[[ "$flat" == *"--set divider.1 drawing=off"* ]] || fail "dead aerospace must hide dividers"

# ---- Test 5: workspace id outside 1..30 (date +%s fallback) is skipped ----
make_stub "1761234567|1" "$(printf '1|1')" ""
run_plugin

printf '%s\n' "$reorder_list" | grep -q 'space.1761234567' &&
	fail "ids outside 1..30 must not be referenced"

if [ "$fails" -eq 0 ]; then
	echo "PASS: all assertions"
else
	echo "$fails assertion(s) failed"
	exit 1
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash sketchybar/tests/test_aerospace_workspaces.sh`
Expected: FAIL lines (current plugin issues no `--reorder`, never touches `divider.*`), exit 1. E.g. `FAIL: multi-monitor reorder sequence, got:` and `FAIL: divider.1 should draw`.

- [ ] **Step 3: Add divider items to `sketchybar/sketchybarrc`**

Insert directly after the `sketchybar "${space_args[@]}"` line (~line 78), before the listener block:

```bash
# Thin separators between per-monitor workspace groups (multi-monitor only).
# The listener's --reorder positions them; single monitor keeps them hidden.
divider_args=()
for d in 1 2 3; do
	divider_args+=(
		--add item "divider.$d" left
		--set "divider.$d"
		drawing=off
		icon="│"
		icon.color=$MUTED_COLOR
		icon.padding_left=2
		icon.padding_right=2
		label.drawing=off
	)
done
sketchybar "${divider_args[@]}"
```

- [ ] **Step 4: Rewrite `sketchybar/plugins/aerospace_workspaces.sh`**

Full new content:

```bash
#!/usr/bin/env bash
# Toggle visibility/highlight of the pre-created space.1..30 items, group them
# by monitor (divider.1..3 between groups, positioned via --reorder), and
# render each visible workspace's app icons (sketchybar-app-font ligatures) so
# the bar is a live map of what's where.
# Visible = non-empty workspaces (all monitors) + the focused one.
# Runs on: aerospace_workspace_change (FOCUSED_WORKSPACE env from aerospace),
# forced, system_woke, display_change, space_windows_change.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

AEROSPACE="${AEROSPACE:-aerospace}"
SKETCHYBAR="${SKETCHYBAR:-sketchybar}"

if ! command -v "$AEROSPACE" >/dev/null 2>&1; then
	exit 0
fi

hide_all() {
	local args=() sid d
	for sid in $(seq 1 30); do
		args+=(--set "space.$sid" drawing=off)
	done
	for d in 1 2 3; do
		args+=(--set "divider.$d" drawing=off)
	done
	"$SKETCHYBAR" "${args[@]}"
}

# Focused workspace and its monitor. The FOCUSED_WORKSPACE env var (fast path
# from aerospace's exec-on-workspace-change) wins for the id and is assumed to
# live on the focused monitor.
focused_line="$("$AEROSPACE" list-workspaces --focused --format '%{workspace}|%{monitor-id}' 2>/dev/null)"
focused="${FOCUSED_WORKSPACE:-${focused_line%%|*}}"
focused_monitor="${focused_line##*|}"

# AeroSpace not running: hide everything.
if [[ -z "$focused" ]]; then
	hide_all
	exit 0
fi

# workspace|monitor-id pairs for every workspace that should be visible.
pairs="$("$AEROSPACE" list-workspaces --monitor all --empty no --format '%{workspace}|%{monitor-id}' 2>/dev/null)"
if [[ -z "$pairs" ]]; then
	pairs="$focused|${focused_monitor:-1}"
elif ! grep -q "^$focused|" <<<"$pairs"; then
	pairs+=$'\n'"$focused|${focused_monitor:-1}"
fi

windows="$("$AEROSPACE" list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)"

app_icons() {
	local sid="$1" app out=""
	while IFS= read -r app; do
		[[ -z "$app" ]] && continue
		icon_result=":default:"
		__icon_map "$app"
		out+="$icon_result "
	done < <(awk -F'|' -v ws="$sid" '$1 == ws { print substr($0, index($0, "|") + 1) }' <<<"$windows")
	printf '%s' "${out% }"
}

# Group by monitor: monitors ascending, workspaces numeric within each group.
# order = item names in the desired visual sequence, dividers between groups.
# Ids outside 1..30 have no bar item (date +%s fallback) and are skipped.
order=()
vis_lines=""
args=()
d=0
for mon in $(cut -d'|' -f2 <<<"$pairs" | sort -n | uniq); do
	group="$(awk -F'|' -v m="$mon" '$2 == m && $1 ~ /^[0-9]+$/ && $1 >= 1 && $1 <= 30 { print $1 }' <<<"$pairs" | sort -n | uniq)"
	[[ -z "$group" ]] && continue
	if (( ${#order[@]} > 0 && d < 3 )); then
		d=$((d + 1))
		order+=("divider.$d")
		args+=(--set "divider.$d" drawing=on)
	fi
	for sid in $group; do
		order+=("space.$sid")
		vis_lines+="$sid"$'\n'
	done
done
for dd in $(seq $((d + 1)) 3); do
	args+=(--set "divider.$dd" drawing=off)
done

# Nothing visible (e.g. only an out-of-range focused id): treat as hidden bar.
if (( ${#order[@]} == 0 )); then
	hide_all
	exit 0
fi

for sid in $(seq 1 30); do
	if grep -Fxq "$sid" <<<"$vis_lines"; then
		icons="$(app_icons "$sid")"
		if [[ -n "$icons" ]]; then
			label_args=(label="$icons" label.drawing=on)
		else
			label_args=(label.drawing=off)
		fi
		if [[ "$sid" == "$focused" ]]; then
			args+=(--set "space.$sid" drawing=on
				background.color="$ACCENT_COLOR"
				icon.color="$BG_DARK" label.color="$BG_DARK"
				"${label_args[@]}")
		else
			args+=(--set "space.$sid" drawing=on
				background.color="$ITEM_BG_COLOR"
				icon.color="$LABEL_COLOR" label.color="$LABEL_COLOR"
				"${label_args[@]}")
		fi
	else
		args+=(--set "space.$sid" drawing=off)
	fi
done

# One batched call. The reorder block names all 33 items (visible sequence
# first, then hidden spaces and unused dividers) so the space/divider block
# stays contiguous and deterministic between aero_mode and front_app.
reorder=("${order[@]}")
for sid in $(seq 1 30); do
	grep -Fxq "$sid" <<<"$vis_lines" || reorder+=("space.$sid")
done
for dd in $(seq $((d + 1)) 3); do
	reorder+=("divider.$dd")
done

"$SKETCHYBAR" --reorder "${reorder[@]}" "${args[@]}"
```

Note for Test 5: with only out-of-range ids visible, `order` stays empty and the plugin takes the `hide_all` early-exit, so no `--reorder` references `space.1761234567` — but Test 5's stub also lists `1|1`, so the normal path runs and simply omits the bogus id.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash sketchybar/tests/test_aerospace_workspaces.sh`
Expected: `PASS: all assertions`, exit 0.

- [ ] **Step 6: Reload the live bar and verify single-monitor behavior is unchanged**

```bash
sketchybar --reload
sleep 2
sketchybar --trigger aerospace_workspace_change
sleep 1
# divider items exist and are hidden
sketchybar --query divider.1 | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('geometry', d).get('drawing'))"
# every non-empty workspace is drawn
for sid in $(aerospace list-workspaces --monitor all --empty no); do
	state="$(sketchybar --query space.$sid | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('geometry', d).get('drawing'))")"
	echo "space.$sid drawing=$state"
done
# spaces still numerically ordered in the bar
sketchybar --query bar | python3 -c "
import json,sys
items=[i for i in json.load(sys.stdin)['items'] if i.startswith('space.')]
print('order ok:', items==sorted(items, key=lambda s:int(s.split('.')[1])))"
```

Expected: `divider.1` → `off`; each listed `space.N drawing=on`; `order ok: True`. Visually: bar looks exactly as before (workspace switching with f8/f10 still highlights correctly).

- [ ] **Step 7: Commit**

```bash
git add sketchybar/tests/test_aerospace_workspaces.sh sketchybar/sketchybarrc sketchybar/plugins/aerospace_workspaces.sh
git commit -m "feat(sketchybar): group aerospace workspaces by monitor with dividers"
```

Multi-monitor visual verification (plug in an external display, confirm the divider appears between groups and hot-unplug regroups) is deferred to the user — no external monitor is attached in this session.

---

### Task 2: CPU / RAM / GPU pills

> **SUPERSEDED — do not execute.** A parallel implementation
> (`plugins/cpu.sh`, `plugins/gpu.sh`, `plugins/ram.sh` + rc items) was
> built outside this plan and adopted verbatim by user decision on
> 2026-07-06. This task is retained for reference only; the adoption commit
> covers what remained (committing the referenced scripts).

**Files:**
- Create: `sketchybar/tests/test_stats.sh`
- Create: `sketchybar/plugins/stats.sh`
- Modify: `sketchybar/sketchybarrc` (after the `wifi` block, before `# ---- Finalize ----`)

**Interfaces:**
- Consumes: `colors.sh` palette (`LABEL_COLOR`, `YELLOW`, `RED`); `SKETCHYBAR` env-override pattern from Task 1.
- Produces: items `cpu`, `ram`, `gpu`; `plugins/stats.sh` batch-setting all three each cycle.

- [ ] **Step 1: Write the failing test**

Create `sketchybar/tests/test_stats.sh` (mode 755):

```bash
#!/usr/bin/env bash
# Unit test for plugins/stats.sh: stub sketchybar, run the real metric
# commands, assert label shape and threshold->color consistency.
# Run: bash sketchybar/tests/test_stats.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
export CONFIG_DIR
source "$CONFIG_DIR/colors.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() {
	echo "FAIL: $1"
	fails=$((fails + 1))
}

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$OUT"
EOF
chmod +x "$TMP/sketchybar"

export OUT="$TMP/out.txt"
: >"$OUT"
SKETCHYBAR="$TMP/sketchybar" bash "$CONFIG_DIR/plugins/stats.sh"

# get_field <item> <field> -> value of "field=..." following "--set <item>"
get_field() {
	awk -v it="$1" -v f="$2" '
		$0 == "--set" { getline cur; next }
		cur == it && index($0, f "=") == 1 { print substr($0, length(f) + 2) }
	' "$OUT"
}

expect_color() {
	if (( $1 >= 90 )); then
		printf '%s' "$RED"
	elif (( $1 >= 70 )); then
		printf '%s' "$YELLOW"
	else
		printf '%s' "$LABEL_COLOR"
	fi
}

check_metric() {
	local item="$1" label val color
	label="$(get_field "$item" label)"
	[[ "$label" =~ ^[0-9]+%$ ]] || { fail "$item label '$label' not 'NN%'"; return; }
	val="${label%\%}"
	(( val >= 0 && val <= 100 )) || fail "$item value $val out of range"
	color="$(get_field "$item" label.color)"
	[ "$color" = "$(expect_color "$val")" ] ||
		fail "$item color $color wrong for value $val"
}

check_metric cpu
check_metric ram

# GPU: either a valid metric (Apple GPU present) or an explicit drawing=off.
if [ "$(get_field gpu drawing)" = "off" ]; then
	echo "note: gpu hidden (no Device Utilization key on this machine)"
else
	check_metric gpu
fi

if [ "$fails" -eq 0 ]; then
	echo "PASS: all assertions"
else
	echo "$fails assertion(s) failed"
	exit 1
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash sketchybar/tests/test_stats.sh`
Expected: FAIL — `bash: .../plugins/stats.sh: No such file or directory`, then `FAIL: cpu label '' not 'NN%'` etc., exit 1.

- [ ] **Step 3: Write `sketchybar/plugins/stats.sh`**

```bash
#!/usr/bin/env bash
# One driver for the cpu/ram/gpu pills: the cpu item's update_freq timer runs
# this; it gathers all metrics in one pass and batch-sets all three items.
# colors.sh exports a user LANG, so numeric parsing forces LC_ALL=C.

source "$CONFIG_DIR/colors.sh"

SKETCHYBAR="${SKETCHYBAR:-sketchybar}"

level_color() {
	if (( $1 >= 90 )); then
		printf '%s' "$RED"
	elif (( $1 >= 70 )); then
		printf '%s' "$YELLOW"
	else
		printf '%s' "$LABEL_COLOR"
	fi
}

args=()

# CPU: user+sys from the second top sample (the first is a since-boot average).
cpu="$(top -l 2 -n 0 -s 1 | LC_ALL=C awk -F'[:,%]+' '
	/^CPU usage/ { u = $2; s = $4 }
	END { if (u != "") printf "%.0f", u + s }')"
if [[ "$cpu" =~ ^[0-9]+$ ]]; then
	args+=(--set cpu label="${cpu}%" label.color="$(level_color "$cpu")")
fi

# RAM: 100 - the kernel's own free percentage (no vm_stat page math).
ram_free="$(memory_pressure -Q | LC_ALL=C awk -F': *|%' '
	/System-wide memory free percentage/ { print $2 }')"
if [[ "$ram_free" =~ ^[0-9]+$ ]]; then
	ram=$((100 - ram_free))
	args+=(--set ram label="${ram}%" label.color="$(level_color "$ram")")
fi

# GPU: Apple GPUs expose utilization in IOAccelerator; absent -> hide the pill.
gpu="$(ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null |
	grep -o '"Device Utilization %"=[0-9]*' | cut -d= -f2 | sort -nr | head -1)"
if [[ "$gpu" =~ ^[0-9]+$ ]]; then
	args+=(--set gpu drawing=on label="${gpu}%" label.color="$(level_color "$gpu")")
else
	args+=(--set gpu drawing=off)
fi

if (( ${#args[@]} > 0 )); then
	"$SKETCHYBAR" "${args[@]}"
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash sketchybar/tests/test_stats.sh`
Expected: `PASS: all assertions` (on this M1 Max the gpu branch is exercised as a real metric), exit 0. Takes ~1.5s (top's two samples).

- [ ] **Step 5: Add the items to `sketchybar/sketchybarrc`**

Insert after the `wifi` block, before `# ---- Finalize ----`. Creation order `gpu, ram, cpu` puts them visually left of wifi as `cpu ram gpu | wifi volume battery clock` (right items stack leftward):

```bash
# ---- CPU / RAM / GPU (one driver: cpu's timer batch-updates all three) ----
sketchybar --add item gpu right \
	--set gpu \
	drawing=off \
	icon=󰢮 \
	label="…" \
	background.drawing=on \
	click_script="open -a 'Activity Monitor'"

sketchybar --add item ram right \
	--set ram \
	icon=󰍛 \
	label="…" \
	background.drawing=on \
	click_script="open -a 'Activity Monitor'"

sketchybar --add item cpu right \
	--set cpu \
	update_freq=5 \
	icon=󰻠 \
	label="…" \
	background.drawing=on \
	click_script="open -a 'Activity Monitor'" \
	script="$PLUGIN_DIR/stats.sh" \
	--subscribe cpu forced system_woke
```

(`gpu` starts `drawing=off` so machines without the ioreg key never flash an empty pill; `stats.sh` turns it on. The `forced` subscription makes the rc's final `sketchybar --update` populate the pills immediately instead of waiting for the first 5s tick.)

- [ ] **Step 6: Reload the live bar and verify**

```bash
sketchybar --reload
sleep 4
for it in cpu ram gpu; do
	sketchybar --query $it | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('$it', d.get('geometry', d).get('drawing'), d['label']['value'])"
done
```

Expected: three lines like `cpu on 23%` / `ram on 13%` / `gpu on 8%` — values plausible vs Activity Monitor, visually left of the wifi item. Optional load check: run `yes >/dev/null &` for ~15s, cpu label climbs and turns yellow/red per thresholds; `kill %1`.

- [ ] **Step 7: Cold-start verification (covers Task 1 + 2)**

```bash
brew services restart sketchybar
sleep 6
bash sketchybar/tests/test_aerospace_workspaces.sh && bash sketchybar/tests/test_stats.sh
sketchybar --query bar | python3 -c "
import json,sys
items=json.load(sys.stdin)['items']
print('dividers:', [i for i in items if i.startswith('divider.')])
print('stats:', [i for i in items if i in ('cpu','ram','gpu')])"
```

Expected: both tests PASS; `dividers: ['divider.1', 'divider.2', 'divider.3']`; `stats: ['gpu', 'ram', 'cpu']`; bar renders correctly from a cold start (workspaces highlighted, stat pills populated within ~6s).

- [ ] **Step 8: Commit**

```bash
git add sketchybar/tests/test_stats.sh sketchybar/plugins/stats.sh sketchybar/sketchybarrc
git commit -m "feat(sketchybar): add cpu/ram/gpu usage pills"
```
