PIP3="/usr/bin/python3 -m pip"

# check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "(Linux) Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
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

    brew install tree-sitter-cli

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
if command -v dotnet &> /dev/null; then
    dotnet tool install csharpier -g
else
    echo "dotnet could not be found. Skipping CSharpier installation."
fi

if ! command -v stylua &> /dev/null; then
	bun install -g @johnnymorganz/stylua-bin
fi

if ! command -v prettier &> /dev/null; then
	bun install -g prettier
fi

bun install -g tree-sitter-cli@latest

# cargo-binstall downloads prebuilt binaries (no compile). No command -v guards needed:
# it skips if already up to date and upgrades if outdated. The curl line installs or
# updates binstall itself into ~/.cargo/bin (cargo finds subcommands there).
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

# wilder.nvim, telescope.nvim
cargo binstall -y fd-find
# ripgrep for telescope.nvim
cargo binstall -y ripgrep
# view images in terminal, used in telescope preview etc.
cargo binstall -y viu

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
