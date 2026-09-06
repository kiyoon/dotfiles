#!/usr/bin/env bash
# Unit test for helpers/codex_local_usage.py: builds synthetic Codex rollout
# files and asserts on the JSON it writes (window detection from the newest
# rate-limit observation, per-model weighting, Spark exclusion, legacy
# token_count fallback, incremental cache, stale window).
# Run: bash sketchybar/tests/test_codex_local_usage.sh
set -u
# The synthetic clock sits in 2026-08-31 (KST), so fixture rollouts live in
# date dirs Codex would have used then: 2026/08/31 (recent) and 2026/08/20 (old).

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
HELPER="$CONFIG_DIR/helpers/codex_local_usage.py"
PYTHON="${PYTHON:-/usr/bin/python3}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SESS="$TMP/sessions"
OUT="$TMP/usage.json"
CACHE="$TMP/cache.json"
CALIB="$TMP/calibration.json"

fails=0
fail() {
	printf 'FAIL: %s\n' "$1"
	fails=$((fails + 1))
}

assert_eq() {
	local actual="$1" expected="$2" message="$3"
	if [[ "$actual" != "$expected" ]]; then
		fail "$message (expected '$expected', got '$actual')"
	fi
}

# Window: weekly, resets_at R, start = R - 7d. "now" sits inside the window.
R=1788774949
START=$((R - 604800))
NOW=$((START + 1000))

iso() { "$PYTHON" -c 'import sys,datetime; print(datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"))' "$1"; }

turn_context() { # ts model
	printf '{"timestamp":"%s","type":"turn_context","payload":{"turn_id":"t","model":"%s"}}\n' "$(iso "$1")" "$2"
}
record() { # ts response_id input cached output
	printf '{"timestamp":"%s","type":"token_usage_record","payload":{"thread_id":"x","turn_id":"t","session_id":"x","response_id":"%s","usage":{"input_tokens":%d,"cached_input_tokens":%d,"cache_write_input_tokens":0,"output_tokens":%d,"reasoning_output_tokens":0,"total_tokens":%d}}}\n' \
		"$(iso "$1")" "$2" "$3" "$4" "$5" "$(($3 + $5))"
}
token_count() { # ts limit_id used_percent resets_at input cached output
	printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":2},"last_token_usage":{"input_tokens":%d,"cached_input_tokens":%d,"cache_write_input_tokens":0,"output_tokens":%d,"reasoning_output_tokens":0,"total_tokens":%d},"model_context_window":258400},"rate_limits":{"limit_id":"%s","limit_name":null,"primary":{"used_percent":%s,"window_minutes":10080,"resets_at":%d},"secondary":null,"plan_type":"pro"}}}\n' \
		"$(iso "$1")" "$5" "$6" "$7" "$(($5 + $7))" "$2" "$3" "$4"
}

mkdir -p "$SESS/2026/08/31" "$SESS/2026/08/20"
A="$SESS/2026/08/31/rollout-2026-08-31T19-00-00-aaaa.jsonl"
B="$SESS/2026/08/31/rollout-2026-08-31T19-10-00-bbbb.jsonl"
C="$SESS/2026/08/20/rollout-2026-08-20T11-00-00-cccc.jsonl"
D="$SESS/2026/08/31/rollout-2026-08-31T19-20-00-dddd.jsonl"
E="$SESS/2026/08/20/rollout-2026-08-20T12-00-00-eeee.jsonl"

{
	printf '{"timestamp":"%s","type":"session_meta","payload":{"id":"aaaa","originator":"codex-tui"}}\n' "$(iso $((START - 100)))"
	turn_context $((START - 100)) gpt-6-astra
	record $((START - 60)) r0 1000 0 0 # before the window: excluded
	token_count $((START - 59)) codex 10.0 "$R" 1 0 0
	record $((START + 100)) r1 1100 100 10 # 1000 + 10 + 80 = 1090 units
	token_count $((START + 101)) codex 12.0 "$R" 1 0 0
	turn_context $((START + 200)) gpt-5.3-codex-spark
	record $((START + 200)) r2 5000 0 0 # Spark: separate bucket, excluded
	token_count $((START + 201)) codex_bengalfox 3.0 $((R + 99999)) 1 0 0
	turn_context $((START + 299)) gpt-6-astra
	record $((START + 300)) r3 2000 1000 100 # 1000 + 100 + 800 = 1900 units
	token_count $((START + 301)) codex 15.0 "$R" 1 0 0
} >"$A"

{
	# Legacy file (CLI before token_usage_record): usage comes from token_count.
	printf '{"timestamp":"%s","type":"session_meta","payload":{"id":"bbbb","originator":"codex-tui"}}\n' "$(iso $((START + 350)))"
	turn_context $((START + 350)) gpt-5.6-sol
	token_count $((START + 400)) codex 16.0 "$R" 3000 2000 50 # 1000 + 200 + 400 = 1600 units
} >"$B"

{
	# Old file (mtime 10 days ago) claiming a different window: must be skipped.
	turn_context $((START + 500)) gpt-6-astra
	record $((START + 500)) r9 100000 0 0
	token_count $((START + 501)) codex 99.0 $((R + 500000)) 1 0 0
} >"$C"
touch -t "$("$PYTHON" -c 'import sys,datetime; print(datetime.datetime.fromtimestamp(int(sys.argv[1]) - 10 * 86400).strftime("%Y%m%d%H%M"))' "$START")" "$C"

printf '{"gpt-6-astra": 1000, "gpt-5.6-sol": 800, "*": 500}\n' >"$CALIB"

STATS=""
run() {
	local out
	out="$("$PYTHON" "$HELPER" --sessions "$SESS" --output "$OUT" --cache "$CACHE" \
		--calibration "$CALIB" --now "$1" --print "${@:2}")" || fail "helper exited $? (now=$1)"
	STATS="$(printf '%s\n' "$out" | /usr/bin/sed -n 's/^stats=//p')"
}
q() { jq -r "$1" "$OUT"; }
st() { jq -r "$1" <<<"$STATS"; }
sums() { cksum "$OUT" "$CACHE" | cut -d' ' -f1 | paste -sd, -; }
qn() { jq -r "($1) + 0" "$OUT"; } # jq 1.7 keeps literals like 17.0; normalise numbers

# --- first run ---
run "$NOW"
[[ -s "$OUT" ]] || fail "no output written"
assert_eq "$(q '.limit_id')" codex "limit id"
assert_eq "$(q '.stale')" false "not stale inside the window"
assert_eq "$(q '.windows | length')" 1 "one weekly window"
assert_eq "$(qn '.windows[0].window_minutes')" 10080 "window minutes"
assert_eq "$(qn '.windows[0].resets_at_epoch')" "$R" "resets_at from newest codex observation"
assert_eq "$(qn '.windows[0].window_start_epoch')" "$START" "window start = resets_at - window"
assert_eq "$(qn '.windows[0].observed_used_percent')" 16 "observed percent from newest codex event"
assert_eq "$(qn '.windows[0].local_used_percent')" 4.99 "local percent = 2990/1000 + 1600/800"
assert_eq "$(qn '.windows[0].percent_by_model["gpt-6-astra"]')" 2.99 "astra share"
assert_eq "$(qn '.windows[0].percent_by_model["gpt-5.6-sol"]')" 2 "sol share via legacy fallback"
assert_eq "$(qn '.windows[0].responses')" 3 "responses counted in window"
assert_eq "$(qn '.excluded_models["gpt-5.3-codex-spark"]')" 5000 "spark units reported but excluded"
assert_eq "$(st '.files_parsed')" 2 "old file skipped by mtime"
assert_eq "$(st '.full_walk')" true "first run walks the whole tree"

# --- unchanged rerun uses the cache and writes nothing ---
before_sums="$(sums)"
run "$NOW"
assert_eq "$(st '.files_parsed')" 0 "nothing reparsed when files are unchanged"
assert_eq "$(st '.full_walk')" false "second run lists only recent date dirs"
assert_eq "$(st '.wrote_output')" false "unchanged result is not rewritten"
assert_eq "$(st '.wrote_cache')" false "unchanged cache is not rewritten"
assert_eq "$(sums)" "$before_sums" "output and cache bytes untouched by an idle run"
assert_eq "$(qn '.windows[0].local_used_percent')" 4.99 "same result from cache"

# --- append: only the new bytes are read ---
before=$(wc -c <"$A")
{
	record $((START + 600)) r4 1000 0 0 # +1000 units = +1.0%
	token_count $((START + 601)) codex 17.0 "$R" 1 0 0
} >>"$A"
after=$(wc -c <"$A")
run $((START + 1200))
assert_eq "$(st '.files_parsed')" 1 "only the appended file reparsed"
assert_eq "$(st '.bytes_read')" $((after - before)) "only appended bytes read"
assert_eq "$(st '.wrote_output')" true "changed result is written"
assert_eq "$(qn '.windows[0].local_used_percent')" 5.99 "appended response counted"
assert_eq "$(qn '.windows[0].observed_used_percent')" 17 "observed percent advanced"

# --- partial trailing line is left for the next run ---
printf '{"timestamp":"x","type":"token_usage_record","payload":{"resp' >>"$A"
run $((START + 1300))
assert_eq "$(qn '.windows[0].local_used_percent')" 5.99 "partial line ignored"
printf 'onse_id":"r5"}}\n' >>"$A"
run $((START + 1400))
assert_eq "$(qn '.windows[0].local_used_percent')" 5.99 "malformed completed line ignored"

# --- a new rollout in a recent date dir is found by the cheap listing ---
{
	turn_context $((START + 1500)) gpt-6-astra
	record $((START + 1500)) r7 1000 0 0 # +1.0%
	token_count $((START + 1501)) codex 18.0 "$R" 1 0 0
} >"$D"
run $((START + 1600))
assert_eq "$(st '.full_walk')" false "still a cheap run"
assert_eq "$(qn '.windows[0].local_used_percent')" 6.99 "new file in a recent date dir counted"

# --- a fresh rollout in an old date dir waits for the next full walk ---
{
	turn_context $((START + 1700)) gpt-6-astra
	record $((START + 1700)) r8 1000 0 0 # +1.0%
	token_count $((START + 1701)) codex 19.0 "$R" 1 0 0
} >"$E"
run $((START + 1800))
assert_eq "$(qn '.windows[0].local_used_percent')" 6.99 "cheap run does not see old date dirs"
run $((START + 1900)) --full-walk
assert_eq "$(st '.full_walk')" true "forced full walk"
assert_eq "$(qn '.windows[0].local_used_percent')" 7.99 "full walk picks up the resumed old thread"

# --- window rolled over with no local activity since ---
run $((R + 10))
assert_eq "$(q '.stale')" true "stale after resets_at"
assert_eq "$(qn '.windows[0].local_used_percent')" 0 "no local usage in the unseen new window"

# --- new observation re-anchors the window (reset credit) ---
R2=$((START + 1900 + 604800)) # reset credit applied at START+1900
{
	turn_context $((START + 2000)) gpt-6-astra
	record $((START + 2000)) r6 500 0 0
	token_count $((START + 2001)) codex 1.0 "$R2" 1 0 0
} >>"$B"
run $((START + 2100))
assert_eq "$(qn '.windows[0].resets_at_epoch')" "$R2" "newest observation wins"
assert_eq "$(qn '.windows[0].window_start_epoch')" $((R2 - 604800)) "window re-anchored"
# Only r6 (500 units) lands after the new window start.
assert_eq "$(qn '.windows[0].local_used_percent')" 0.5 "only usage after the new start counts"

if ((fails == 0)); then
	echo "PASS: codex_local_usage"
	exit 0
fi
exit 1
