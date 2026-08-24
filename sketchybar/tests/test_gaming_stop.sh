#!/usr/bin/env bash
# Unit and wiring tests for plugins/gaming_stop.sh. Every external action is
# stubbed; this test never connects Tailscale, SSHes, or signals a real app.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
PLUGIN="$CONFIG_DIR/plugins/gaming_stop.sh"
REMOTE_SCRIPT="$CONFIG_DIR/plugins/steam_stop.ps1"
SKETCHYBARRC="$CONFIG_DIR/sketchybarrc"
README="$CONFIG_DIR/README.md"

TEST_TMP="$(mktemp -d)"
STUB_DIR="$TEST_TMP/bin"
mkdir -p "$STUB_DIR"

TEST_AGENT_SOCKET="$TEST_TMP/agent.sock"
TEST_AGENT_ENV="$TEST_TMP/agent.env"
if ! /usr/bin/ssh-agent -a "$TEST_AGENT_SOCKET" >"$TEST_AGENT_ENV"; then
	echo "FAIL: could not start isolated test SSH agent"
	exit 1
fi
TEST_AGENT_PID="$(sed -n 's/^SSH_AGENT_PID=\([0-9][0-9]*\);.*$/\1/p' "$TEST_AGENT_ENV" | head -1)"
if [[ ! "$TEST_AGENT_PID" =~ ^[0-9]+$ || ! -S "$TEST_AGENT_SOCKET" ]]; then
	echo "FAIL: isolated test SSH agent did not create a valid socket"
	exit 1
fi
cleanup_test() {
	/bin/kill "$TEST_AGENT_PID" 2>/dev/null || true
	rm -rf "$TEST_TMP"
}
trap cleanup_test EXIT

fails=0
last_status=0

fail() {
	echo "FAIL: $1"
	fails=$((fails + 1))
}

assert_contains() {
	local file="$1" pattern="$2" message="$3"
	grep -Fq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
	local file="$1" pattern="$2" message="$3"
	if grep -Fq -- "$pattern" "$file"; then
		fail "$message"
	fi
}

assert_before() {
	local file="$1" first="$2" second="$3" message="$4"
	local first_line second_line
	first_line="$(grep -nF -m1 -- "$first" "$file" | cut -d: -f1)"
	second_line="$(grep -nF -m1 -- "$second" "$file" | cut -d: -f1)"
	if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
		fail "$message"
	fi
}

cat >"$STUB_DIR/tailscale" <<'EOF'
#!/usr/bin/env bash
printf 'tailscale %s\n' "$*" >>"$TEST_CALLS"
case "${1:-}" in
status)
	if [[ -e "$TEST_TS_ONLINE" ]]; then
		printf '%s\n' '{"BackendState":"Running"}'
	else
		printf '%s\n' '{"BackendState":"Stopped"}'
	fi
	;;
up)
	if [[ "${STUB_TS_UP_EXIT:-0}" -ne 0 ]]; then
		exit "$STUB_TS_UP_EXIT"
	fi
	: >"$TEST_TS_ONLINE"
	;;
wait)
	[[ -e "$TEST_TS_ONLINE" ]]
	;;
*) exit 2 ;;
esac
EOF

cat >"$STUB_DIR/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >>"$TEST_CALLS"
exit "${STUB_OPEN_EXIT:-0}"
EOF

cat >"$STUB_DIR/ssh" <<'EOF'
#!/usr/bin/env bash
printf 'ssh_agent %s\n' "${SSH_AUTH_SOCK:-<unset>}" >>"$TEST_CALLS"
printf 'ssh %s\n' "$*" >>"$TEST_CALLS"
/bin/cat >"$TEST_SSH_STDIN"
ssh_status="${STUB_SSH_EXIT:-0}"
if [[ "$ssh_status" -ne 0 ]]; then
	exit "$ssh_status"
fi
if [[ -n "${STUB_SSH_JSON+x}" ]]; then
	printf '%s\n' "$STUB_SSH_JSON"
elif [[ "$(head -1 "$TEST_SSH_STDIN")" == *'"probe"'* ]]; then
	printf '%s\n' '{"Mode":"probe","SteamRunning":false,"SteamPidCount":0,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":false,"ReadyToStop":false,"Actions":[],"Success":true}'
else
	printf '%s\n' '{"Mode":"stop","SteamRunning":true,"SteamPidCount":1,"RunningAppId":2114740,"RunningApps":[{"AppId":2114740,"Name":"Test Game"}],"TrackedProcesses":[{"AppId":2114740,"Pid":42424,"Name":"test-game.exe"}],"SteamExecutableTrusted":true,"ReadyToStop":true,"Actions":["confirmed AppID 2114740 stopped","confirmed Steam exited"],"Success":true}'
fi
EOF

cat >"$STUB_DIR/pgrep" <<'EOF'
#!/usr/bin/env bash
printf 'pgrep %s\n' "$*" >>"$TEST_CALLS"
if [[ "$*" == "-x Moonlight" && -e "$TEST_MOONLIGHT_RUNNING" ]]; then
	printf '%s\n' 4242
fi
EOF

cat >"$STUB_DIR/ps" <<'EOF'
#!/usr/bin/env bash
printf 'ps %s\n' "$*" >>"$TEST_CALLS"
if [[ "$*" == *"-p 4242"* && -e "$TEST_MOONLIGHT_RUNNING" ]]; then
	printf '%s\n' '/Applications/Moonlight.app/Contents/MacOS/Moonlight'
fi
EOF

cat >"$STUB_DIR/kill" <<'EOF'
#!/usr/bin/env bash
printf 'kill %s\n' "$*" >>"$TEST_CALLS"
case "${1:-}" in
-TERM)
	if [[ "${STUB_MOONLIGHT_STUBBORN:-0}" -ne 1 ]]; then
		/bin/rm -f "$TEST_MOONLIGHT_RUNNING"
	fi
	;;
-KILL)
	if [[ "${STUB_MOONLIGHT_UNKILLABLE:-0}" -ne 1 ]]; then
		/bin/rm -f "$TEST_MOONLIGHT_RUNNING"
	fi
	;;
esac
EOF

cat >"$STUB_DIR/sleep" <<'EOF'
#!/usr/bin/env bash
printf 'sleep %s\n' "$*" >>"$TEST_CALLS"
EOF

cat >"$STUB_DIR/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf 'sketchybar %s\n' "$*" >>"$TEST_CALLS"
EOF

chmod +x "$STUB_DIR"/*

new_case() {
	local name="$1"
	TEST_CASE_DIR="$TEST_TMP/$name"
	mkdir -p "$TEST_CASE_DIR"
	export TEST_CALLS="$TEST_CASE_DIR/calls"
	export TEST_TS_ONLINE="$TEST_CASE_DIR/tailscale-online"
	export TEST_MOONLIGHT_RUNNING="$TEST_CASE_DIR/moonlight-running"
	export TEST_SSH_STDIN="$TEST_CASE_DIR/ssh-stdin.ps1"
	: >"$TEST_CALLS"
	: >"$TEST_SSH_STDIN"

	export GAMING_STOP_TAILSCALE_BIN="$STUB_DIR/tailscale"
	export GAMING_STOP_JQ_BIN=/usr/bin/jq
	export GAMING_STOP_OPEN_BIN="$STUB_DIR/open"
	export GAMING_STOP_SSH_BIN="$STUB_DIR/ssh"
	export GAMING_STOP_PGREP_BIN="$STUB_DIR/pgrep"
	export GAMING_STOP_PS_BIN="$STUB_DIR/ps"
	export GAMING_STOP_KILL_BIN="$STUB_DIR/kill"
	export GAMING_STOP_SLEEP_BIN="$STUB_DIR/sleep"
	export GAMING_STOP_CAT_BIN=/bin/cat
	export GAMING_STOP_SKETCHYBAR_BIN="$STUB_DIR/sketchybar"
	export GAMING_STOP_REMOTE_SCRIPT="$REMOTE_SCRIPT"
	export GAMING_STOP_LOCK_DIR="$TEST_CASE_DIR/lock"
	export GAMING_STOP_LOG_FILE="$TEST_CASE_DIR/plugin.log"
	export GAMING_STOP_FEEDBACK_SECONDS=0
	export GAMING_STOP_SSH_AGENT_ENV_FILE="$TEST_AGENT_ENV"
	export GAMING_STOP_SSH_IDENTITY_FILE="$TEST_CASE_DIR/id_ed25519"
	: >"$GAMING_STOP_SSH_IDENTITY_FILE"
	unset GAMING_STOP_SSH_AUTH_SOCK
	unset STUB_TS_UP_EXIT STUB_OPEN_EXIT STUB_SSH_EXIT STUB_SSH_JSON STUB_MOONLIGHT_STUBBORN STUB_MOONLIGHT_UNKILLABLE
}

invoke_plugin() {
	local button="${1:-left}"
	BUTTON="$button" NAME=gaming_stop bash "$PLUGIN"
	last_status=$?
}

invoke_probe() {
	BUTTON=left NAME=gaming_stop bash "$PLUGIN" probe
	last_status=$?
}

# 1. Offline happy path: connection is established before SSH, and Moonlight
# receives one graceful TERM only after the remote step succeeds.
new_case offline_happy
: >"$TEST_MOONLIGHT_RUNNING"
invoke_plugin
[[ "$last_status" -eq 0 ]] || fail "offline happy path should succeed"
assert_contains "$TEST_CALLS" 'open -gj -a Tailscale' "offline path must open Tailscale"
assert_contains "$TEST_CALLS" 'tailscale up --timeout=12s' "offline path must run bounded tailscale up"
assert_contains "$TEST_CALLS" 'tailscale wait --timeout=5s' "offline path must wait for Tailscale readiness"
assert_contains "$TEST_CALLS" 'ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes' "SSH must be noninteractive and reject unknown host keys"
assert_contains "$TEST_CALLS" "ssh_agent $TEST_AGENT_SOCKET" "SSH must receive the selected dotfiles agent socket"
assert_contains "$TEST_CALLS" "-o ConnectTimeout=8 -o ConnectionAttempts=1 -o ServerAliveInterval=3 -o ServerAliveCountMax=2 -i $TEST_CASE_DIR/id_ed25519 -o IdentitiesOnly=yes -o AddKeysToAgent=no -o UseKeychain=yes windows-tail" "SSH must use bounded liveness, the pinned identity, and the configured alias"
assert_contains "$TEST_CALLS" 'pwsh.exe -NoLogo -NoProfile -NonInteractive -Command "& ([scriptblock]::Create([Console]::In.ReadToEnd()))"' "SSH must execute the complete stdin payload as one PowerShell script"
assert_contains "$TEST_CALLS" 'kill -TERM 4242' "Moonlight must receive graceful TERM"
assert_not_contains "$TEST_CALLS" 'kill -KILL' "responsive Moonlight must never receive KILL"
assert_contains "$TEST_CALLS" 'label=Game stopped' "game shutdown must report that the game stopped"
assert_not_contains "$TEST_CALLS" 'label=Done' "success feedback must not use a generic Done label"
assert_not_contains "$TEST_CALLS" 'label=Test Game' "remote game names must never become SketchyBar commands"
assert_before "$TEST_CALLS" 'open -gj -a Tailscale' 'tailscale up --timeout=12s' "Tailscale app must open before up"
assert_before "$TEST_CALLS" 'tailscale up --timeout=12s' 'ssh -T ' "Tailscale must connect before SSH"
assert_before "$TEST_CALLS" 'ssh -T ' 'kill -TERM 4242' "remote shutdown must finish before Moonlight closes"
[[ "$(head -1 "$TEST_SSH_STDIN")" == '$env:GAMING_STOP_MODE = "stop"' ]] || fail "stop opt-in must be the first PowerShell statement"
assert_contains "$TEST_SSH_STDIN" '$env:GAMING_STOP_MODE = "stop"' "SSH stdin must explicitly opt into stop mode"
assert_contains "$TEST_SSH_STDIN" 'Set-StrictMode -Version 3.0' "SSH must receive the committed PowerShell helper"
[[ ! -e "$GAMING_STOP_LOCK_DIR" ]] || fail "happy path must release its lock"

# 2. The connected path is the negative control for `tailscale up`: the first
# case proves the checker sees it, while this case proves it is skipped.
new_case already_connected
: >"$TEST_TS_ONLINE"
export STUB_SSH_JSON='{"Mode":"stop","SteamRunning":false,"SteamPidCount":0,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":false,"ReadyToStop":false,"Actions":["Steam was not running"],"Success":true}'
invoke_plugin
[[ "$last_status" -eq 0 ]] || fail "already-connected path should succeed"
assert_contains "$TEST_CALLS" 'tailscale status --json' "connected path must still inspect state"
assert_not_contains "$TEST_CALLS" 'tailscale up ' "connected path must not call tailscale up"
assert_not_contains "$TEST_CALLS" 'open -gj -a Tailscale' "connected path must not reopen Tailscale"
assert_contains "$TEST_CALLS" 'ssh -T ' "connected path must run SSH"
assert_not_contains "$TEST_CALLS" 'kill -' "absent Moonlight must be a no-op"
assert_contains "$TEST_CALLS" 'label=No Steam running' "absent Steam must produce contextual feedback"

# 3. Steam without a game gets its own successful outcome label.
new_case steam_only
: >"$TEST_TS_ONLINE"
export STUB_SSH_JSON='{"Mode":"stop","SteamRunning":true,"SteamPidCount":1,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":true,"ReadyToStop":false,"Actions":["confirmed Steam exited"],"Success":true}'
invoke_plugin
[[ "$last_status" -eq 0 ]] || fail "Steam-only stop should succeed"
assert_contains "$TEST_CALLS" 'label=Steam stopped' "Steam-only shutdown must report that Steam stopped"

# 4. A Tailscale failure skips both SSH and Moonlight, returns failure feedback,
# and releases the lock so a later click can retry.
new_case tailscale_failure
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_TS_UP_EXIT=7
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "Tailscale failure must return nonzero"
assert_not_contains "$TEST_CALLS" 'ssh -T ' "Tailscale failure must skip SSH"
assert_not_contains "$TEST_CALLS" 'kill -' "Tailscale failure must preserve Moonlight"
assert_contains "$TEST_CALLS" 'label=Failed' "Tailscale failure must show visible failure feedback"
[[ -e "$TEST_MOONLIGHT_RUNNING" ]] || fail "Tailscale failure must leave Moonlight running"
[[ ! -e "$GAMING_STOP_LOCK_DIR" ]] || fail "Tailscale failure must release its lock"

# 5. SSH/PowerShell failure likewise preserves the local viewer for diagnosis.
new_case ssh_failure
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_SSH_EXIT=9
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "SSH failure must return nonzero"
assert_contains "$TEST_CALLS" 'ssh -T ' "SSH failure case must attempt SSH"
assert_not_contains "$TEST_CALLS" 'kill -' "SSH failure must preserve Moonlight"
[[ -e "$TEST_MOONLIGHT_RUNNING" ]] || fail "SSH failure must leave Moonlight running"
[[ ! -e "$GAMING_STOP_LOCK_DIR" ]] || fail "SSH failure must release its lock"

# 6. A successful SSH transport with malformed output also fails closed.
new_case malformed_remote_result
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_SSH_JSON='not-json'
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "malformed remote result must fail"
assert_not_contains "$TEST_CALLS" 'kill -' "malformed remote result must preserve Moonlight"
assert_contains "$TEST_CALLS" 'label=Failed' "malformed remote result must show failure feedback"

# 7. Multiple otherwise-valid results are ambiguous and must fail closed.
new_case multiple_remote_results
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_SSH_JSON=$'{"Mode":"stop","SteamRunning":false,"SteamPidCount":0,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":false,"ReadyToStop":false,"Actions":["Steam was not running"],"Success":true}\n{"Mode":"stop","SteamRunning":false,"SteamPidCount":0,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":false,"ReadyToStop":false,"Actions":["Steam was not running"],"Success":true}'
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "multiple remote results must fail"
assert_not_contains "$TEST_CALLS" 'kill -' "multiple remote results must preserve Moonlight"

# 8. Contradictory but well-typed state must not receive a contextual label.
new_case inconsistent_remote_result
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_SSH_JSON='{"Mode":"stop","SteamRunning":false,"SteamPidCount":1,"RunningAppId":0,"RunningApps":[],"TrackedProcesses":[],"SteamExecutableTrusted":false,"ReadyToStop":false,"Actions":["Steam was not running"],"Success":true}'
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "inconsistent remote result must fail"
assert_not_contains "$TEST_CALLS" 'kill -' "inconsistent remote result must preserve Moonlight"
assert_contains "$TEST_CALLS" 'label=Failed' "inconsistent remote result must show failure feedback"

# 9. Invalid authentication configuration fails before SSH and preserves the
# local viewer instead of silently falling back to another identity.
new_case invalid_agent_override
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export GAMING_STOP_SSH_AUTH_SOCK="$TEST_CASE_DIR/not-a-socket"
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "invalid SSH agent override must fail"
assert_not_contains "$TEST_CALLS" 'ssh -T ' "invalid SSH agent override must skip SSH"
assert_not_contains "$TEST_CALLS" 'kill -' "invalid SSH agent override must preserve Moonlight"
assert_contains "$TEST_CALLS" 'label=Failed' "invalid SSH agent override must show failure feedback"

# 10. An unreadable pinned key also fails closed before opening SSH.
new_case missing_identity
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export GAMING_STOP_SSH_IDENTITY_FILE="$TEST_CASE_DIR/missing-id_ed25519"
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "missing pinned SSH identity must fail"
assert_not_contains "$TEST_CALLS" 'ssh -T ' "missing pinned SSH identity must skip SSH"
assert_not_contains "$TEST_CALLS" 'kill -' "missing pinned SSH identity must preserve Moonlight"

# 11. A stubborn but verified Moonlight PID gets exactly one TERM, then one KILL
# after the bounded wait. This is the only local force path.
new_case stubborn_moonlight
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_MOONLIGHT_STUBBORN=1
invoke_plugin
[[ "$last_status" -eq 0 ]] || fail "Moonlight KILL fallback should complete successfully"
[[ "$(grep -Fc 'kill -TERM 4242' "$TEST_CALLS")" -eq 1 ]] || fail "Moonlight must receive exactly one TERM"
[[ "$(grep -Fc 'kill -KILL 4242' "$TEST_CALLS")" -eq 1 ]] || fail "stubborn Moonlight must receive exactly one KILL fallback"
[[ ! -e "$TEST_MOONLIGHT_RUNNING" ]] || fail "KILL fallback must clear the verified Moonlight process"

# 12. Even a valid remote outcome must show Failed if Moonlight cannot close.
new_case unkillable_moonlight
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
export STUB_MOONLIGHT_STUBBORN=1
export STUB_MOONLIGHT_UNKILLABLE=1
invoke_plugin
[[ "$last_status" -ne 0 ]] || fail "unkillable Moonlight must fail the overall action"
assert_contains "$TEST_CALLS" 'label=Failed' "Moonlight failure must override contextual remote feedback"
assert_not_contains "$TEST_CALLS" 'label=Game stopped' "partial local failure must not display remote success"

# 13. Probe mode uses the same SSH/authentication path but never opts into a
# remote stop, signals Moonlight, or changes the live SketchyBar item.
new_case read_only_probe
: >"$TEST_TS_ONLINE"
: >"$TEST_MOONLIGHT_RUNNING"
invoke_probe
[[ "$last_status" -eq 0 ]] || fail "read-only probe should succeed"
[[ "$(head -1 "$TEST_SSH_STDIN")" == '$env:GAMING_STOP_MODE = "probe"' ]] || fail "probe opt-in must be the first PowerShell statement"
assert_contains "$TEST_CALLS" "ssh_agent $TEST_AGENT_SOCKET" "probe must use the selected dotfiles SSH agent"
assert_contains "$TEST_CALLS" 'ssh -T ' "probe must exercise the real SSH command path"
assert_not_contains "$TEST_CALLS" 'kill -' "probe must not signal Moonlight"
assert_not_contains "$TEST_CALLS" 'sketchybar --set' "probe must not alter button feedback"
[[ -e "$TEST_MOONLIGHT_RUNNING" ]] || fail "probe must leave Moonlight running"

# 14. Duplicate and non-left clicks are inert.
new_case duplicate_click
: >"$TEST_TS_ONLINE"
mkdir "$GAMING_STOP_LOCK_DIR"
invoke_plugin
[[ "$last_status" -eq 0 ]] || fail "duplicate click should be an idempotent no-op"
[[ ! -s "$TEST_CALLS" ]] || fail "duplicate click must not invoke an external action"
rmdir "$GAMING_STOP_LOCK_DIR"

new_case right_click
invoke_plugin right
[[ "$last_status" -eq 0 ]] || fail "right click should be an idempotent no-op"
[[ ! -s "$TEST_CALLS" ]] || fail "right click must not invoke an external action"

# 15. Static integration: SketchyBar can only reach the destructive action via
# click_script. The Amphetamine block is a known-positive control proving the
# update-script detector is live before it checks the gaming block's absence.
gaming_block="$TEST_CASE_DIR/gaming-block"
amphetamine_block="$TEST_CASE_DIR/amphetamine-block"
sed -n '/--add item gaming_stop right/,/^$/p' "$SKETCHYBARRC" >"$gaming_block"
sed -n '/--add item amphetamine right/,/^$/p' "$SKETCHYBARRC" >"$amphetamine_block"
assert_contains "$gaming_block" 'click_script="$PLUGIN_DIR/gaming_stop.sh"' "SketchyBar item must wire the click handler"
grep -Eq '^[[:space:]]*script=' "$amphetamine_block" || fail "positive control must detect an update script"
if grep -Eq '^[[:space:]]*script=' "$gaming_block"; then
	fail "gaming shutdown must never be wired as an update script"
fi

# The remote helper must remain fail-safe. Prove the unsafe-token checker with
# a positive fixture before asserting those force mechanisms are absent.
unsafe_fixture="$TEST_CASE_DIR/unsafe.ps1"
printf '%s\n' 'Stop-Process -Force' >"$unsafe_fixture"
grep -Eq 'Stop-Process|taskkill|force:1' "$unsafe_fixture" || fail "unsafe-token positive control is broken"
if grep -Eiq 'Stop-Process|taskkill|force:1' "$REMOTE_SCRIPT"; then
	fail "remote helper must not contain a forced process termination path"
fi
assert_contains "$REMOTE_SCRIPT" "if (\$Mode -eq 'probe')" "PowerShell helper must expose its read-only default path"
assert_contains "$REMOTE_SCRIPT" "'+app_stop'" "PowerShell helper must request the exact tracked AppID"
assert_contains "$REMOTE_SCRIPT" "@('-shutdown')" "PowerShell helper must request Steam shutdown only after the game"
assert_contains "$REMOTE_SCRIPT" 'Get-AuthenticodeSignature' "PowerShell helper must validate the Steam executable"
assert_contains "$REMOTE_SCRIPT" "Assert-NoSteamGameReported -Stage 'before Steam shutdown'" "PowerShell helper must re-check game signals before Steam shutdown"
assert_contains "$REMOTE_SCRIPT" "Assert-NoSteamGameReported -Stage 'after Steam shutdown'" "PowerShell helper must re-check game signals before reporting success"

assert_contains "$README" 'There is no public Steam API' "README must explain the Steam API limitation"
assert_contains "$README" 'No separate Moonlight' "README must explain Moonlight disconnect semantics"
assert_contains "$README" 'left open' "README must document partial-failure preservation"

if [[ "$fails" -ne 0 ]]; then
	echo "$fails gaming stop test(s) failed"
	exit 1
fi

echo "gaming stop tests passed"
