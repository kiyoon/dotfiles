#!/usr/bin/env bash
# Compiles helpers/codexbar_usage_watcher.swift and renders synthetic CodexBar
# snapshots with --once --no-sketchybar, asserting on the summary line it
# prints: <provider>=on[<top>,<bottom>[,local]]. The optional third token marks
# a bottom lane filled from helpers/codex_local_usage.py output. The last block
# runs the watcher for real against a stub scan script to check that scans are
# driven by rollout changes, not by a timer.
# Run: bash sketchybar/tests/test_codexbar_usage_watcher.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
SOURCE="$CONFIG_DIR/helpers/codexbar_usage_watcher.swift"
SWIFTC="${SWIFTC:-swiftc}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/codexbar_usage_watcher"
OUT="$TMP/out"

fails=0
fail() {
	printf 'FAIL: %s\n' "$1"
	fails=$((fails + 1))
}

if ! "$SWIFTC" -O "$SOURCE" -o "$BIN" -framework AppKit; then
	fail "compile"
	exit 1
fi

# Fixture windows are relative to the real clock: the lane logic compares
# resets_at with "now".
WEEKLY_RESET="$(date -u -v+6d +%Y-%m-%dT%H:%M:%SZ)"
SESSION_RESET="$(date -u -v+3H +%Y-%m-%dT%H:%M:%SZ)"
OLDER_RESET="$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OLD_ISO="$(date -u -v-2d +%Y-%m-%dT%H:%M:%SZ)"

snapshot() { # show_used weekly_only(1|0) -> path
	local show_used="$1" weekly_only="$2" path="$TMP/snapshot_${1}_${2}.json"
	local rows='{"id":"weekly","title":"Weekly","percentLeft":70,"window":{"windowMinutes":10080,"usedPercent":30,"resetsAt":"'"$WEEKLY_RESET"'"}}'
	if [[ "$weekly_only" == 0 ]]; then
		rows='{"id":"session","title":"5h","percentLeft":80,"window":{"windowMinutes":300,"usedPercent":20,"resetsAt":"'"$SESSION_RESET"'"}},'"$rows"
	fi
	cat >"$path" <<JSON
{"enabledProviders":["codex","claude"],"generatedAt":"$NOW_ISO","usageBarsShowUsed":$show_used,
 "entries":[
  {"provider":"codex","creditsRemaining":0,"usageRows":[$rows],
   "secondary":{"windowMinutes":10080,"usedPercent":30,"resetsAt":"$WEEKLY_RESET"}},
  {"provider":"claude","primary":{"windowMinutes":300,"usedPercent":10,"resetsAt":"$SESSION_RESET"},
   "secondary":{"windowMinutes":10080,"usedPercent":20,"resetsAt":"$WEEKLY_RESET"}}
 ]}
JSON
	printf '%s' "$path"
}

usage() { # generated_at resets_at local_percent [stale] -> path
	local path="$TMP/usage_$RANDOM.json"
	cat >"$path" <<JSON
{"version":1,"generated_at":"$1","limit_id":"codex","stale":${4:-false},
 "windows":[{"window_minutes":10080,"window_start":"2026-09-05T18:30:14Z","resets_at":"$2",
  "observed_used_percent":30.0,"stale":${4:-false},"local_used_percent":$3,
  "percent_by_model":{"gpt-6-astra":$3},"responses":10}]}
JSON
	printf '%s' "$path"
}

render() { # snapshot usage -> codex summary token
	local out
	out="$("$BIN" --once --no-sketchybar --snapshot "$1" --local-usage "$2" --output-dir "$OUT" 2>"$TMP/stderr")" \
		|| fail "watcher exited non-zero for $1 / $2: $(cat "$TMP/stderr")"
	printf '%s' "$out" | tr ' ' '\n' | /usr/bin/grep '^codex=' || printf 'none'
}

assert_codex() {
	local actual="$1" expected="$2" message="$3"
	[[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

WEEKLY_ONLY="$(snapshot false 1)"
WEEKLY_ONLY_USED="$(snapshot true 1)"
TWO_LANES="$(snapshot false 0)"

assert_codex "$(render "$WEEKLY_ONLY" "$TMP/missing.json")" "codex=on[70.0,nil]" \
	"no local file leaves the bottom lane empty"
[[ -s "$OUT/codex.png" ]] || fail "codex.png not rendered"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 27.1)")" "codex=on[70.0,27.1,local]" \
	"fresh local usage fills the empty bottom lane as used percent"

assert_codex "$(render "$WEEKLY_ONLY_USED" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 27.1)")" "codex=on[30.0,27.1,local]" \
	"local lane is used-percent regardless of the show-used toggle"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$OLD_ISO" "$WEEKLY_RESET" 27.1)")" "codex=on[70.0,27.1,local]" \
	"an old scan result stays valid while its window is current (nothing polls it)"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$NOW_ISO" "$OLDER_RESET" 64.0)")" "codex=on[70.0,0.0,local]" \
	"a result for a window that has ended means nothing local in the current one"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 0.0)")" "codex=on[70.0,0.0,local]" \
	"zero local usage is an empty full-height lane"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 35.0)")" "codex=on[70.0,30.0,local]" \
	"local share never exceeds the account-wide used percent"

assert_codex "$(render "$TWO_LANES" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 27.1)")" "codex=on[80.0,70.0]" \
	"CodexBar's own second lane wins over local usage"

assert_codex "$(render "$WEEKLY_ONLY" "$(usage "$NOW_ISO" "$WEEKLY_RESET" 27.1 true)")" "codex=on[70.0,0.0,local]" \
	"stale window flag renders as zero local usage"

printf '{"version":1,"generated_at":"%s","windows":"nope"}' "$NOW_ISO" >"$TMP/broken.json"
assert_codex "$(render "$WEEKLY_ONLY" "$TMP/broken.json")" "codex=on[70.0,nil]" \
	"malformed local usage is ignored"

# --- live run: scans follow rollout changes, not a clock ---
LIVE="$TMP/live"
mkdir -p "$LIVE/sessions/2026/09/06" "$LIVE/out"
STUB="$LIVE/scan.py"
cat >"$STUB" <<'PY'
import json, os, sys
# Stand-in for codex_local_usage.py: log the call, emit a plausible usage file.
args = sys.argv[1:]
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "calls"), "a") as log:
    log.write(" ".join(args) + "\n")
out = args[args.index("--output") + 1]
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as handle:
    json.dump({"version": 1, "generated_at": "2026-01-01T00:00:00Z", "limit_id": "codex", "stale": False,
               "windows": [{"window_minutes": 10080, "resets_at": os.environ["TEST_RESET"],
                            "local_used_percent": 27.1, "stale": False}]}, handle)
PY
wait_for_calls() { # count timeout_seconds
	local deadline=$((SECONDS + $2))
	while ((SECONDS < deadline)); do
		[[ -f "$LIVE/calls" && "$(wc -l <"$LIVE/calls" | tr -d ' ')" -ge "$1" ]] && return 0
		sleep 0.2
	done
	return 1
}
TEST_RESET="$WEEKLY_RESET" "$BIN" --no-sketchybar --snapshot "$WEEKLY_ONLY" \
	--local-usage "$LIVE/out/usage.json" --output-dir "$LIVE/out" \
	--sessions "$LIVE/sessions" --local-usage-script "$STUB" \
	--scan-debounce 0.5 --scan-min-interval 1 >"$LIVE/log" 2>&1 &
WATCHER_PID=$!
trap 'kill "$WATCHER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

wait_for_calls 1 10 || fail "startup scan did not run"
/usr/bin/grep -q -- '--sessions '"$LIVE/sessions"' --output '"$LIVE/out/usage.json"' --cache '"$LIVE/out/cache.json" "$LIVE/calls" \
	|| fail "scan invoked with unexpected arguments: $(cat "$LIVE/calls" 2>/dev/null)"
sleep 4
assert_codex "$(wc -l <"$LIVE/calls" | tr -d ' ')" 1 "no scan without rollout changes"
/usr/bin/grep -q 'codex=on\[70.0,27.1,local\]' "$LIVE/log" || fail "startup scan result not rendered: $(cat "$LIVE/log")"

printf '{"type":"turn_context"}\n' >>"$LIVE/sessions/2026/09/06/rollout-x.jsonl"
wait_for_calls 2 15 || fail "rollout change did not trigger a scan"
printf '{"type":"turn_context"}\n' >>"$LIVE/sessions/2026/09/06/rollout-x.jsonl"
printf '{"type":"turn_context"}\n' >>"$LIVE/sessions/2026/09/06/rollout-x.jsonl"
wait_for_calls 3 15 || fail "second burst did not trigger a scan"
sleep 3
assert_codex "$(wc -l <"$LIVE/calls" | tr -d ' ')" 3 "a burst of appends coalesces into one scan"

kill "$WATCHER_PID" 2>/dev/null
wait "$WATCHER_PID" 2>/dev/null

if ((fails == 0)); then
	echo "PASS: codexbar_usage_watcher"
	exit 0
fi
exit 1
