#!/usr/bin/env bash

INSTALL_DIR="$HOME/.local"

brew install wget
brew install pidof

##### oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

##### conda
if ! command -v conda &>/dev/null; then
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
	CONDADIR="$HOME/bin/miniconda3"
	mkdir -p "$HOME/bin"
	bash Miniconda3-latest-MacOSX-arm64.sh -b -p "$CONDADIR"
	rm Miniconda3-latest-MacOSX-arm64.sh
	$CONDADIR/bin/conda init
fi

##### zoxide
brew install zoxide
brew install fzf
brew install pipx
brew install thefuck

##### Starship prompt
if ! command -v starship &>/dev/null; then
	sh -c "$(curl -fsSL https://starship.rs/install.sh)" sh -b "$INSTALL_DIR/bin" -y
fi

pip3 install --user pygments # colorize (ccat)
pip3 install --user pillow   # my custom ranger viu image viewer uses this

# install ranger from github
TEMPDIR=$(mktemp -d)
git clone --depth=1 https://github.com/ranger/ranger "$TEMPDIR"
pip3 install --user "$TEMPDIR"


if ! command -v "$INSTALL_DIR/bin/npm" &>/dev/null; then
	curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$INSTALL_DIR" -y
fi

# rustup, cargo
if ! command -v rustup &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
fi

brew install fd
brew install tig
brew install exa

brew install gh
gh extension install github/gh-copilot
gh extension upgrade gh-copilot

brew install jq
brew install viu
brew install bat
brew install bottom
brew install dust
brew install procs
brew install csvlens
brew install helix
