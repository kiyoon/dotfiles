#!/usr/bin/env bash
# End the windows-tail gaming session with bounded, verified branches:
# connect Tailscale, then stop the tracked Steam game/client while closing
# Moonlight concurrently on the Mac.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
source "$CONFIG_DIR/colors.sh"

RUN_MODE="${1:-stop}"
if [[ "$RUN_MODE" != stop && "$RUN_MODE" != probe ]]; then
	printf 'usage: %s [stop|probe]\n' "$0" >&2
	exit 2
fi

SSH_TARGET="${GAMING_STOP_SSH_TARGET:-windows-tail}"
REMOTE_SCRIPT="${GAMING_STOP_REMOTE_SCRIPT:-$SCRIPT_DIR/steam_stop.ps1}"
LOG_FILE="${GAMING_STOP_LOG_FILE:-${TMPDIR:-/tmp}/sketchybar_gaming_stop.log}"
LOCK_DIR="${GAMING_STOP_LOCK_DIR:-${TMPDIR:-/tmp}/sketchybar_gaming_stop.lock}"
FEEDBACK_SECONDS="${GAMING_STOP_FEEDBACK_SECONDS:-2}"
SSH_AGENT_ENV_FILE="${GAMING_STOP_SSH_AGENT_ENV_FILE:-$HOME/.ssh/agent.env}"
SSH_IDENTITY_FILE="${GAMING_STOP_SSH_IDENTITY_FILE:-$HOME/.ssh/id_ed25519}"

TAILSCALE_BIN="${GAMING_STOP_TAILSCALE_BIN:-}"
if [[ -z "$TAILSCALE_BIN" ]]; then
	for candidate in \
		/usr/local/bin/tailscale \
		/opt/homebrew/bin/tailscale \
		/Applications/Tailscale.app/Contents/MacOS/Tailscale; do
		if [[ -x "$candidate" ]]; then
			TAILSCALE_BIN="$candidate"
			break
		fi
	done
fi

JQ_BIN="${GAMING_STOP_JQ_BIN:-/usr/bin/jq}"
OPEN_BIN="${GAMING_STOP_OPEN_BIN:-/usr/bin/open}"
SSH_BIN="${GAMING_STOP_SSH_BIN:-/usr/bin/ssh}"
PGREP_BIN="${GAMING_STOP_PGREP_BIN:-/usr/bin/pgrep}"
PS_BIN="${GAMING_STOP_PS_BIN:-/bin/ps}"
KILL_BIN="${GAMING_STOP_KILL_BIN:-/bin/kill}"
SLEEP_BIN="${GAMING_STOP_SLEEP_BIN:-/bin/sleep}"
CAT_BIN="${GAMING_STOP_CAT_BIN:-/bin/cat}"
UNLINK_BIN="${GAMING_STOP_UNLINK_BIN:-/bin/unlink}"
SKETCHYBAR_BIN="${GAMING_STOP_SKETCHYBAR_BIN:-sketchybar}"
ITEM_NAME="${NAME:-gaming_stop}"
REMOTE_SUCCESS_LABEL="Stopped"
REMOTE_RESULT_FILE=""
MOONLIGHT_JOB_PID=""

log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

clear_remote_result() {
	if [[ -n "$REMOTE_RESULT_FILE" && -e "$REMOTE_RESULT_FILE" ]]; then
		"$UNLINK_BIN" "$REMOTE_RESULT_FILE" 2>/dev/null || true
	fi
	REMOTE_RESULT_FILE=""
}

set_button() {
	local state="$1"
	command -v "$SKETCHYBAR_BIN" >/dev/null 2>&1 || return 0

	case "$state" in
	busy)
		"$SKETCHYBAR_BIN" --set "$ITEM_NAME" \
			drawing=on icon.drawing=on icon.color="$YELLOW" \
			label="Stopping…" label.color="$YELLOW" label.drawing=on >/dev/null 2>&1 || true
		;;
	success)
		"$SKETCHYBAR_BIN" --set "$ITEM_NAME" \
			drawing=on icon.drawing=on icon.color="$GREEN" \
			label="$REMOTE_SUCCESS_LABEL" label.color="$GREEN" label.drawing=on >/dev/null 2>&1 || true
		;;
	failure)
		"$SKETCHYBAR_BIN" --set "$ITEM_NAME" \
			drawing=on icon.drawing=on icon.color="$RED" \
			label="Failed" label.color="$RED" label.drawing=on >/dev/null 2>&1 || true
		;;
	idle)
		"$SKETCHYBAR_BIN" --set "$ITEM_NAME" \
			drawing=off icon.drawing=off label.drawing=off >/dev/null 2>&1 || true
		;;
	esac
}

prepare_ssh_auth() {
	local agent_socket=""

	# An explicit override is useful for alternate agents and the stubbed test
	# harness. Otherwise prefer the long-lived agent created by this dotfiles
	# setup over launchd's default Apple agent, which may contain no identities.
	if [[ -n "${GAMING_STOP_SSH_AUTH_SOCK:-}" ]]; then
		agent_socket="$GAMING_STOP_SSH_AUTH_SOCK"
		if [[ ! -S "$agent_socket" ]]; then
			log "The explicitly configured SSH agent socket is invalid"
			return 1
		fi
		log "Using the explicitly configured SSH agent socket"
	elif [[ -r "$SSH_AGENT_ENV_FILE" ]]; then
		agent_socket="$(sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);[[:space:]]*export SSH_AUTH_SOCK;.*$/\1/p' "$SSH_AGENT_ENV_FILE" | head -1)"
		if [[ -n "$agent_socket" && -S "$agent_socket" ]]; then
			log "Using the live SSH agent recorded in $SSH_AGENT_ENV_FILE"
		else
			agent_socket=""
			log "The SSH agent recorded in $SSH_AGENT_ENV_FILE is missing or stale"
		fi
	fi

	if [[ -n "$agent_socket" ]]; then
		export SSH_AUTH_SOCK="$agent_socket"
	else
		log "No dotfiles SSH agent socket was available; SSH will use its inherited identity configuration"
	fi
	return 0
}

tailscale_is_connected() {
	[[ -n "$TAILSCALE_BIN" && -x "$TAILSCALE_BIN" && -x "$JQ_BIN" ]] || return 1
	TAILSCALE_BE_CLI=1 "$TAILSCALE_BIN" status --json 2>>"$LOG_FILE" |
		"$JQ_BIN" -e '.BackendState == "Running"' >/dev/null 2>&1
}

ensure_tailscale() {
	if tailscale_is_connected; then
		log "Tailscale is already connected"
		return 0
	fi

	if [[ -z "$TAILSCALE_BIN" || ! -x "$TAILSCALE_BIN" ]]; then
		log "Tailscale CLI was not found"
		return 1
	fi
	if [[ ! -x "$JQ_BIN" ]]; then
		log "jq was not found at $JQ_BIN"
		return 1
	fi

	log "Tailscale is offline; opening the app and requesting a bounded connection"
	"$OPEN_BIN" -gj -a Tailscale >>"$LOG_FILE" 2>&1 || true
	if ! TAILSCALE_BE_CLI=1 "$TAILSCALE_BIN" up --timeout=12s >>"$LOG_FILE" 2>&1; then
		log "tailscale up failed (first-time login may require the Tailscale app)"
		return 1
	fi
	if ! TAILSCALE_BE_CLI=1 "$TAILSCALE_BIN" wait --timeout=5s >>"$LOG_FILE" 2>&1; then
		log "Tailscale did not become ready within 5 seconds"
		return 1
	fi
	if ! tailscale_is_connected; then
		log "Tailscale still does not report a Running backend"
		return 1
	fi

	log "Tailscale connected"
	return 0
}

remote_inputs_are_ready() {
	if [[ ! -r "$REMOTE_SCRIPT" ]]; then
		log "Remote Steam helper is unreadable: $REMOTE_SCRIPT"
		return 1
	fi
	if [[ ! -r "$SSH_IDENTITY_FILE" ]]; then
		log "Pinned SSH identity is unreadable; refusing an unpinned connection"
		return 1
	fi
	if [[ ! -x "$SSH_BIN" ]]; then
		log "SSH client is unavailable: $SSH_BIN"
		return 1
	fi
	return 0
}

run_remote() {
	local mode="$1"
	local parsed_result remote_outcome
	local ssh_identity_args=(
		-i "$SSH_IDENTITY_FILE"
		-o IdentitiesOnly=yes
		-o AddKeysToAgent=no
		-o UseKeychain=yes
	)
	if ! remote_inputs_are_ready; then
		return 1
	fi
	log "Using the pinned Windows SSH identity"

	# Prepending the mode keeps steam_stop.ps1 read-only when it is invoked by
	# hand. Feeding the script to pwsh also works regardless of whether Windows
	# OpenSSH's configured default shell is cmd.exe or PowerShell.
	REMOTE_RESULT_FILE="$LOCK_DIR/remote-result.json"
	if ! : >"$REMOTE_RESULT_FILE"; then
		log "Could not create the remote result file inside the click lock"
		REMOTE_RESULT_FILE=""
		return 1
	fi

	{
		if [[ "$mode" == stop ]]; then
			printf '%s\n' '$env:GAMING_STOP_MODE = "stop"'
		else
			printf '%s\n' '$env:GAMING_STOP_MODE = "probe"'
		fi
		"$CAT_BIN" "$REMOTE_SCRIPT"
	} | "$SSH_BIN" \
		-T \
		-o BatchMode=yes \
		-o StrictHostKeyChecking=yes \
		-o ConnectTimeout=8 \
		-o ConnectionAttempts=1 \
		-o ServerAliveInterval=3 \
		-o ServerAliveCountMax=2 \
		"${ssh_identity_args[@]}" \
		"$SSH_TARGET" \
		'pwsh.exe -NoLogo -NoProfile -NonInteractive -Command "& ([scriptblock]::Create([Console]::In.ReadToEnd()))"' >"$REMOTE_RESULT_FILE" 2>>"$LOG_FILE"
	local pipeline_status=("${PIPESTATUS[@]}")
	if [[ -s "$REMOTE_RESULT_FILE" ]]; then
		"$CAT_BIN" "$REMOTE_RESULT_FILE" >>"$LOG_FILE"
	fi
	if [[ "${pipeline_status[0]}" -ne 0 ]]; then
		clear_remote_result
		return "${pipeline_status[0]}"
	fi
	if [[ "${pipeline_status[1]}" -ne 0 ]]; then
		clear_remote_result
		return "${pipeline_status[1]}"
	fi

	# A zero SSH exit alone is not enough to close Moonlight. Require exactly
	# one successful, mode-matching JSON object from the Windows helper.
	if ! parsed_result="$("$JQ_BIN" -c -e -s --arg mode "$mode" '
		def nonnegint: type == "number" and . >= 0 and floor == .;
		def posint: nonnegint and . > 0;
		if length != 1 or (.[0] | type) != "object" then
			error("expected exactly one remote result object")
		else
			.[0]
		end
		| if .Mode != $mode
			or .Success != true
			or (.SteamRunning | type) != "boolean"
			or ((.SteamPidCount | nonnegint) | not)
			or ((.RunningAppId | nonnegint) | not)
			or (.RunningApps | type) != "array"
			or (all(.RunningApps[]; (.AppId | posint) and (.Name | type) == "string") | not)
			or (.TrackedProcesses | type) != "array"
			or (all(.TrackedProcesses[]; (.AppId | posint) and (.Pid | posint) and (.Name | type) == "string") | not)
			or (.SteamExecutableTrusted | type) != "boolean"
			or (.ReadyToStop | type) != "boolean"
			or (.Actions | type) != "array"
			or (all(.Actions[]; type == "string") | not)
		then error("invalid remote result schema") else . end
	' "$REMOTE_RESULT_FILE" 2>/dev/null)"; then
		log "Remote helper returned missing, malformed, or inconsistent JSON"
		clear_remote_result
		return 1
	fi
	clear_remote_result

	if [[ "$mode" == stop ]]; then
		if ! remote_outcome="$(printf '%s\n' "$parsed_result" | "$JQ_BIN" -e -r '
			def action($text): any(.Actions[]; . == $text);
			def steam_gone: action("confirmed Steam exited") or action("Steam was not running");
			.RunningAppId as $app_id
			| if .SteamRunning == false
				and .SteamPidCount == 0
				and $app_id == 0
				and (.RunningApps | length) == 0
				and (.TrackedProcesses | length) == 0
				and .SteamExecutableTrusted == false
				and .ReadyToStop == false
				and action("Steam was not running")
			then "no_steam"
			elif .SteamRunning == true
				and .SteamPidCount > 0
				and $app_id > 0
				and (.RunningApps | length) == 1
				and .RunningApps[0].AppId == $app_id
				and (.RunningApps | length) > 0
				and (.TrackedProcesses | length) > 0
				and all(.TrackedProcesses[]; .AppId == $app_id)
				and .SteamExecutableTrusted == true
				and .ReadyToStop == true
				and action("confirmed AppID \($app_id) stopped")
				and steam_gone
			then "game_stopped"
			elif .SteamRunning == true
				and .SteamPidCount > 0
				and $app_id == 0
				and (.RunningApps | length) == 0
				and (.TrackedProcesses | length) == 0
				and .SteamExecutableTrusted == true
				and .ReadyToStop == false
				and steam_gone
			then "steam_stopped"
			else error("remote actions do not prove a known stop outcome") end
		' 2>/dev/null)"; then
			log "Remote result did not prove a recognized stop outcome"
			return 1
		fi
		case "$remote_outcome" in
		no_steam) REMOTE_SUCCESS_LABEL="No Steam running" ;;
		steam_stopped) REMOTE_SUCCESS_LABEL="Steam stopped" ;;
		game_stopped) REMOTE_SUCCESS_LABEL="Game stopped" ;;
		*)
			log "Remote result produced an unknown outcome token"
			return 1
			;;
		esac
		log "Success feedback: $REMOTE_SUCCESS_LABEL"
	fi
	return 0
}

moonlight_pid_is_running() {
	local pid="$1" command_path
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1
	command_path="$($PS_BIN -p "$pid" -o comm= 2>/dev/null)"
	[[ "$command_path" == */Moonlight.app/Contents/MacOS/Moonlight ]]
}

moonlight_pids() {
	local pid
	while IFS= read -r pid; do
		if moonlight_pid_is_running "$pid"; then
			printf '%s\n' "$pid"
		fi
	done < <("$PGREP_BIN" -x Moonlight 2>/dev/null || true)
}

remaining_moonlight_pids() {
	local original_pids="$1" pid
	while IFS= read -r pid; do
		if moonlight_pid_is_running "$pid"; then
			printf '%s\n' "$pid"
		fi
	done <<<"$original_pids"
}

wait_for_moonlight_job() {
	local job_status
	[[ -n "$MOONLIGHT_JOB_PID" ]] || return 0
	wait "$MOONLIGHT_JOB_PID"
	job_status=$?
	MOONLIGHT_JOB_PID=""
	return "$job_status"
}

close_moonlight() {
	local pids pid attempt remaining
	pids="$(moonlight_pids)"
	if [[ -z "$pids" ]]; then
		log "Moonlight is not running"
		return 0
	fi

	# Moonlight 6.1 may interpret the first TERM during an active stream as a
	# request to end the session, then remain open at its main window. Give that
	# teardown a brief grace period before a second TERM asks the app to exit.
	log "Sending first TERM to end Moonlight's active stream"
	while IFS= read -r pid; do
		[[ -n "$pid" ]] || continue
		"$KILL_BIN" -TERM "$pid" >>"$LOG_FILE" 2>&1 || true
	done <<<"$pids"

	for ((attempt = 0; attempt < 8; attempt++)); do
		remaining="$(remaining_moonlight_pids "$pids")"
		[[ -z "$remaining" ]] && {
			log "Moonlight exited cleanly"
			return 0
		}
		"$SLEEP_BIN" 0.25
	done

	remaining="$(remaining_moonlight_pids "$pids")"
	log "Moonlight ended its session but remained open; sending second TERM to close the app"
	while IFS= read -r pid; do
		[[ -n "$pid" ]] || continue
		"$KILL_BIN" -TERM "$pid" >>"$LOG_FILE" 2>&1 || true
	done <<<"$remaining"

	for ((attempt = 0; attempt < 4; attempt++)); do
		remaining="$(remaining_moonlight_pids "$pids")"
		[[ -z "$remaining" ]] && {
			log "Moonlight exited after its second TERM"
			return 0
		}
		"$SLEEP_BIN" 0.25
	done

	remaining="$(remaining_moonlight_pids "$pids")"
	log "Moonlight ignored both TERM requests; forcing only the original verified remaining PID(s)"
	while IFS= read -r pid; do
		[[ -n "$pid" ]] || continue
		"$KILL_BIN" -KILL "$pid" >>"$LOG_FILE" 2>&1 || true
	done <<<"$remaining"
	"$SLEEP_BIN" 0.25

	if [[ -n "$(remaining_moonlight_pids "$pids")" ]]; then
		log "Moonlight is still running"
		return 1
	fi
	log "Moonlight was force-closed after both TERM requests"
	return 0
}

finish() {
	local status="$1"
	if [[ "$status" -eq 0 ]]; then
		set_button success
		log "Gaming shutdown completed: $REMOTE_SUCCESS_LABEL"
	else
		set_button failure
		log "Gaming shutdown completed with an error"
	fi
	"$SLEEP_BIN" "$FEEDBACK_SECONDS"
	set_button idle
	return "$status"
}

# SketchyBar exports BUTTON. Ignore right/middle clicks, while preserving
# direct command-line invocation where BUTTON is unset.
if [[ "${BUTTON:-left}" != left ]]; then
	exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	log "Ignoring duplicate click; another gaming shutdown is active"
	exit 0
fi
cleanup_lock() {
	if [[ -n "$MOONLIGHT_JOB_PID" ]]; then
		wait_for_moonlight_job >/dev/null 2>&1 || true
	fi
	clear_remote_result
	rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup_lock EXIT
trap 'exit 130' HUP INT TERM

log "=== gaming $RUN_MODE requested for $SSH_TARGET"
if [[ "$RUN_MODE" == stop ]]; then
	set_button busy
	log "Starting Moonlight shutdown immediately alongside local/Tailscale preparation"
	close_moonlight &
	MOONLIGHT_JOB_PID=$!
fi

status=0
ssh_auth_ready=1
if ! prepare_ssh_auth; then
	status=1
	ssh_auth_ready=0
fi

if ensure_tailscale; then
	if [[ "$ssh_auth_ready" -ne 1 ]]; then
		log "Skipping SSH because its configured authentication is invalid"
	elif ! remote_inputs_are_ready; then
		status=1
		log "Skipping SSH because the remote inputs are invalid"
	else
		if [[ "$RUN_MODE" == stop ]]; then
			log "Requesting verified Steam game stop and Steam shutdown over SSH"
		else
			log "Requesting read-only Steam probe over SSH"
		fi
		if run_remote "$RUN_MODE"; then
			log "Remote Steam $RUN_MODE succeeded"
		else
			log "Remote Steam $RUN_MODE failed"
			status=1
		fi
	fi
else
	log "Skipping SSH because Tailscale could not be connected"
	status=1
fi

# Probe mode is read-only by contract and never touches Moonlight. Stop mode
# waits for the local branch that began alongside SSH, regardless of whether
# the remote branch eventually succeeds or fails.
if [[ "$RUN_MODE" == probe ]]; then
	log "Probe mode leaves Moonlight unchanged"
elif [[ -n "$MOONLIGHT_JOB_PID" ]]; then
	if wait_for_moonlight_job; then
		log "Concurrent Moonlight shutdown succeeded"
	else
		log "Concurrent Moonlight shutdown failed"
		status=1
	fi
else
	log "Moonlight shutdown job was not started"
	status=1
fi

if [[ "$RUN_MODE" == probe ]]; then
	if [[ "$status" -eq 0 ]]; then
		log "Gaming probe completed"
	else
		log "Gaming probe failed"
	fi
	exit "$status"
fi

finish "$status"
exit $?
