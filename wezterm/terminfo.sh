#!/usr/bin/env bash

if [[ $# -eq 0 ]] ; then
	tempfile=$(mktemp) &&
		curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo &&
		tic -x -o ~/.local/share/terminfo $tempfile &&
		tic -x -o ~/.terminfo $tempfile &&
		rm $tempfile
else
	# the first argument is the ssh host
	ssh "$1" 'tempfile=$(mktemp) &&
		curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo &&
		tic -x -o ~/.local/share/terminfo $tempfile &&
		tic -x -o ~/.terminfo $tempfile &&
		rm $tempfile'
fi



