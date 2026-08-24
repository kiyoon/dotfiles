#!/usr/bin/env bash
# Unit tests for the battery-limit renderer/click handler and their SketchyBar
# wiring. PowerUI itself is covered separately by test_battery_limit_helper.sh.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
export CONFIG_DIR
# shellcheck source=colors.sh
source "$CONFIG_DIR/colors.sh"
RENDERER="$CONFIG_DIR/plugins/battery.sh"
CLICK_HANDLER="$CONFIG_DIR/plugins/battery_limit_click.sh"
RC="$CONFIG_DIR/sketchybarrc"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/limit"
CALLS="$TMP/sketchybar-calls"
SET_CALLS="$TMP/helper-set-calls"
LOG="$TMP/click.log"

fails=0
fail() {
	printf 'FAIL: %s\n' "$1"
	fails=$((fails + 1))
}

assert_calls_contain() {
	local expected="$1"
	local message="$2"
	grep -Fq -- "$expected" "$CALLS" || fail "$message"
}

cat >"$TMP/battery-helper" <<'EOF'
#!/usr/bin/env bash
set -u

case "${1:-status}" in
status)
	[[ "${TEST_FAIL_STATUS:-0}" != 1 ]] || exit 1
	limit="$(<"$BATTERY_LIMIT_TEST_STATE")"
	printf 'limit=%s mcl=%s optimized=%s\n' \
		"$limit" "${TEST_MCL:-1}" "${TEST_OPTIMIZED:-1}"
	;;
set)
	[[ "${TEST_FAIL_SET:-0}" != 1 ]] || exit 1
	printf '%s\n' "$2" >>"$BATTERY_LIMIT_TEST_SET_CALLS"
	printf '%s\n' "$2" >"$BATTERY_LIMIT_TEST_STATE"
	printf 'limit=%s mcl=1 optimized=1\n' "$2"
	;;
*) exit 2 ;;
esac
EOF

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
set -u
for argument in "$@"; do
	printf '<%s>\n' "$argument" >>"$SKETCHYBAR_TEST_CALLS"
done
EOF

cat >"$TMP/pmset" <<'EOF'
#!/usr/bin/env bash
set -u
printf "Now drawing from '%s'\n" "${TEST_POWER_SOURCE:-Battery Power}"
if [[ "${TEST_NO_BATTERY:-0}" != 1 ]]; then
	printf ' -InternalBattery-0 (id=1)\t%s%%; discharging; present: true\n' \
		"${TEST_BATTERY_PERCENTAGE:-74}"
fi
EOF

chmod +x "$TMP/battery-helper" "$TMP/sketchybar" "$TMP/pmset"
export BATTERY_LIMIT_HELPER="$TMP/battery-helper"
export BATTERY_LIMIT_TEST_STATE="$STATE"
export BATTERY_LIMIT_TEST_SET_CALLS="$SET_CALLS"
export BATTERY_LIMIT_LOG="$LOG"
export BATTERY_PMSET_BIN="$TMP/pmset"
export SKETCHYBAR="$TMP/sketchybar"
export SKETCHYBAR_TEST_CALLS="$CALLS"

run_renderer() {
	local limit="$1"
	local manual_state="${2:-1}"
	local optimized_state="${3:-1}"
	printf '%s\n' "$limit" >"$STATE"
	: >"$CALLS"
	NAME=battery TEST_MCL="$manual_state" \
		TEST_OPTIMIZED="$optimized_state" bash "$RENDERER"
}

run_renderer 80
assert_calls_contain '<label=74>' 'current charge must omit its unit when the limit suffix is available'
assert_calls_contain '<icon.drawing=off>' 'limit suffix must not duplicate the battery icon'
assert_calls_contain '<label=≤80%>' '80% must have an exact maximum label'
assert_calls_contain "<label.color=$ACCENT_COLOR>" 'an active limit suffix must use the blue accent color'

run_renderer 85
assert_calls_contain '<label=≤85%>' '85% changed in System Settings must render exactly'

run_renderer 90
assert_calls_contain '<label=≤90%>' '90% must have an exact maximum label'

run_renderer 95
assert_calls_contain '<label=≤95%>' '95% must have an exact maximum label'

run_renderer 100
assert_calls_contain '<label=≤100%>' '100% must have an exact maximum label'
assert_calls_contain "<label.color=$ACCENT_COLOR>" 'protected 100% must retain the accent color'

run_renderer 100 0 0
assert_calls_contain '<label=!100%>' 'unprotected 100% must be visibly marked unsafe'
assert_calls_contain "<label.color=$RED>" 'unprotected 100% must use the warning color'

run_renderer 90 0 1
assert_calls_contain '<label=!90%>' 'an inactive sub-100 manual policy must not look enforced'

: >"$CALLS"
if NAME=battery TEST_FAIL_STATUS=1 bash "$RENDERER"; then
	assert_calls_contain '<drawing=off>' 'an unavailable native API must hide the limit suffix'
	assert_calls_contain '<label=74%>' 'an unavailable native API must restore a self-contained current percentage'
else
	fail 'renderer must degrade cleanly when the native API is unavailable'
fi

# Exercise the requested sequence as one stateful cycle.
printf '80\n' >"$STATE"
: >"$SET_CALLS"
for expected in 90 95 100 80; do
	: >"$CALLS"
	if ! NAME=battery_limit bash "$CLICK_HANDLER"; then
		fail "click from the preceding state to $expected failed"
		continue
	fi
	actual="$(<"$STATE")"
	[[ "$actual" == "$expected" ]] ||
		fail "cycle expected $expected but helper stored $actual"
	assert_calls_contain '<--trigger>' "successful set to $expected must trigger a refresh"
	assert_calls_contain '<battery_limit_change>' "successful set to $expected must trigger the limit event"
done

expected_sets="$(printf '90\n95\n100\n80')"
actual_sets="$(<"$SET_CALLS")"
[[ "$actual_sets" == "$expected_sets" ]] ||
	fail "helper set sequence was not exactly 90,95,100,80"

# Native System Settings also offers 85%; the custom click cycle intentionally
# skips it and advances to the requested 90% state.
printf '85\n' >"$STATE"
: >"$CALLS"
NAME=battery_limit bash "$CLICK_HANDLER" || fail 'clicking an external 85% state failed'
[[ "$(<"$STATE")" == 90 ]] || fail '85% must advance to 90%'

# A failed write must not emit a success event or alter the stored limit.
printf '90\n' >"$STATE"
: >"$CALLS"
if NAME=battery_limit TEST_FAIL_SET=1 bash "$CLICK_HANDLER"; then
	fail 'failed native writes must return nonzero'
fi
[[ "$(<"$STATE")" == 90 ]] || fail 'failed native writes must preserve the old limit'
if grep -Fq -- '<--trigger>' "$CALLS"; then
	fail 'failed native writes must not emit a successful refresh event'
fi
assert_calls_contain '<label=Limit!>' 'failed native writes must show visible error feedback'
assert_calls_contain '<icon.drawing=off>' 'failed native writes must not restore a duplicate icon'
assert_calls_contain "<label.color=$RED>" 'failed native writes must show the warning color'

# Static integration: helper build, native event bridge, scripts, and item order.
grep -Fq 'battery_charge_limit.m' "$RC" || fail 'sketchybarrc must build the native helper'
grep -Fq 'sketchybar --add event battery_limit_change' "$RC" ||
	fail 'sketchybarrc must declare the immediate click-refresh event'
grep -Fq "click_script=\"\$PLUGIN_DIR/battery_limit_click.sh\"" "$RC" ||
	fail 'battery-limit click handler is not wired'
grep -Fq "script=\"\$PLUGIN_DIR/battery.sh\"" "$RC" ||
	fail 'shared battery renderer is not wired'
grep -Fq -- '--subscribe battery battery_limit_change power_source_change system_woke forced' "$RC" ||
	fail 'shared battery refresh subscriptions are incomplete'

battery_block="$TMP/battery-block"
limit_block="$TMP/limit-block"
sed -n '/--add item battery right/,/^$/p' "$RC" >"$battery_block"
sed -n '/--add item battery_limit right/,/^$/p' "$RC" >"$limit_block"
grep -Fq 'label.padding_right=0' "$battery_block" ||
	fail 'current charge must join the limit suffix without an internal gap'
grep -Fq 'label.padding_left=0' "$limit_block" ||
	fail 'limit suffix must join the current charge without an internal gap'
grep -Fq 'icon.drawing=off' "$limit_block" ||
	fail 'limit suffix must be label-only at rest'
if grep -Eq '^[[:space:]]*script=' "$limit_block"; then
	fail 'limit suffix must not race the shared battery renderer'
fi
grep -Fq "click_script=\"open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'\"" "$RC" ||
	fail 'current-charge region must open Battery Settings'

battery_line="$(grep -n -m1 -- '--add item battery right' "$RC" | cut -d: -f1)"
limit_line="$(grep -n -m1 -- '--add item battery_limit right' "$RC" | cut -d: -f1)"
volume_line="$(grep -n -m1 -- '--add item volume right' "$RC" | cut -d: -f1)"
if [[ -z "$battery_line" || -z "$limit_line" || -z "$volume_line" ]] ||
	(( limit_line >= battery_line || battery_line >= volume_line )); then
	fail 'limit must be declared before battery so the visible readout is current≤limit'
fi

if ((fails > 0)); then
	printf '%d battery limit plugin test(s) failed\n' "$fails"
	exit 1
fi

printf 'battery limit plugin tests passed\n'
