#!/usr/bin/env bash
# Install conda, uv, node and rustup.
# Run `source ~/.cargo/env` afterwards to activate rustup (cargo install)

INSTALL_DIR="$HOME/.local"
# PIP3="/usr/bin/python3 -m pip"

if [[ $OSTYPE == "darwin"* ]]; then
	# brew install --cask miniconda
	brew install node
    brew install bun
else
	if ! command -v "$INSTALL_DIR"/bin/npm &>/dev/null; then
		curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$INSTALL_DIR" -y
	fi

    if ! command -v bun &>/dev/null; then
        curl -fsSL https://bun.sh/install | bash
    else
        bun upgrade
    fi
fi

if [[ $OSTYPE == "darwin"* ]]; then
    brew install uv
else
    if ! command -v uv &>/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        uv self update
    fi
fi

##### conda
if ! command -v conda &>/dev/null; then
	mkdir -p "$HOME/bin"
	wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -P "$HOME/bin"
	CONDADIR="$HOME/bin/miniforge3"
	bash "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh" -b -p "$CONDADIR"
	rm "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh"
else
    mamba update mamba -y
fi

# rustup, cargo
if [[ $OSTYPE == "darwin"* ]]; then
    brew install rustup
    brew install cargo-binstall
else
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
        source "$HOME/.cargo/env"
        rustup default stable
        # cargo-binstall
        curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
    else
        rustup self update
        cargo binstall cargo-binstall
    fi
fi
