#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/monitor.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-monitor-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/aerospace" <<'EOF'
#!/usr/bin/env bash
printf 'aerospace %s\n' "$*" >>"$CALLS"
case "$1" in
list-monitors)
	if [[ "$*" == *"--focused"* ]]; then
		printf '%s\n' 2
	else
		printf '%s\n' 1 2
	fi
	;;
list-windows)
	printf '%s\n' "${FAKE_WINDOW_MONITOR:-Built-in Retina Display}"
	;;
move-node-to-monitor)
	if [[ "${FAKE_FAIL_ALL_MOVES:-0}" == "1" ]]; then
		exit 1
	elif [[ "${FAKE_FAIL_DIRECT:-0}" == "1" && "$*" != *"--wrap-around"* ]]; then
		exit 1
	fi
	;;
esac
EOF

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf 'sketchybar %s\n' "$*" >>"$CALLS"
[[ "${FAKE_SKETCHYBAR_FAIL:-0}" != "1" ]]
EOF

cat >"$TMP/osascript" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'LG Left' 'LG Right'
EOF

chmod +x "$TMP/aerospace" "$TMP/sketchybar" "$TMP/osascript"

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

run_monitor() {
	local name="$1"
	shift
	: >"$TMP/$name.calls"
	printf '%s\n' '1 2' >"$TMP/aerospace-monitor-history"
	CALLS="$TMP/$name.calls" \
		AEROSPACE="$TMP/aerospace" \
		SKETCHYBAR="$TMP/sketchybar" \
		XDG_CACHE_HOME="$TMP" \
		PATH="$TMP:$PATH" \
		"$@" /bin/bash "$SCRIPT" "$name"
}

run_monitor move-recent /usr/bin/env
check move-recent-final-event \
	$'aerospace list-monitors\naerospace list-monitors --focused --format %{monitor-id}\naerospace move-node-to-monitor --focus-follows-window 1\nsketchybar --trigger aerospace_workspace_change REFRESH_NOW=1' \
	"$(cat "$TMP/move-recent.calls")"

# If the remembered monitor disappeared, the wrapped fallback is the successful
# final operation and still produces exactly one reconciliation event.
run_monitor move-recent /usr/bin/env FAKE_FAIL_DIRECT=1
check move-recent-fallback-event \
	$'aerospace list-monitors\naerospace list-monitors --focused --format %{monitor-id}\naerospace move-node-to-monitor --focus-follows-window 1\naerospace move-node-to-monitor --focus-follows-window --wrap-around next\nsketchybar --trigger aerospace_workspace_change REFRESH_NOW=1' \
	"$(cat "$TMP/move-recent.calls")"

if run_monitor move-recent /usr/bin/env FAKE_FAIL_ALL_MOVES=1; then
	fail=$((fail + 1))
	echo "FAIL failed recent-monitor move unexpectedly succeeded" >&2
else
	pass=$((pass + 1))
fi
if grep -q '^sketchybar ' "$TMP/move-recent.calls"; then
	fail=$((fail + 1))
	echo "FAIL failed recent-monitor move must not refresh SketchyBar" >&2
else
	pass=$((pass + 1))
fi

run_monitor move-main-toggle /usr/bin/env
check move-toggle-final-event \
	$'aerospace list-windows --focused --format %{monitor-name}\naerospace move-node-to-monitor --focus-follows-window ^LG Right$\nsketchybar --trigger aerospace_workspace_change REFRESH_NOW=1' \
	"$(cat "$TMP/move-main-toggle.calls")"

run_monitor move-main-toggle /usr/bin/env FAKE_FAIL_ALL_MOVES=1
if grep -q '^sketchybar ' "$TMP/move-main-toggle.calls"; then
	fail=$((fail + 1))
	echo "FAIL failed toggle move must not refresh SketchyBar" >&2
else
	pass=$((pass + 1))
fi

# SketchyBar is cosmetic; its IPC failure must not turn a successful move into
# a failed hotkey action.
if run_monitor move-main-toggle /usr/bin/env FAKE_SKETCHYBAR_FAIL=1; then
	pass=$((pass + 1))
else
	fail=$((fail + 1))
	echo "FAIL SketchyBar failure must not fail monitor move" >&2
fi

printf 'pass=%d fail=%d\n' "$pass" "$fail"
((fail == 0))
