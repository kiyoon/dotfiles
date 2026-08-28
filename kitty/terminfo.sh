#!/usr/bin/env bash
# Install the xterm-kitty terminfo, locally or on an ssh host.
# Usually unnecessary: kitty sets TERMINFO locally, and `kitten ssh host`
# copies the terminfo automatically. This is for plain ssh to servers,
# like ../wezterm/terminfo.sh.

# infocmp needs to find xterm-kitty; outside a kitty session fall back
# to the terminfo bundled with kitty.app.
dump_terminfo() {
	infocmp -a xterm-kitty 2>/dev/null ||
		infocmp -A /Applications/kitty.app/Contents/Resources/kitty/terminfo -a xterm-kitty
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
