tempfile=$(mktemp) &&
	curl -o $tempfile https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo &&
	tic -x -o ~/.local/share/terminfo $tempfile &&
	rm $tempfile
