#!/usr/bin/env bash

# This should be installed on your local machine, not on the server where you have neovim

if [[ "$OSTYPE" == "darwin"* ]]; then
	brew tap homebrew/cask-fonts
	brew install font-jetbrains-mono-nerd-font
	brew install font-fira-code
    # brew install font-cascadia-code-nf
    # brew install font-caskaydia-cove-nerd-font
else
	TEMPDIR=$(mktemp -d)
	FONTDIR="$HOME/.local/share/fonts"

	# fontname="UbuntuMono"
	# fontname="FiraCode"
	fontname="JetBrainsMono"
	# fontname="CascadiaCode"

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
		unzip "$TEMPDIR/nf.zip" -d "$TEMPDIR"/nerd-fonts
		rm "$TEMPDIR/nerd-fonts/*"" Nerd Font "*" Windows Compatible.ttf"
		mv "$TEMPDIR"/nerd-fonts/*.ttf "$FONTDIR"

		# NOTE: we need non-NF FiraCode for python rich export_svg -> cairosvg PDF generation
		mkdir -p "$TEMPDIR/firacode"
		curl -s https://api.github.com/repos/tonsky/FiraCode/releases/latest |
			grep "browser_download_url.*.zip" |
			cut -d : -f 2,3 |
			tr -d \" |
			wget -qi - -O "$TEMPDIR/firacode.zip"
		unzip "$TEMPDIR/firacode.zip" -d "$TEMPDIR"/firacode
		mv "$TEMPDIR"/firacode/ttf/*.ttf "$FONTDIR"

		fc-cache -fv
	else
		echo "Nerd Font is already installed"
	fi
fi
