#!/usr/bin/env bash
# Install the xterm-ghostty terminfo, locally or on an ssh host.
# Usually unnecessary locally: Ghostty sets TERMINFO to the terminfo bundled
# with Ghostty.app. This is for plain ssh to servers, like ../wezterm/terminfo.sh.
# (Ghostty can also do this on ssh with `shell-integration-features = ssh-terminfo`.)

# infocmp needs to find xterm-ghostty; outside a Ghostty session fall back
# to the terminfo bundled with Ghostty.app. -x keeps the extended
# capabilities (truecolor, undercurl, synchronized output, cursor shape, ...).
dump_terminfo() {
	infocmp -x xterm-ghostty 2>/dev/null ||
		infocmp -x -A /Applications/Ghostty.app/Contents/Resources/terminfo xterm-ghostty
}

if [[ $# -eq 0 ]]; then
	tempfile=$(mktemp) &&
		dump_terminfo >"$tempfile" &&
		tic -x -o ~/.local/share/terminfo "$tempfile" &&
		tic -x -o ~/.terminfo "$tempfile" &&
		rm "$tempfile"
else
	# the first argument is the ssh host
	dump_terminfo | ssh "$1" 'tempfile=$(mktemp) &&
		cat >"$tempfile" &&
		tic -x -o ~/.local/share/terminfo "$tempfile" &&
		tic -x -o ~/.terminfo "$tempfile" &&
		rm "$tempfile"'
fi
