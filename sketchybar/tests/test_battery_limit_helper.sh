#!/usr/bin/env bash
# Compile the runtime PowerUI helper and exercise only read-only/error paths.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
SOURCE="$CONFIG_DIR/helpers/battery_charge_limit.m"
CLANG="${CLANG:-/usr/bin/clang}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HELPER="$TMP/battery_charge_limit"
fails=0

fail() {
	printf 'FAIL: %s\n' "$1"
	fails=$((fails + 1))
}

parse_status() {
	local status="$1"
	local limit_field manual_field optimized_field
	read -r limit_field manual_field optimized_field <<<"$status"
	LIMIT="${limit_field#limit=}"
	MCL_STATE="${manual_field#mcl=}"
	OPTIMIZED_STATE="${optimized_field#optimized=}"
}

if ! "$CLANG" -O2 -fobjc-arc -Wall -Wextra -Werror \
	"$SOURCE" -framework Foundation -o "$HELPER"; then
	printf 'FAIL: native helper did not compile\n'
	exit 1
fi

status="$("$HELPER" status 2>/dev/null)" || {
	printf 'FAIL: native helper could not read PowerUI status\n'
	exit 1
}
parse_status "$status"

case "$LIMIT" in
80 | 85 | 90 | 95 | 100) ;;
*) fail "native helper returned unsupported limit '$LIMIT'" ;;
esac
[[ "$OPTIMIZED_STATE" == 1 ]] || fail 'Optimized Battery Charging must currently be enabled'
if [[ "$LIMIT" != 100 && "$MCL_STATE" != 1 ]]; then
	fail 'the configured sub-100 manual limit must currently be active'
fi

# Invalid input must fail before changing native state.
if "$HELPER" set 81 >/dev/null 2>&1; then
	fail 'helper accepted a charge limit macOS does not offer'
fi
after_invalid="$("$HELPER" status 2>/dev/null)" || fail 'status failed after invalid input'
[[ "$after_invalid" == "$status" ]] || fail 'invalid input changed native charge state'

if "$HELPER" unknown >/dev/null 2>&1; then
	fail 'helper accepted an unknown command'
fi

if ((fails > 0)); then
	printf '%d battery limit helper integration test(s) failed\n' "$fails"
	exit 1
fi

printf 'battery limit helper integration passed\n'
