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
