#!/usr/bin/env bash
set -eo pipefail

# Standalone CLI tools (including uv, bun and ImageMagick's magick CLI) live in
# mise-config/config.toml. This script manages ~/.virtualenvs/neovim directly,
# outside mise, and also installs the Node provider.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv &>/dev/null; then
    echo "uv is required. Install it and activate your shell's tool environment first." >&2
    exit 1
fi

path_to_venv="$HOME/.virtualenvs/neovim"
if [[ ! -e "$path_to_venv" && ! -L "$path_to_venv" ]]; then
    uv venv "$path_to_venv" --python 3.12
fi
if [[ ! -f "$path_to_venv/pyvenv.cfg" || ! -x "$path_to_venv/bin/python3" ]]; then
    echo "Error: $path_to_venv exists but is not a working Python venv; leaving it untouched." >&2
    exit 1
fi

# Explicitly target the venv without activating it or touching system/project Python.
# pynvim: Neovim's Python provider.
# debugpy: nvim-dap-python, which uses the provider's Python interpreter.
# jupyter_client, cairosvg, plotly, kaleido, pnglatex, pyperclip: molten.nvim.
# Tmux hooks use system Python; tmux/install-plugins.sh installs their dependencies.
uv pip install --python "$path_to_venv/bin/python3" --upgrade \
    pynvim debugpy jupyter_client cairosvg plotly kaleido pnglatex pyperclip

# Mason.nvim's Python package installations need the standalone virtualenv CLI.
uv tool install --upgrade virtualenv

bun install -g neovim

# Formatter
if command -v dotnet &> /dev/null && ! command -v csharpier &> /dev/null; then
    dotnet tool install csharpier -g
elif ! command -v dotnet &> /dev/null; then
    echo "dotnet could not be found. Skipping CSharpier installation."
fi
