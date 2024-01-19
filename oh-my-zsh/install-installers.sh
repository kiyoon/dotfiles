#!/usr/bin/env bash
# Install conda, node and rustup.
# Run `source ~/.cargo/env` afterwards to activate rustup (cargo install)

INSTALL_DIR="$HOME/.local"

if [[ $OSTYPE == "darwin"* ]]; then
	brew install --cask miniconda
	brew install node
else
	##### conda
	if ! command -v conda &>/dev/null; then
		mkdir -p "$HOME/bin"
		wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -P "$HOME/bin"
		CONDADIR="$HOME/bin/miniconda3"
		bash "$HOME/bin/Miniconda3-latest-Linux-x86_64.sh" -b -p "$CONDADIR"
		rm "$HOME/bin/Miniconda3-latest-Linux-x86_64.sh"
	fi

	if ! command -v $INSTALL_DIR/bin/npm &>/dev/null; then
		curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$INSTALL_DIR" -y
	fi
fi


# rustup, cargo
if ! command -v rustc &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
fi
