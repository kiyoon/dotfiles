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

$PIP3 install --user --break-system-packages virtualenv # for Mason.nvim
bun install -g neovim

# Install to the virtual environment
# DAP
uv pip install -U debugpy
# molten.nvim
uv pip install -U pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip

if command -v brew &> /dev/null; then
    # Lint
    brew install ruff
    brew install biome

    # Formatter
    brew install stylua
    brew install prettier
    brew install taplo

    brew install tree-sitter

    # wilder.nvim, telescope.nvim
    brew install fd

    # ripgrep for telescope.nvim
    brew install ripgrep
    brew install viu

    # molten.nvim
    brew install imagemagick
    brew install pkg-config  # for magick from luarocks

    exit 0
fi

if [[ $OSTYPE == "darwin"* ]]; then
	echo "MacOS detected but brew is not installed. Exiting."
	exit 1
fi

LOCALBIN="$HOME/.local/bin"

# Lint
uv tool install -U ruff
bun install -g @biomejs/biome

# Formatter
bun install -g @taplo/cli

if command -v dotnet &> /dev/null; then
    dotnet tool install csharpier -g
else
    echo "dotnet could not be found. Skipping CSharpier installation."
fi

if ! command -v stylua &> /dev/null; then
	npm install -g @johnnymorganz/stylua-bin
fi

if ! command -v prettier &> /dev/null; then
	bun install -g prettier
fi

if ! command -v tree-sitter &> /dev/null; then
	bun install -g tree-sitter-cli
fi

# wilder.nvim, telescope.nvim
if ! command -v fd &> /dev/null; then
	bun install -g fd-find
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

# view images in terminal, used in telescope preview etc.
if ! command -v viu &> /dev/null; then
	cargo install viu
fi

# molten.nvim
# We need to extract the AppImage because the luarocks magick (bundled in this dotfiles)
# requires the shared libraries.
INSTALL_DIR=$(nvim --clean --headless +'lua io.write(vim.fn.stdpath("data"))' +qa)/magick  # ~/.local/share/nvim/magick
mkdir -p "$INSTALL_DIR"
curl -s https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest \
    | grep "browser_download_url.*ImageMagick-.*-gcc-x86_64.AppImage" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | wget -qi - -O magick.appimage
chmod +x magick.appimage
./magick.appimage --appimage-extract
# NOTE: installing libglib will break the system's package manager.
# Many apps depend on it and it won't work.
# We need to remove libglib from the extracted AppImage.
rm squashfs-root/usr/lib/libglib-2.0.so.0
rsync -a squashfs-root/usr/ "$INSTALL_DIR"/
rm magick.appimage
rm -rf squashfs-root
