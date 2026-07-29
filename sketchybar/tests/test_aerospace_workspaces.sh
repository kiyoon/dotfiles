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
TEST_REFRESH_MARKER="$TMP/recovery-refresh-now"
TEST_PENDING_MARKER="$TMP/recovery-pending"

fails=0
fail() {
	echo "FAIL: $1"
	fails=$((fails + 1))
}

# $1 = focused "ws|monitor" line, $2 = "ws|monitor" pairs, $3 = window lines
make_stub() {
	cat >"$TMP/aerospace" <<EOF
#!/usr/bin/env bash
if [[ -n "\${AEROSPACE_CALLS:-}" ]]; then
	printf '%s\n' "\$*" >>"\$AEROSPACE_CALLS"
fi
case "\$*" in
	*"--focused"*) printf '%s\n' "$1" ;;
	*"--monitor all"*) printf '%s\n' "$2" ;;
	*"list-windows"*)
		[[ -z "\${AEROSPACE_STUB_DELAY:-}" ]] || sleep "\$AEROSPACE_STUB_DELAY"
		printf '%s\n' "$3"
		;;
esac
EOF
	chmod +x "$TMP/aerospace"
}

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$OUT"
if [[ -n "${SKETCHYBAR_CALLS:-}" ]]; then
	printf '%q ' "$@" >>"$SKETCHYBAR_CALLS"
	printf '\n' >>"$SKETCHYBAR_CALLS"
fi
EOF
chmod +x "$TMP/sketchybar"

cat >"$TMP/monitor-tracker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TRACK_OUT"
EOF
chmod +x "$TMP/monitor-tracker"

run_plugin() {
	export OUT="$TMP/out.txt"
	export AEROSPACE_CALLS="$TMP/aerospace-calls.txt"
	: >"$OUT"
	: >"$AEROSPACE_CALLS"
	AEROSPACE="$TMP/aerospace" SKETCHYBAR="$TMP/sketchybar" \
		AEROSPACE_WORKSPACES_TRACK_MONITOR=0 FOCUSED_WORKSPACE="" \
		AEROSPACE_WORKSPACES_REFRESH_MARKER="$TEST_REFRESH_MARKER" \
		AEROSPACE_WORKSPACES_RECOVERY_PENDING_MARKER="$TEST_PENDING_MARKER" \
		bash "$PLUGIN" --render-now
	flat="$(tr '\n' ' ' <"$OUT")"
	reorder_list="$(awk '/^--reorder$/ { f = 1; next } /^--set$/ { f = 0 } f' "$OUT")"
}

run_event() {
	local focused="$1"
	local sender="${2:-aerospace_workspace_change}"
	local refresh_now="${3:-0}"
	FOCUSED_WORKSPACE="$focused" SENDER="$sender" REFRESH_NOW="$refresh_now" \
		AEROSPACE="$TMP/aerospace" SKETCHYBAR="$TMP/sketchybar" \
		AEROSPACE_CALLS="$AEROSPACE_CALLS" OUT="$OUT" TRACK_OUT="$TRACK_OUT" \
		SKETCHYBAR_CALLS="${SKETCHYBAR_CALLS:-}" \
		AEROSPACE_MONITOR_TRACKER="$TMP/monitor-tracker" \
		AEROSPACE_WORKSPACES_STATE_DIR="$TMP/debounce-state" \
		AEROSPACE_WORKSPACES_REFRESH_MARKER="$TEST_REFRESH_MARKER" \
		AEROSPACE_WORKSPACES_RECOVERY_PENDING_MARKER="$TEST_PENDING_MARKER" \
		AEROSPACE_WORKSPACES_EVENT_COALESCE_SECONDS="${TEST_EVENT_COALESCE_SECONDS:-0.5}" \
		AEROSPACE_WORKSPACES_RECOVERY_FALLBACK_SECONDS="${TEST_RECOVERY_FALLBACK_SECONDS:-0.5}" \
		bash "$PLUGIN"
}

wait_for_render() {
	local tries=0
	while ! grep -qx -- '--reorder' "$OUT" 2>/dev/null && [ "$tries" -lt 40 ]; do
		sleep 0.05
		tries=$((tries + 1))
	done
	# Let the winning renderer and all same-burst stale sleepers fully exit.
	sleep 0.1
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

# ---- Test 6: four monitor groups -> all three dividers, no divider.4 ----
make_stub "1|1" "$(printf '1|1\n2|2\n3|3\n4|4')" ""
run_plugin

expected_head="$(printf 'space.1\ndivider.1\nspace.2\ndivider.2\nspace.3\ndivider.3\nspace.4')"
[ "$(printf '%s\n' "$reorder_list" | head -7)" = "$expected_head" ] ||
	fail "four-group reorder sequence, got: $(printf '%s' "$reorder_list" | head -7 | tr '\n' ' ')"
[ "$(printf '%s\n' "$reorder_list" | wc -l | tr -d ' ')" = "33" ] ||
	fail "four-group reorder block must name all 33 items"
[ "$(printf '%s\n' "$reorder_list" | grep -cx 'divider.3')" = "1" ] ||
	fail "divider.3 must appear exactly once in reorder"
grep -q 'divider\.4' "$OUT" && fail "nonexistent divider.4 must never be referenced"
[[ "$flat" == *"--set divider.1 drawing=on"* && "$flat" == *"--set divider.2 drawing=on"* &&
	"$flat" == *"--set divider.3 drawing=on"* ]] || fail "all three dividers must draw with four groups"
[[ "$flat" == *"--set divider.3 drawing=off"* ]] && fail "divider.3 must not be re-hidden in the same call"

# ---- Test 7: rapid events collapse into one render; latest focus wins ----
make_stub "1|1" "$(printf '1|1')" ""
export OUT="$TMP/debounce-out.txt"
export AEROSPACE_CALLS="$TMP/debounce-aerospace-calls.txt"
export TRACK_OUT="$TMP/debounce-track-calls.txt"
export SKETCHYBAR_CALLS="$TMP/debounce-sketchybar-calls.txt"
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"

run_event 1
run_event 2
run_event 3

[ ! -s "$AEROSPACE_CALLS" ] || fail "burst must not query AeroSpace before the quiet period"
[ ! -s "$TRACK_OUT" ] || fail "burst must not track a monitor before the quiet period"
[ "$(wc -l <"$SKETCHYBAR_CALLS" | tr -d ' ')" = "3" ] ||
	fail "each focus event must update SketchyBar immediately"
grep -qx -- '--reorder' "$OUT" &&
	fail "focus event must not fully render before the quiet period"
last_fast_call="$(tail -1 "$SKETCHYBAR_CALLS")"
[[ "$last_fast_call" == *"--set space.3 drawing=on background.color=$ACCENT_COLOR"* ]] ||
	fail "last immediate focus event must highlight space.3"
[[ "$last_fast_call" == *"icon.color=$BG_DARK label.color=$BG_DARK"* ]] ||
	fail "focused workspace must use readable accent text colors"
[[ "$last_fast_call" == *"background.color=$ITEM_BG_COLOR icon.color=$LABEL_COLOR label.color=$LABEL_COLOR"* ]] ||
	fail "immediate focus event must clear stale accents"

# SketchyBar compiles selectors as POSIX basic regex. Verify the actual
# selector emitted by the plugin matches numeric space items without relying
# on ERE-only operators such as an unescaped '+'.
space_selector="$(grep -m1 '^/\^space' "$OUT" || true)"
space_bre="${space_selector#/}"
space_bre="${space_bre%/}"
printf '%s\n' space.1 space.30 | grep -q "$space_bre" ||
	fail "focus reset selector must match numeric workspace items"
if printf '%s\n' divider.1 space.foo | grep -q "$space_bre"; then
	fail "focus reset selector must reject non-workspace items"
fi

wait_for_render

[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] || fail "burst must render exactly once"
[ "$(wc -l <"$AEROSPACE_CALLS" | tr -d ' ')" = "3" ] || fail "winning render must make exactly three AeroSpace queries"
[ "$(grep -c -- 'list-workspaces --focused' "$AEROSPACE_CALLS" || true)" = "1" ] || fail "focused workspace must be queried once"
[ "$(grep -c -- 'list-workspaces --monitor all' "$AEROSPACE_CALLS" || true)" = "1" ] || fail "visible workspaces must be queried once"
[ "$(grep -c -- 'list-windows --all' "$AEROSPACE_CALLS" || true)" = "1" ] || fail "windows must be queried once"
[ "$(grep -cx -- 'track' "$TRACK_OUT" || true)" = "1" ] || fail "burst must track the monitor exactly once"
debounce_flat="$(tr '\n' ' ' <"$OUT")"
[[ "$debounce_flat" == *"--set space.3 drawing=on background.color=$ACCENT_COLOR"* ]] ||
	fail "the last event's focused workspace must win"

# A later event starts a fresh debounce cycle rather than being lost to stale
# token cleanup from the first burst.
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
run_event 4
[ ! -s "$AEROSPACE_CALLS" ] || fail "later event must also wait for its quiet period"
[ "$(wc -l <"$SKETCHYBAR_CALLS" | tr -d ' ')" = "1" ] ||
	fail "later focus event must update SketchyBar immediately"
wait_for_render
[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] || fail "later event must render exactly once"
[ "$(wc -l <"$AEROSPACE_CALLS" | tr -d ' ')" = "3" ] || fail "later render must make exactly three AeroSpace queries"
[ "$(grep -cx -- 'track' "$TRACK_OUT" || true)" = "1" ] || fail "later event must track the monitor exactly once"

# ---- Test 8: startup recovery refresh bypasses the routine debounce ----
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
printf 'recovery-8\n' >"$TEST_REFRESH_MARKER"
printf 'recovery-8\n' >"$TEST_PENDING_MARKER"
TEST_EVENT_COALESCE_SECONDS=5 run_event "" aerospace_started

tries=0
while ! grep -qx -- '--reorder' "$OUT" 2>/dev/null && [ "$tries" -lt 20 ]; do
	sleep 0.05
	tries=$((tries + 1))
done
[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] ||
	fail "recovery startup event must render without the five-second debounce"
[ "$(wc -l <"$AEROSPACE_CALLS" | tr -d ' ')" = "3" ] ||
	fail "recovery startup event must make one complete query set"
[ ! -e "$TEST_REFRESH_MARKER" ] ||
	fail "recovery startup event must consume its one-shot refresh marker"
[ ! -e "$TEST_PENDING_MARKER" ] ||
	fail "recovery startup event must clear the recovery-pending marker"

# A startup event from an older recovery generation must not clear the newer
# hazard or perform an immediate query.
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
printf 'old-recovery\n' >"$TEST_REFRESH_MARKER"
printf 'new-recovery\n' >"$TEST_PENDING_MARKER"
TEST_RECOVERY_FALLBACK_SECONDS=0.5 run_event "" aerospace_started
[ ! -s "$AEROSPACE_CALLS" ] ||
	fail "stale startup handshake must not query AeroSpace immediately"
[ "$(cat "$TEST_PENDING_MARKER")" = "new-recovery" ] ||
	fail "stale startup handshake must preserve the newer recovery generation"
wait_for_render
[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] ||
	fail "newer recovery generation must eventually use its safe fallback"

# ---- Test 9: active-display changes are fast; wake/topology recovery is held ----
make_stub "2|2" "$(printf '1|1\n2|2')" "2|WezTerm"
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
TEST_EVENT_COALESCE_SECONDS=0.05 run_event "" display_change
# This is the exact event order produced by a focus-following monitor move:
# SketchyBar changes active display, then monitor.sh requests a final snapshot.
TEST_RECOVERY_FALLBACK_SECONDS=0.6 run_event 2 aerospace_workspace_change 1

[ ! -e "$TEST_PENDING_MARKER" ] ||
	fail "active display_change must not enter topology recovery"
wait_for_render

[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] ||
	fail "active display move plus REFRESH_NOW must perform one prompt full render"
[ "$(wc -l <"$AEROSPACE_CALLS" | tr -d ' ')" = "3" ] ||
	fail "active display move must make one complete query set"
grep -qx 'label=:wezterm:' "$OUT" ||
	fail "prompt post-move render must include WezTerm on its final workspace"

# Wake is a genuine recovery hazard: Hammerspoon deliberately schedules a
# topology restart even when screen notifications were missed during sleep.
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
run_event "" system_woke

[ ! -s "$OUT" ] || fail "system_woke must not update workspace items before recovery settles"
[ ! -s "$AEROSPACE_CALLS" ] || fail "system_woke must not query AeroSpace before recovery settles"
[ ! -s "$TRACK_OUT" ] || fail "system_woke must not track a monitor before recovery settles"
[ -e "$TEST_PENDING_MARKER" ] ||
	fail "system_woke must mark recovery pending"

# A later routine event must preserve, rather than shorten, that recovery hold.
TEST_EVENT_COALESCE_SECONDS=0 run_event 8 space_windows_change
[ ! -s "$AEROSPACE_CALLS" ] ||
	fail "routine event during display recovery must not query AeroSpace immediately"
run_event "" forced
[ ! -s "$AEROSPACE_CALLS" ] ||
	fail "forced event during display recovery must not query AeroSpace immediately"
wait_for_render
[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] ||
	fail "system_woke must eventually perform one full render"
[ ! -e "$TEST_PENDING_MARKER" ] ||
	fail "the winning recovery fallback must consume its pending generation"

# A normal worker armed just before Hammerspoon marks a topology hazard must
# recheck the marker before its first query.
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
TEST_EVENT_COALESCE_SECONDS=0.2 run_event "" space_windows_change
printf 'hammerspoon-hazard\n' >"$TEST_PENDING_MARKER"
sleep 0.35
[ ! -s "$AEROSPACE_CALLS" ] ||
	fail "healthy worker must abort if recovery becomes pending before it starts"
[ ! -s "$OUT" ] ||
	fail "aborted healthy worker must not commit a bar snapshot"
rm -f "$TEST_PENDING_MARKER"

# ---- Test 10: an in-progress stale snapshot cannot overwrite newer focus ----
make_stub "1|1" "$(printf '1|1\n2|1')" ""
: >"$OUT"
: >"$AEROSPACE_CALLS"
: >"$TRACK_OUT"
: >"$SKETCHYBAR_CALLS"
mkdir -p "$TMP/debounce-state"
printf 'old-render\n' >"$TMP/debounce-state/aerospace-workspaces.generation"

FOCUSED_WORKSPACE=1 SENDER=aerospace_workspace_change \
	AEROSPACE_STUB_DELAY=0.3 \
	AEROSPACE="$TMP/aerospace" SKETCHYBAR="$TMP/sketchybar" \
	AEROSPACE_CALLS="$AEROSPACE_CALLS" OUT="$OUT" TRACK_OUT="$TRACK_OUT" \
	SKETCHYBAR_CALLS="$SKETCHYBAR_CALLS" \
	AEROSPACE_MONITOR_TRACKER="$TMP/monitor-tracker" \
	AEROSPACE_WORKSPACES_STATE_DIR="$TMP/debounce-state" \
	AEROSPACE_WORKSPACES_REFRESH_MARKER="$TEST_REFRESH_MARKER" \
	bash "$PLUGIN" --render-if-current old-render &
stale_pid=$!

tries=0
while ! grep -q -- 'list-windows --all' "$AEROSPACE_CALLS" 2>/dev/null && [ "$tries" -lt 20 ]; do
	sleep 0.02
	tries=$((tries + 1))
done
TEST_EVENT_COALESCE_SECONDS=0.1 run_event 2
wait "$stale_pid"
wait_for_render
sleep 0.2

[ "$(grep -cx -- '--reorder' "$OUT" || true)" = "1" ] ||
	fail "new event must prevent stale in-progress snapshot from committing"
stale_flat="$(tr '\n' ' ' <"$OUT")"
[[ "$stale_flat" == *"--set space.2 drawing=on background.color=$ACCENT_COLOR"* ]] ||
	fail "newer focus must remain highlighted after stale snapshot exits"
last_snapshot="$(tail -1 "$SKETCHYBAR_CALLS")"
[[ "$last_snapshot" == *"--set space.1 drawing=on background.color=$ACCENT_COLOR"* ]] ||
	fail "full renderer must use its fresh focus query, not inherited event focus"

grep -q 'monitor\.sh track' "$CONFIG_DIR/../aerospace/aerospace.toml" &&
	fail "AeroSpace callback must not track immediately outside the debounce gate"

if [ "$fails" -eq 0 ]; then
	echo "PASS: all assertions"
else
	echo "$fails assertion(s) failed"
	exit 1
fi
