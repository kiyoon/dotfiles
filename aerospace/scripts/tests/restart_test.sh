#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/restart.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-restart-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"

cat >"$TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ -f "$FAKE_PROCESS_STATE" ]]
EOF

cat >"$TMP/bin/killall" <<'EOF'
#!/usr/bin/env bash
printf 'killall %s\n' "$*" >>"$FAKE_CALLS"
if [[ "$1" == "-KILL" || "${FAKE_IGNORE_TERM:-0}" != "1" ]]; then
	rm -f "$FAKE_PROCESS_STATE"
fi
EOF

cat >"$TMP/bin/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >>"$FAKE_CALLS"
[[ "${FAKE_OPEN_FAIL:-0}" != "1" ]]
EOF

cat >"$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >>"$FAKE_CALLS"
EOF

chmod +x "$TMP/bin/"*

pass=0
fail=0

check() {
	local name="$1"
	local expected="$2"
	local actual="$3"
	if [[ "$actual" == "$expected" ]]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		printf 'FAIL %s\nexpected:\n%s\nactual:\n%s\n' "$name" "$expected" "$actual" >&2
	fi
}

file_state() {
	if [[ -f "$1" ]]; then
		printf 'present'
	else
		printf 'absent'
	fi
}

run_restart() {
	local name="$1"
	shift
	local state_dir="$TMP/state-$name"
	mkdir -p "$state_dir"
	FAKE_PROCESS_STATE="$TMP/process-$name" \
		FAKE_CALLS="$TMP/calls-$name" \
		AEROSPACE_RESTART_STATE_DIR="$state_dir" \
		AEROSPACE_RESTART_PGREP_BIN="$TMP/bin/pgrep" \
		AEROSPACE_RESTART_KILLALL_BIN="$TMP/bin/killall" \
		AEROSPACE_RESTART_OPEN_BIN="$TMP/bin/open" \
		AEROSPACE_RESTART_SLEEP_BIN="$TMP/bin/sleep" \
		AEROSPACE_RESTART_TERM_WAIT_ATTEMPTS=2 \
		AEROSPACE_RESTART_KILL_WAIT_ATTEMPTS=1 \
		"$@" /bin/bash "$SCRIPT" "$name"
}

# A healthy process receives TERM, fully exits, then LaunchServices is called.
touch "$TMP/process-graceful"
: >"$TMP/calls-graceful"
run_restart graceful /usr/bin/env
check graceful $'killall -TERM AeroSpace\nopen -g -a AeroSpace' "$(cat "$TMP/calls-graceful")"
check graceful-marker present "$(file_state "$TMP/state-graceful/refresh-now")"
check graceful-pending present "$(file_state "$TMP/state-graceful/recovery-pending")"
check graceful-generation \
	"$(cat "$TMP/state-graceful/recovery-pending")" \
	"$(cat "$TMP/state-graceful/refresh-now")"

# Recovery also launches AeroSpace when the hot-plug crash already killed it.
: >"$TMP/calls-dead"
run_restart dead /usr/bin/env
check dead 'open -g -a AeroSpace' "$(cat "$TMP/calls-dead")"
check dead-marker present "$(file_state "$TMP/state-dead/refresh-now")"
check dead-pending present "$(file_state "$TMP/state-dead/recovery-pending")"
check dead-generation \
	"$(cat "$TMP/state-dead/recovery-pending")" \
	"$(cat "$TMP/state-dead/refresh-now")"

# A wedged process gets a bounded TERM wait and then an exact-name KILL.
touch "$TMP/process-wedged"
: >"$TMP/calls-wedged"
run_restart wedged /usr/bin/env FAKE_IGNORE_TERM=1
check wedged $'killall -TERM AeroSpace\nsleep 0.1\nsleep 0.1\nkillall -KILL AeroSpace\nopen -g -a AeroSpace' \
	"$(cat "$TMP/calls-wedged")"

# Propagate an app-launch failure so Hammerspoon can report it.
: >"$TMP/calls-open-failure"
if run_restart open-failure /usr/bin/env FAKE_OPEN_FAIL=1; then
	fail=$((fail + 1))
	echo "FAIL open-failure (expected non-zero exit)" >&2
else
	pass=$((pass + 1))
fi
check open-failure-marker absent "$(file_state "$TMP/state-open-failure/refresh-now")"
check open-failure-pending present "$(file_state "$TMP/state-open-failure/recovery-pending")"

printf 'pass=%d fail=%d\n' "$pass" "$fail"
((fail == 0))
