#!/usr/bin/env bash

if command -v brew &> /dev/null; then
	if command -v pipx &> /dev/null; then
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
		brew install prettier

		brew install tree-sitter

		# wilder.nvim, telescope.nvim
		brew install fd

		# ripgrep for telescope.nvim
		brew install ripgrep
		brew install viu
		exit 0
	fi
fi

if [[ $OSTYPE == "darwin"* ]]; then
	echo "MacOS detected but either brew or pipx is not installed. Exiting."
	exit 1
fi

LOCALBIN="$HOME/.local/bin"

pip3 install --user virtualenv # for Mason.nvim
pip3 install --user pynvim
npm install -g neovim

# DAP
pip3 install --user debugpy

# Lint
# pip3 install --user flake8
pip3 install --user ruff

# Formatter
pip3 install --user isort 
pip3 install --user black

if ! command -v stylua &> /dev/null; then
	npm install -g @johnnymorganz/stylua-bin
fi

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
if ! command -v fd &> /dev/null; then
	npm install -g fd-find
fi

# ripgrep for telescope.nvim

if ! command -v rg &> /dev/null; then
	echo "ripgrep (rg) could not be found. Installing on $LOCALBIN"
	TEMPDIR=$(mktemp -d)
	mkdir -p "$LOCALBIN"
	mkdir -p $TEMPDIR
	curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest \
		| grep "browser_download_url.*-x86_64-unknown-linux-musl.tar.gz" \
		| cut -d : -f 2,3 \
		| tr -d \" \
		| wget -qi - -O - | tar -xz --strip-components=1 -C $TEMPDIR
	mv $TEMPDIR/rg "$LOCALBIN"
	rm -rf $TEMPDIR
else
	echo "ripgrep found at $(which rg). Skipping installation."
fi

if ! command -v viu &> /dev/null; then
	cargo install viu
fi
