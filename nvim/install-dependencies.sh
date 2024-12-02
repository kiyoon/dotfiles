PIP3="/usr/bin/python3 -m pip"

# check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "(Linux) Install with: pip3 install --user --break-system-packages uv"
    echo "(Mac) Install with: brew install uv"
    exit 1
fi

path_to_venv="$HOME/.virtualenvs/neovim"

if [[ -f "$path_to_venv" ]]; then
    echo "Error: $path_to_venv is a file"
    exit 1
fi

if [[ ! -d "$path_to_venv" ]]; then
    uv venv "$path_to_venv" --python 3.12
fi

source "$path_to_venv/bin/activate"

if command -v brew &> /dev/null; then
	if command -v pipx &> /dev/null; then
		$PIP3 install --user --break-system-packages virtualenv # for Mason.nvim
		# $PIP3 install --user --break-system-packages pynvim
        uv pip install pynvim
		npm install -g neovim

		# DAP
		# $PIP3 install --user --break-system-packages debugpy
        uv pip install debugpy

		# Csv align
		# $PIP3 install --user --break-system-packages polars
        uv pip install polars typer

		# Lint
        brew install ruff

		# Formatter
		brew install stylua
		brew install prettier

		brew install tree-sitter

		# wilder.nvim, telescope.nvim
		brew install fd

		# ripgrep for telescope.nvim
		brew install ripgrep
		brew install viu

		# molten.nvim
		brew install imagemagick
		brew install pkg-config  # for magick from luarocks
		# $PIP3 install --user --break-system-packages pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
        uv pip install pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip

		exit 0
	fi
fi

if [[ $OSTYPE == "darwin"* ]]; then
	echo "MacOS detected but either brew or pipx is not installed. Exiting."
	exit 1
fi

LOCALBIN="$HOME/.local/bin"

$PIP3 install --user --break-system-packages virtualenv # for Mason.nvim
$PIP3 install --user --break-system-packages pynvim
npm install -g neovim

# DAP
$PIP3 install --user --break-system-packages debugpy

# Csv align
$PIP3 install --user --break-system-packages polars
$PIP3 install --user --break-system-packages typer

# Find python imports in a project
$PIP3 install --user --break-system-packages tree-sitter
$PIP3 install --user --break-system-packages tree-sitter-python

# Lint
# $PIP3 install --user flake8
$PIP3 install --user --break-system-packages ruff

# Formatter
# $PIP3 install --user --break-system-packages isort 
# $PIP3 install --user --break-system-packages black

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
	echo "ripgrep (rg) could not be found. Installing in $LOCALBIN"
	TEMPDIR=$(mktemp -d)
	mkdir -p "$LOCALBIN"
	curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest \
		| grep "browser_download_url.*-x86_64-unknown-linux-musl.tar.gz" \
		| cut -d : -f 2,3 \
		| tr -d \" \
		| wget -qi - -O - | tar -xz --strip-components=1 -C "$TEMPDIR"
	mv "$TEMPDIR"/rg "$LOCALBIN"
	rm -rf "$TEMPDIR"
else
	echo "ripgrep found at $(which rg). Skipping installation."
fi

if ! command -v viu &> /dev/null; then
	cargo install viu
fi

# molten.nvim
# We need to extract the AppImage because the luarocks magick (bundled in this dotfiles)
# requires the shared libraries.
if ! command -v magick &> /dev/null; then
	echo "ImageMagick could not be found. Installing in $LOCALBIN"
	mkdir -p ~/.local
	curl -s https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest \
		| grep "browser_download_url.*ImageMagick--gcc-x86_64.AppImage" \
		| cut -d : -f 2,3 \
		| tr -d \" \
		| wget -qi - -O magick.appimage
	chmod +x magick.appimage
	./magick.appimage --appimage-extract
	# NOTE: installing libglib will break the system's package manager.
	# Many apps depend on it and it won't work.
	# We need to remove libglib from the extracted AppImage.
	rm squashfs-root/usr/lib/libglib-2.0.so.0
	rsync -a squashfs-root/usr/ ~/.local/
	rm magick.appimage
	rm -rf squashfs-root
else
	echo "ImageMagick found at $(which magick). Skipping installation."
fi
# $PIP3 install --user --break-system-packages pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
uv pip install pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
