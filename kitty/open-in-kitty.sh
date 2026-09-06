#!/usr/bin/env bash
# Open the given paths in kitty. Files resolve to their parent folder; with no
# arguments, the frontmost Finder window's folder is used.
#
#   open-in-kitty.sh [--tab] [PATH...]
#
# Drives the running kitty over its remote control socket, so the new window or
# tab lands in the kitty you are already using. --single-instance cannot do this:
# it only joins instances that were themselves started with that flag, and kitty
# launched from the Dock was not. When no kitty is running, a new one starts.
#
# The env vars below exist so tests can stub every external command.

set -uo pipefail
shopt -s nullglob

KITTY_BIN="${KITTY_BIN:-/opt/homebrew/bin/kitty}"
OPEN_BIN="${OPEN_BIN:-/usr/bin/open}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"
# kitty.conf sets `listen_on unix:/tmp/kitty`; kitty appends its own pid.
KITTY_SOCKET_DIR="${KITTY_SOCKET_DIR:-/tmp}"

launch_type="os-window"
if [[ ${1:-} == "--tab" ]]; then
	launch_type="tab"
	shift
fi

# Newest socket whose pid is still alive. Sockets outlive the kitty that made
# them, so /tmp accumulates stale ones; picking purely by mtime targets a
# corpse and the launch silently does nothing.
live_socket() {
	local newest="" socket pid
	for socket in "$KITTY_SOCKET_DIR"/kitty-*; do
		[[ -S $socket ]] || continue
		pid="${socket##*/kitty-}"
		[[ $pid =~ ^[0-9]+$ ]] || continue
		kill -0 "$pid" 2>/dev/null || continue
		if [[ -z $newest || $socket -nt $newest ]]; then
			newest="$socket"
		fi
	done
	printf '%s' "$newest"
}

frontmost_finder_folder() {
	"$OSASCRIPT_BIN" -e '
		tell application "Finder"
			if (count of windows) is 0 then return POSIX path of (path to home folder)
			return POSIX path of (target of front window as alias)
		end tell'
}

dirs=()
if [[ $# -eq 0 ]]; then
	folder="$(frontmost_finder_folder)"
	folder="${folder%/}"
	[[ -n $folder ]] && dirs+=("$folder")
else
	for item in "$@"; do
		if [[ -d $item ]]; then
			dirs+=("$item")
		else
			dirs+=("$(dirname "$item")")
		fi
	done
fi

[[ ${#dirs[@]} -eq 0 ]] && exit 0

socket="$(live_socket)"

for dir in "${dirs[@]}"; do
	if [[ -n $socket ]]; then
		"$KITTY_BIN" @ --to "unix:$socket" launch \
			--type="$launch_type" --cwd="$dir"
	else
		"$OPEN_BIN" -na kitty --args --directory "$dir"
	fi
done

# Remote control creates the window behind Finder; only `open` raises kitty.
[[ -n $socket ]] && "$OPEN_BIN" -a kitty

exit 0
