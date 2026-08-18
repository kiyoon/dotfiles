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
if [[ -n "${FAKE_KILLALL_DELAY:-}" ]]; then
	/bin/sleep "$FAKE_KILLALL_DELAY"
fi
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

run_action() {
	local name="$1"
	local reason="$2"
	shift 2
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
		"$@" /bin/bash "$SCRIPT" "$reason"
}

run_restart() {
	local name="$1"
	shift
	run_action "$name" "$name" "$@"
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

# Manual stop records an intentional hold, clears recovery markers, and never
# relaunches AeroSpace.
touch "$TMP/process-stop-running"
mkdir -p "$TMP/state-stop-running"
touch "$TMP/state-stop-running/refresh-now" "$TMP/state-stop-running/recovery-pending"
: >"$TMP/calls-stop-running"
run_action stop-running stop /usr/bin/env
check stop-running 'killall -TERM AeroSpace' "$(cat "$TMP/calls-stop-running")"
check stop-running-marker present "$(file_state "$TMP/state-stop-running/manually-stopped")"
check stop-running-refresh absent "$(file_state "$TMP/state-stop-running/refresh-now")"
check stop-running-pending absent "$(file_state "$TMP/state-stop-running/recovery-pending")"

# Stopping an already-dead server still establishes the hold.
: >"$TMP/calls-stop-dead"
run_action stop-dead stop /usr/bin/env
check stop-dead '' "$(cat "$TMP/calls-stop-dead")"
check stop-dead-marker present "$(file_state "$TMP/state-stop-dead/manually-stopped")"

# Start / Restart clears the hold and launches a stopped AeroSpace.
mkdir -p "$TMP/state-start-after-stop"
touch "$TMP/state-start-after-stop/manually-stopped"
: >"$TMP/calls-start-after-stop"
run_action start-after-stop manual /usr/bin/env
check start-after-stop 'open -g -a AeroSpace' "$(cat "$TMP/calls-start-after-stop")"
check start-after-stop-marker absent "$(file_state "$TMP/state-start-after-stop/manually-stopped")"

# Display recovery must not undo an intentional stop.
mkdir -p "$TMP/state-held-recovery"
touch "$TMP/state-held-recovery/manually-stopped" \
	"$TMP/state-held-recovery/refresh-now" \
	"$TMP/state-held-recovery/recovery-pending"
: >"$TMP/calls-held-recovery"
run_action held-recovery display-change /usr/bin/env
check held-recovery '' "$(cat "$TMP/calls-held-recovery")"
check held-recovery-marker present "$(file_state "$TMP/state-held-recovery/manually-stopped")"
check held-recovery-refresh absent "$(file_state "$TMP/state-held-recovery/refresh-now")"
check held-recovery-pending absent "$(file_state "$TMP/state-held-recovery/recovery-pending")"

# If AeroSpace is already running (for example after login), an old hold is
# stale and normal recovery resumes.
mkdir -p "$TMP/state-stale-hold"
touch "$TMP/state-stale-hold/manually-stopped" "$TMP/process-stale-hold"
: >"$TMP/calls-stale-hold"
run_action stale-hold display-change /usr/bin/env
check stale-hold $'killall -TERM AeroSpace\nopen -g -a AeroSpace' "$(cat "$TMP/calls-stale-hold")"
check stale-hold-marker absent "$(file_state "$TMP/state-stale-hold/manually-stopped")"

# A rapid Stop -> Start click sequence is serialized. Start waits for Stop's
# bounded TERM path and then clears the hold instead of being silently dropped.
touch "$TMP/process-stop-start-race"
: >"$TMP/calls-stop-start-race"
run_action stop-start-race stop /usr/bin/env FAKE_KILLALL_DELAY=0.2 &
stop_pid=$!
for _ in {1..100}; do
	grep -q '^killall -TERM AeroSpace$' "$TMP/calls-stop-start-race" && break
	/bin/sleep 0.01
done
run_action stop-start-race manual /usr/bin/env
wait "$stop_pid"
check stop-start-race $'killall -TERM AeroSpace\nopen -g -a AeroSpace' \
	"$(cat "$TMP/calls-stop-start-race")"
check stop-start-race-marker absent "$(file_state "$TMP/state-stop-start-race/manually-stopped")"

printf 'pass=%d fail=%d\n' "$pass" "$fail"
((fail == 0))
