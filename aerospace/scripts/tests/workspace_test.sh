#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/workspace.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-workspace-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/aerospace" <<'EOF'
#!/usr/bin/env bash
printf 'aerospace %s\n' "$*" >>"$CALLS"
case "$1" in
list-windows)
	printf '%s\n' "${FAKE_FOCUSED_WINDOW:-77}"
	;;
list-monitors)
	printf '%s\n' "${FAKE_FOCUSED_MONITOR:-2}"
	;;
list-workspaces)
	printf '%s\n' 1 2 4
	;;
eval)
	[[ "${FAKE_AEROSPACE_FAIL:-}" != "eval" ]]
	;;
move-node-to-workspace)
	[[ "${FAKE_AEROSPACE_FAIL:-}" != "move" ]]
	;;
esac
EOF

cat >"$TMP/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf 'sketchybar %s\n' "$*" >>"$CALLS"
[[ "${FAKE_SKETCHYBAR_FAIL:-0}" != "1" ]]
EOF

cat >"$TMP/open" <<'EOF'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >>"$CALLS"
EOF

chmod +x "$TMP/aerospace" "$TMP/sketchybar" "$TMP/open"

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

run_workspace() {
	local name="$1"
	shift
	: >"$TMP/$name.calls"
	CALLS="$TMP/$name.calls" \
		AEROSPACE="$TMP/aerospace" \
		SKETCHYBAR="$TMP/sketchybar" \
		OPEN="$TMP/open" \
		"$@" /bin/bash "$SCRIPT" "$name"
}

run_workspace_fails() {
	local name="$1"
	shift
	if run_workspace "$name" "$@"; then
		fail=$((fail + 1))
		printf 'FAIL %s unexpectedly succeeded\n' "$name" >&2
	else
		pass=$((pass + 1))
	fi
}

# A direct invocation captures the focused window. Workspace 3 is summoned on
# that window's monitor before the explicit-id move. The bar refresh is a
# post-eval barrier and therefore sees the final app -> workspace mapping.
run_workspace move-window-new /usr/bin/env
check move-window-new-order \
	$'aerospace list-windows --focused --format %{window-id}\naerospace list-workspaces --all\naerospace eval focus --window-id 77 && summon-workspace -- 3 && move-node-to-workspace --window-id 77 --focus-follows-window -- 3\nsketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=3 REFRESH_NOW=1' \
	"$(cat "$TMP/move-window-new.calls")"

# Explicit context remains supported for manual/callback use and avoids a
# global-focus query.
run_workspace move-window-new /usr/bin/env AEROSPACE_WINDOW_ID=88
check move-window-forwarded-context \
	$'aerospace list-workspaces --all\naerospace eval focus --window-id 88 && summon-workspace -- 3 && move-node-to-workspace --window-id 88 --focus-follows-window -- 3\nsketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=3 REFRESH_NOW=1' \
	"$(cat "$TMP/move-window-new.calls")"

# Existing-workspace moves also emit one final-state event. The target is
# resolved inside AeroSpace's stdin command, so the delayed renderer obtains
# the authoritative focused workspace from its own final snapshot.
run_workspace move-window-next-used /usr/bin/env
check move-window-used-order \
	$'aerospace list-workspaces --monitor focused --empty no\naerospace move-node-to-workspace --focus-follows-window --stdin --wrap-around next\nsketchybar --trigger aerospace_workspace_change REFRESH_NOW=1' \
	"$(cat "$TMP/move-window-next-used.calls")"

run_workspace_fails move-window-next-used /usr/bin/env FAKE_AEROSPACE_FAIL=move
if grep -q '^sketchybar ' "$TMP/move-window-next-used.calls"; then
	fail=$((fail + 1))
	echo "FAIL failed existing-workspace move must not refresh SketchyBar" >&2
else
	pass=$((pass + 1))
fi

# alt-shift-space captures its monitor, re-focuses it inside the one eval, and
# summons a genuinely new empty workspace there before LaunchServices runs.
run_workspace open-terminal-new /usr/bin/env FAKE_FOCUSED_MONITOR=2
check terminal-workspace-order \
	$'aerospace list-monitors --focused --format %{monitor-id}\naerospace list-workspaces --all\naerospace eval focus-monitor -- 2 && summon-workspace -- 3\nsketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=3 REFRESH_NOW=1\nopen -n -a WezTerm' \
	"$(cat "$TMP/open-terminal-new.calls")"

if grep -q 'move-workspace-to-monitor' "$TMP/move-window-new.calls" "$TMP/open-terminal-new.calls"; then
	fail=$((fail + 1))
	echo "FAIL new-workspace actions must never relocate a main-monitor workspace" >&2
else
	pass=$((pass + 1))
fi

# A failed AeroSpace operation must not claim success in the bar or launch a
# terminal into whichever workspace happened to remain focused.
run_workspace_fails move-window-new /usr/bin/env FAKE_AEROSPACE_FAIL=eval
if grep -q '^sketchybar ' "$TMP/move-window-new.calls"; then
	fail=$((fail + 1))
	echo "FAIL failed window move must not refresh SketchyBar" >&2
else
	pass=$((pass + 1))
fi

run_workspace_fails open-terminal-new /usr/bin/env FAKE_AEROSPACE_FAIL=eval
if grep -Eq '^(sketchybar|open) ' "$TMP/open-terminal-new.calls"; then
	fail=$((fail + 1))
	echo "FAIL failed workspace summon must not refresh or open WezTerm" >&2
else
	pass=$((pass + 1))
fi

# Bar IPC is cosmetic and must not prevent a successfully summoned terminal.
run_workspace open-terminal-new /usr/bin/env FAKE_SKETCHYBAR_FAIL=1
grep -qx 'open -n -a WezTerm' "$TMP/open-terminal-new.calls" || {
	fail=$((fail + 1))
	echo "FAIL SketchyBar failure must not block WezTerm" >&2
}
grep -qx 'open -n -a WezTerm' "$TMP/open-terminal-new.calls" &&
	pass=$((pass + 1))

printf 'pass=%d fail=%d\n' "$pass" "$fail"
((fail == 0))
