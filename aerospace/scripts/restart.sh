#!/usr/bin/env bash
# Relaunch AeroSpace without asking its possibly wedged CLI server for state.
# Calls are serialized because manual and display-recovery restarts can overlap.
set -u

reason="${1:-manual}"
process_name="${AEROSPACE_RESTART_PROCESS_NAME:-AeroSpace}"
app_name="${AEROSPACE_RESTART_APP_NAME:-AeroSpace}"
state_dir="${AEROSPACE_RESTART_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/aerospace}"
lock_file="$state_dir/restart.lock"
log_file="$state_dir/recovery.log"

lockf_bin="${AEROSPACE_RESTART_LOCKF_BIN:-/usr/bin/lockf}"
pgrep_bin="${AEROSPACE_RESTART_PGREP_BIN:-/usr/bin/pgrep}"
killall_bin="${AEROSPACE_RESTART_KILLALL_BIN:-/usr/bin/killall}"
open_bin="${AEROSPACE_RESTART_OPEN_BIN:-/usr/bin/open}"
sleep_bin="${AEROSPACE_RESTART_SLEEP_BIN:-/bin/sleep}"
term_wait_attempts="${AEROSPACE_RESTART_TERM_WAIT_ATTEMPTS:-20}"
kill_wait_attempts="${AEROSPACE_RESTART_KILL_WAIT_ATTEMPTS:-10}"
wait_seconds="${AEROSPACE_RESTART_WAIT_SECONDS:-0.1}"

mkdir -p "$state_dir" || exit 1
exec 9>"$lock_file"
if ! "$lockf_bin" -s -t 0 9; then
	# Another invocation owns the restart. It will leave AeroSpace healthy.
	exit 0
fi

log() {
	printf '%s reason=%s %s\n' "$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')" "$reason" "$*" >>"$log_file"
}

is_running() {
	"$pgrep_bin" -x "$process_name" >/dev/null 2>&1
}

wait_for_exit() {
	local attempts="$1"
	local i=0
	while is_running && (( i < attempts )); do
		"$sleep_bin" "$wait_seconds"
		i=$((i + 1))
	done
	! is_running
}

log "restart requested"

if is_running; then
	"$killall_bin" -TERM "$process_name" >/dev/null 2>&1 || true
fi

if ! wait_for_exit "$term_wait_attempts"; then
	log "TERM timed out; sending KILL"
	"$killall_bin" -KILL "$process_name" >/dev/null 2>&1 || true
	wait_for_exit "$kill_wait_attempts" || {
		log "failed: old process is still running"
		exit 1
	}
fi

if "$open_bin" -g -a "$app_name"; then
	log "relaunch requested"
else
	status=$?
	log "failed: open exited $status"
	exit "$status"
fi
