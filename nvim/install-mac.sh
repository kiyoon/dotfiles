#!/usr/bin/env bash

LOCALBIN="$HOME/.local/bin"

if ! command -v node &> /dev/null; then
	curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$HOME/.local" -y
fi

pip3 install --user virtualenv # for Mason.nvim
pip3 install --user pynvim
npm install -g neovim

# DAP
pip3 install --user debugpy

# Lint
pipx install ruff

# Formatter
pipx install isort
pipx install black
brew install stylua

if ! command -v prettier &> /dev/null; then
	npm install -g prettier
fi

if [[ ! -d "$HOME/.local/lib/node_modules/prettier-plugin-toml" ]]; then
	npm install -g prettier-plugin-toml
fi

if ! command -v tree-sitter &> /dev/null; then
	npm install -g tree-sitter-cli
fi

# wilder.nvim, telescope.nvim
brew install fd

# ripgrep for telescope.nvim
brew install ripgrep
brew install viu
