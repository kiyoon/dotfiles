#!/usr/bin/env bash
# Bootstrap standalone uv, Bun, rustup and cargo-binstall, mise, Oh My Zsh and conda on macOS/Linux.
set -euo pipefail

export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$HOME/.local/bin:$PATH"

# Rust/Cargo stay outside mise. Install a stable toolchain for cargo install/binstall,
# but preserve an existing rustup default and let rustup select project toolchains.
if ! command -v rustup &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable
else
    rustup toolchain install stable --profile minimal
    if ! rustup default &>/dev/null; then
        rustup default stable
    fi
fi

# cargo-binstall also stays with Cargo, outside mise, for ad-hoc `cargo binstall` use.
if [[ $OSTYPE == "darwin"* ]]; then
    brew install cargo-binstall
elif ! command -v cargo-binstall &>/dev/null; then
    curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
fi

# Keep runners outside mise so background commands can use stable executable paths.
# Check standalone paths on Linux: an inherited PATH may still contain mise tools.
if [[ $OSTYPE == "darwin"* ]]; then
    brew install uv bun
else
    if [[ -x "$HOME/.local/bin/uv" ]]; then
        "$HOME/.local/bin/uv" self update
    else
        curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="$HOME/.local/bin" sh
    fi

    export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
    if [[ -x "$BUN_INSTALL/bin/bun" ]]; then
        "$BUN_INSTALL/bin/bun" upgrade
    else
        curl -fsSL https://bun.sh/install | bash
    fi
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

# Official standalone mise installer works on both macOS and Linux, without sudo.
if ! command -v mise &>/dev/null; then
    curl -fsSL https://mise.run | sh
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

##### conda
if [[ -x "$HOME/bin/miniforge3/bin/mamba" ]]; then
    "$HOME/bin/miniforge3/bin/mamba" update mamba -y
elif ! command -v conda &>/dev/null; then
	mkdir -p "$HOME/bin"
	wget "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -P "$HOME/bin"
	CONDADIR="$HOME/bin/miniforge3"
	bash "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh" -b -p "$CONDADIR"
	rm "$HOME/bin/Miniforge3-$(uname)-$(uname -m).sh"
elif command -v mamba &>/dev/null; then
    mamba update mamba -y
fi
