#!/usr/bin/env bash

# This should be installed on your local machine, not on the server where you have neovim

TEMPDIR=$(mktemp -d)
FONTDIR="$HOME/.local/share/fonts"

# fontname="UbuntuMono"
# fontname="FiraCode"
fontname="JetBrainsMono"

# nerd fonts
if [ ! command -v fc-list ] &>/dev/null || ! fc-list | grep -q "$fontname Nerd Font"; then
	echo "Nerd Font could not be found. Installing $fontname NF on $FONTDIR"
	mkdir -p "$FONTDIR"
	mkdir -p "$TEMPDIR/nerd-fonts"
	curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest |
		grep "browser_download_url.*$fontname.zip" |
		cut -d : -f 2,3 |
		tr -d \" |
		wget -qi - -O "$TEMPDIR/nf.zip"
	unzip "$TEMPDIR/nf.zip" -d $TEMPDIR/nerd-fonts
	rm "$TEMPDIR/nerd-fonts/*"" Nerd Font "*" Windows Compatible.ttf"
	mv $TEMPDIR/nerd-fonts/*.ttf "$FONTDIR"
	#rm -rf $TEMPDIR/nerd-fonts
	#rm "$TEMPDIR/ubuntumononf.zip"
	fc-cache -fv
else
	echo "Nerd Font is already installed"
fi
