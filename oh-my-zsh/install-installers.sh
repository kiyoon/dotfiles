#!/usr/bin/env bash
# Install conda, uv, node and rustup.
# Run `source ~/.cargo/env` afterwards to activate rustup (cargo install)

INSTALL_DIR="$HOME/.local"
PIP3="/usr/bin/python3 -m pip"

if [[ $OSTYPE == "darwin"* ]]; then
	# brew install --cask miniconda
	brew install node
else
	if ! command -v "$INSTALL_DIR"/bin/npm &>/dev/null; then
		curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$INSTALL_DIR" -y
	fi
fi

if [[ $OSTYPE == "darwin"* ]]; then
    brew install uv
else
    $PIP3 install --user --break-system-packages uv 
fi

##### conda
if ! command -v conda &>/dev/null; then
	mkdir -p "$HOME/bin"
	wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -P "$HOME/bin"
	CONDADIR="$HOME/bin/miniforge3"
	bash "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh" -b -p "$CONDADIR"
	rm "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh"
fi

# rustup, cargo
if ! command -v rustc &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
fi
