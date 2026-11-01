#!/usr/bin/env bash
# Install the xterm-kitty terminfo, locally or on an ssh host.
# Usually unnecessary: kitty sets TERMINFO locally, and `kitten ssh host`
# copies the terminfo automatically. This is for plain ssh to servers,
# like ../wezterm/terminfo.sh, and for shells that point TERMINFO elsewhere,
# as ../oh-my-zsh/custom/01_env.zsh does on Linux.

# infocmp finds xterm-kitty inside a kitty session; otherwise ask kitty where its
# bundled terminfo is. kitty.app's command-line binary may not be on the macOS PATH.
dump_terminfo() {
	infocmp -a xterm-kitty 2>/dev/null && return
	local kitty
	kitty=$(command -v kitty || echo /Applications/kitty.app/Contents/MacOS/kitty)
	infocmp -a -A "$("$kitty" +runpy 'from kitty.constants import terminfo_dir; print(terminfo_dir)')" xterm-kitty
}

if [[ $# -eq 0 ]]; then
	tempfile=$(mktemp) &&
		dump_terminfo >"$tempfile" &&
		mkdir -p ~/.local/share/terminfo ~/.terminfo &&
		tic -x -o ~/.local/share/terminfo "$tempfile" &&
		tic -x -o ~/.terminfo "$tempfile" &&
		rm "$tempfile"
else
	# the first argument is the ssh host
	dump_terminfo | ssh "$1" 'tempfile=$(mktemp) &&
		cat >"$tempfile" &&
		mkdir -p ~/.local/share/terminfo ~/.terminfo &&
		tic -x -o ~/.local/share/terminfo "$tempfile" &&
		tic -x -o ~/.terminfo "$tempfile" &&
		rm "$tempfile"'
fi
