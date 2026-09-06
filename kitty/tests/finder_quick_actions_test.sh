#!/usr/bin/env bash
# Tests for open-in-kitty.sh and finder-quick-actions.sh. Every external
# command is stubbed; this test never launches kitty, never touches
# ~/Library/Services, and never talks to Finder.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$HERE")"
OPENER="$CONFIG_DIR/open-in-kitty.sh"
INSTALLER="$CONFIG_DIR/finder-quick-actions.sh"
README="$CONFIG_DIR/README.md"

TEST_TMP="$(mktemp -d)"
STUB_DIR="$TEST_TMP/bin"
SOCKET_DIR="$TEST_TMP/sockets"
mkdir -p "$STUB_DIR" "$SOCKET_DIR"
trap 'rm -rf "$TEST_TMP"' EXIT

fails=0

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

# --- stubs -------------------------------------------------------------

# Records every invocation, one line per call, into $TEST_TMP/<name>.log
make_stub() {
	local name="$1"
	cat >"$STUB_DIR/$name" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TEST_TMP/$name.log"
exit 0
STUB
	chmod +x "$STUB_DIR/$name"
}

make_stub kitty
make_stub open
cat >"$STUB_DIR/osascript" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TEST_TMP/osascript.log"
cat "$TEST_TMP/finder-folder"
STUB
chmod +x "$STUB_DIR/osascript"

# A live socket owned by a running pid, and a stale one from a dead pid.
LIVE_PID=$$
DEAD_PID=999999
python3 - "$SOCKET_DIR/kitty-$LIVE_PID" "$SOCKET_DIR/kitty-$DEAD_PID" <<'PY'
import socket, sys
for path in sys.argv[1:]:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
PY
# Age the live socket so the stale one is unambiguously the newest: picking by
# mtime alone must land on the dead pid. Same-second mtimes would let the live
# one win by glob order and hide a missing liveness check.
touch -t 202001010000 "$SOCKET_DIR/kitty-$LIVE_PID"

run_opener() {
	rm -f "$TEST_TMP"/kitty.log "$TEST_TMP"/open.log "$TEST_TMP"/osascript.log
	KITTY_BIN="$STUB_DIR/kitty" \
		OPEN_BIN="$STUB_DIR/open" \
		OSASCRIPT_BIN="$STUB_DIR/osascript" \
		KITTY_SOCKET_DIR="$SOCKET_DIR" \
		"$OPENER" "$@" >"$TEST_TMP/stdout" 2>"$TEST_TMP/stderr"
	echo $? >"$TEST_TMP/status"
	touch "$TEST_TMP"/kitty.log "$TEST_TMP"/open.log "$TEST_TMP"/osascript.log
}

# --- open-in-kitty.sh --------------------------------------------------

if [[ ! -x "$OPENER" ]]; then
	fail "$OPENER is missing or not executable"
else
	mkdir -p "$TEST_TMP/a folder"
	echo hi >"$TEST_TMP/a folder/file.txt"

	run_opener "$TEST_TMP/a folder"
	assert_contains "$TEST_TMP/kitty.log" "--cwd=$TEST_TMP/a folder" \
		"a folder argument should open at that folder"
	assert_contains "$TEST_TMP/kitty.log" "--type=os-window" \
		"without --tab the launch type should be os-window"
	assert_contains "$TEST_TMP/kitty.log" "--to unix:$SOCKET_DIR/kitty-$LIVE_PID" \
		"should target the socket whose pid is alive"
	assert_not_contains "$TEST_TMP/kitty.log" "kitty-$DEAD_PID" \
		"should ignore a stale socket left by a dead pid"

	run_opener "$TEST_TMP/a folder/file.txt"
	assert_contains "$TEST_TMP/kitty.log" "--cwd=$TEST_TMP/a folder" \
		"a file argument should open at its parent folder"
	# Without this, the assertion above also matches the unresolved
	# --cwd=.../a folder/file.txt, since grep -F matches substrings.
	assert_not_contains "$TEST_TMP/kitty.log" "file.txt" \
		"a file argument should not be passed to kitty as the cwd"

	run_opener --tab "$TEST_TMP/a folder"
	assert_contains "$TEST_TMP/kitty.log" "--type=tab" \
		"--tab should launch a tab instead of an os-window"

	run_opener "$TEST_TMP/a folder" "$TEST_TMP/a folder/file.txt"
	if [[ "$(wc -l <"$TEST_TMP/kitty.log")" -ne 2 ]]; then
		fail "two selected items should produce two launches"
	fi

	echo "$TEST_TMP/a folder" >"$TEST_TMP/finder-folder"
	run_opener
	assert_contains "$TEST_TMP/kitty.log" "--cwd=$TEST_TMP/a folder" \
		"with no arguments it should fall back to the frontmost Finder folder"

	# Raising kitty is what makes the new window/tab visible.
	run_opener "$TEST_TMP/a folder"
	assert_contains "$TEST_TMP/open.log" "-a" \
		"should activate kitty so the new window is focused"

	# No live socket: kitty is not running, so start it at the folder.
	KITTY_BIN="$STUB_DIR/kitty" OPEN_BIN="$STUB_DIR/open" \
		OSASCRIPT_BIN="$STUB_DIR/osascript" \
		KITTY_SOCKET_DIR="$TEST_TMP/empty" \
		"$OPENER" "$TEST_TMP/a folder" >/dev/null 2>&1
	assert_contains "$TEST_TMP/open.log" "-na" \
		"with no live socket it should launch a new kitty instance"
	assert_contains "$TEST_TMP/open.log" "--directory $TEST_TMP/a folder" \
		"the fallback launch should still use the selected folder"
fi

# --- finder-quick-actions.sh -------------------------------------------

DEST="$TEST_TMP/Services"
WINDOW_ACTION="$DEST/Open in kitty.workflow"
TAB_ACTION="$DEST/Open in kitty tab.workflow"

if [[ ! -x "$INSTALLER" ]]; then
	fail "$INSTALLER is missing or not executable"
else
	if ! "$INSTALLER" --dest "$DEST" >"$TEST_TMP/install.out" 2>&1; then
		fail "installer exited non-zero: $(cat "$TEST_TMP/install.out")"
	fi

	for action in "$WINDOW_ACTION" "$TAB_ACTION"; do
		name="$(basename "$action")"
		for part in Contents/Info.plist Contents/document.wflow; do
			if [[ ! -f "$action/$part" ]]; then
				fail "$name is missing $part"
				continue
			fi
			plutil -lint "$action/$part" >/dev/null 2>&1 ||
				fail "$name/$part is not a valid plist"
		done
	done

	if [[ -f "$WINDOW_ACTION/Contents/Info.plist" ]]; then
		menu="$(/usr/libexec/PlistBuddy -c "Print :NSServices:0:NSMenuItem:default" \
			"$WINDOW_ACTION/Contents/Info.plist" 2>/dev/null)"
		[[ "$menu" == "Open in kitty" ]] ||
			fail "window action menu title should be 'Open in kitty', got '$menu'"
		context="$(/usr/libexec/PlistBuddy -c "Print :NSServices:0:NSRequiredContext:NSApplicationIdentifier" \
			"$WINDOW_ACTION/Contents/Info.plist" 2>/dev/null)"
		[[ "$context" == "com.apple.finder" ]] ||
			fail "window action should only appear in Finder, got '$context'"
	fi

	if [[ -f "$TAB_ACTION/Contents/Info.plist" ]]; then
		menu="$(/usr/libexec/PlistBuddy -c "Print :NSServices:0:NSMenuItem:default" \
			"$TAB_ACTION/Contents/Info.plist" 2>/dev/null)"
		[[ "$menu" == "Open in kitty tab" ]] ||
			fail "tab action menu title should be 'Open in kitty tab', got '$menu'"
	fi

	if [[ -f "$WINDOW_ACTION/Contents/document.wflow" ]]; then
		assert_contains "$WINDOW_ACTION/Contents/document.wflow" "open-in-kitty.sh" \
			"window action should call open-in-kitty.sh"
		assert_not_contains "$WINDOW_ACTION/Contents/document.wflow" "--tab" \
			"window action should not pass --tab"
	fi
	if [[ -f "$TAB_ACTION/Contents/document.wflow" ]]; then
		assert_contains "$TAB_ACTION/Contents/document.wflow" "--tab" \
			"tab action should pass --tab"
	fi

	# Re-running must not fail or duplicate.
	"$INSTALLER" --dest "$DEST" >/dev/null 2>&1 ||
		fail "installer should be safe to re-run"

	"$INSTALLER" --dest "$DEST" --uninstall >/dev/null 2>&1 ||
		fail "uninstall should exit zero"
	[[ ! -e "$WINDOW_ACTION" && ! -e "$TAB_ACTION" ]] ||
		fail "uninstall should remove both quick actions"
fi

# --- documentation -----------------------------------------------------

assert_contains "$README" "finder-quick-actions.sh" \
	"README should document the installer"

if [[ $fails -eq 0 ]]; then
	echo "PASS: all finder quick action tests"
else
	echo "$fails test(s) failed"
	exit 1
fi
