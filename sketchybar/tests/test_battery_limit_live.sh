#!/usr/bin/env bash
# Opt-in native round-trip test. Every exit path restores the initial configured
# limit; the test refuses to start unless protection is already enabled.
set -u

if [[ "${BATTERY_LIMIT_LIVE_TEST:-0}" != 1 ]]; then
	printf 'Set BATTERY_LIMIT_LIVE_TEST=1 to allow temporary native limit changes.\n' >&2
	exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
SOURCE="$CONFIG_DIR/helpers/battery_charge_limit.m"
CLANG="${CLANG:-/usr/bin/clang}"
TMP="$(mktemp -d)"
HELPER="$TMP/battery_charge_limit"
restored=0

parse_status() {
	local status="$1"
	local limit_field manual_field optimized_field
	read -r limit_field manual_field optimized_field <<<"$status"
	LIMIT="${limit_field#limit=}"
	MCL_STATE="${manual_field#mcl=}"
	OPTIMIZED_STATE="${optimized_field#optimized=}"
}

die() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

cleanup() {
	if [[ "$restored" != 1 && -n "${ORIGINAL_LIMIT:-}" && -x "$HELPER" ]]; then
		"$HELPER" set "$ORIGINAL_LIMIT" >/dev/null 2>&1 ||
			printf 'WARNING: automatic restoration to %s%% failed\n' "$ORIGINAL_LIMIT" >&2
	fi
	rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

"$CLANG" -O2 -fobjc-arc -Wall -Wextra -Werror \
	"$SOURCE" -framework Foundation -o "$HELPER" || die 'native helper did not compile'

original_status="$("$HELPER" status 2>/dev/null)" || die 'could not read initial native status'
parse_status "$original_status"
ORIGINAL_LIMIT="$LIMIT"
ORIGINAL_MCL_STATE="$MCL_STATE"
ORIGINAL_OPTIMIZED_STATE="$OPTIMIZED_STATE"

[[ "$ORIGINAL_OPTIMIZED_STATE" == 1 ]] ||
	die 'refusing live test because Optimized Battery Charging starts disabled'
if [[ "$ORIGINAL_LIMIT" != 100 && "$ORIGINAL_MCL_STATE" != 1 ]]; then
	die 'refusing live test because the initial sub-100 manual policy is inactive'
fi

for target in 80 90 95 100; do
	result="$("$HELPER" set "$target" 2>/dev/null)" || die "setting $target% failed"
	parse_status "$result"
	[[ "$LIMIT" == "$target" ]] || die "set $target% but read back $LIMIT%"
	[[ "$OPTIMIZED_STATE" == 1 ]] ||
		die "Optimized Battery Charging was not enabled at $target%"
	if [[ "$target" != 100 && "$MCL_STATE" != 1 ]]; then
		die "manual charge policy was inactive at $target%"
	fi
done

restored_status="$("$HELPER" set "$ORIGINAL_LIMIT" 2>/dev/null)" ||
	die "restoring the original $ORIGINAL_LIMIT% limit failed"
parse_status "$restored_status"
[[ "$LIMIT" == "$ORIGINAL_LIMIT" ]] || die 'original limit did not restore'
[[ "$OPTIMIZED_STATE" == 1 ]] || die 'optimized charging was not preserved after restoration'
if [[ "$ORIGINAL_LIMIT" != 100 && "$MCL_STATE" != 1 ]]; then
	die 'original sub-100 manual policy did not restore as active'
fi

restored=1
printf 'battery limit live round-trip passed\n'
