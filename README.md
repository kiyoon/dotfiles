# dotfiles that work without sudo

This is a modern Neovim, Tmux, Zsh configuration that supports installing everything locally (i.e. non-system-wide user install, not using sudo).  
You can enjoy working on a remote SSH server without root permission, just like you do locally.

> [!NOTE]
> Currently I'm experimenting with a tranparent terminal background.
> If you want to turn it off, change transparent settings in `wezterm/wezterm.lua` and `nvim/lua/kiyoon/tokyonight.lua`.

![image](https://user-images.githubusercontent.com/12980409/218476082-8c400daf-7d9d-4d15-bf7a-f6b41d9191d9.png)

![image](https://user-images.githubusercontent.com/12980409/218475937-c9a51b2d-b4d6-499f-8787-012770410209.png)

![image](https://user-images.githubusercontent.com/12980409/218476252-9de93e0c-ddfe-486b-979a-5ded6a9425a9.png)

## Keep it stable!

This repository includes a GitHub Actions that automatically checks if the commit hasn't been made for 1 week.  
If it has not been updated for 1 week, we consider that commit to be 'stable' and automatically bump version with `stable` tag.  
In order to try the stable version, just run `dotstable` after setting up the zsh. This will also pull neovim plugin versions that have been used for the stable commit.

Also, it has many versions of vim configurations.

- `vi` to run a fully-featured bleeding-edge configuration of neovim.
- `vic` to run neovim with stable and mild configuration using CoC. It's a balance between the two, and should be used when the first option is broken.
- `lazyvim` to run pre-configured [LazyVim](https://github.com/LazyVim/LazyVim).
- `vim` to run original vim with no plugins (only simple `.vimrc`)
- `csvi` to read CSV files. `:CsvAlign` or `:TsvAlign` to align columns and `H`, `L` to move by columns.
- Use `vscode_init.lua` for VSCode-Neovim.

## Features

### Zsh

- Feature-rich prompt powered by [Starship](https://starship.rs)
- Autocomplete, autosuggest
- Syntax highlighting
- Vim mode
- Fuzzy searching with [fzf](https://github.com/junegunn/fzf)
  - Try `Ctrl+t` to find file, `Alt+c` to change directory, `Ctrl+r` to reverse search commands.
- Smart change directory with [Zoxide](https://github.com/ajeetdsouza/zoxide)
  - Try `z <partial dirname..>` like `z dot` will go to the `~/.config/dotfiles`.
- Move between prompts: (OSC 133)
  - In Tmux: Ctrl + Alt + k/j
  - Outside Tmux (WezTerm setting): Shift + Up/Down
- Copy to clipboard: (OSC 52)
  - `osc52copy`, `cppath`, `cpfile` command
  - Ctrl + o to copy the current command

### Neovim

My main frameworks/languages: Python (PyTorch, FastAPI), TypeScript (React), C# (Unity), Rust, Lua (Neovim)

- Yank registers synchronised with tmux. Yank from neovim and paste on tmux. Copy from tmux and paste on neovim.
- Copy to clipboard: (OSC 52)
  - `<space>y`
- See more in [nvim/README.md](nvim/README.md)

### Tmux

- Mouse-enabled interactive tree view with [Treemux](https://github.com/kiyoon/treemux)
- Status bar that shows battery, CPU, GPU, RAM, weather, and git with [tmux-dracula fork](https://github.com/kiyoon/tmux-dracula)
- See more in [tmux/README.md](tmux/README.md)

## Requirements

- Linux x86-64, macOS, Windows WSL2
- Neovim v0.12.4 (make sure you use this exact version)
- Tmux v3.7 or newer
- Zsh v5.9 (in v5.8 highlighting will look weird and fzf-tab will remove some lines)


## Steps

1. Install dotfiles

```bash
cd ~/.config	# it doesn't have to be here. Just install anywhere
git clone https://github.com/kiyoon/dotfiles

# WARNING: ./symlink.sh will override existing dotfiles without validation (but will create a backup).
# The old dotfiles will be moved with '~' suffix.
# Use with care if you configured something manually.
cd dotfiles
./symlink.sh
```

2. Install Zsh, mise, CLI tools and Oh My Zsh

On macOS, install Homebrew first for Zsh and the system-library dependencies.
On Linux, the local Zsh build needs a C compiler, make, curl, wget and rsync.
The global [mise config](mise-config/config.toml) documents the tools used by Zsh,
Neovim and their plugins. Native Windows has a separate [config](windows/mise-config/config.toml).
The source directories are named `mise-config` so mise does not load them as
project configs when browsing this checkout. `symlink.sh` installs the macOS/Linux
config by linking `mise-config/` to `~/.config/mise` (or `$XDG_CONFIG_HOME/mise`).
The accompanying [lockfile](mise-config/mise.lock) records exact versions and
available download URLs/checksums for Linux x64 and macOS arm64. Keep it with
the config so installs can reuse those resolutions instead of querying `latest`.

Use `mise activate zsh` / `mise activate pwsh` in interactive shells, never mise
shim directories or `mise activate --shims`. Non-interactive scripts and Docker
build steps use `mise env` to activate direct tool paths once per shell. Keep
Cargo, Pixi and other user tool paths; mise's selected tools take precedence.
The global configs set `[settings] not_found_auto_install = false` because mise otherwise
adds auto-install shims even with normal activation. Install missing tools explicitly
with `mise install --locked`. Interactive Zsh uses activation alone; an extra `mise env`
at startup can resolve missing `latest` versions through GitHub and hit API limits.

```bash
oh-my-zsh/zsh-local-install.sh
oh-my-zsh/install-installers.sh

# Make the installed tools available in this bash session.
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise -C "$HOME" env -s bash)"

oh-my-zsh/launch-zsh-in-bash.sh
git submodule update --init --remote  # Install and update all zsh plugins
```

The bootstrap uses the [official mise shell installer](https://mise.jdx.dev/installing-mise.html),
then runs `mise install --locked` and `mise run install-extras` from your home directory.
Most CLI tools come from mise. The extras task uses Homebrew on macOS and Pixi
on Linux for utilities whose libraries need a package manager (including PDF previews).
On macOS it also installs eza with Homebrew, because eza publishes no macOS binaries;
on Linux mise installs eza from its GitHub release.
Conda and Oh My Zsh are also bootstrapped by `install-installers.sh`.
Rust/Cargo are bootstrapped separately through rustup, with cargo-binstall next to it
(Homebrew on macOS, the official installer on Linux) for ad-hoc `cargo binstall` use.
Existing rustup defaults are preserved; mise does not select or manage Rust toolchains,
and no mise-managed tool needs Cargo.

Open your terminal again and you'll see you're running zsh.

See [oh-my-zsh/README.md](oh-my-zsh/README.md) for details.

3. Install Neovim dependencies and Tmux plugins

Neovim v0.12.4 and the locked Tmux version are already installed by mise in step 2.
Neovim is pinned in `mise-config/config.toml`; Tmux advances when the lockfile is updated.
The dependency script below uses uv to create or reuse `~/.virtualenvs/neovim`
and install pynvim, debugpy and Molten's dependencies.
This venv is managed by the script, not mise; system Python is left untouched.
The script also installs Mason's `virtualenv` CLI directly with `uv tool install`.
Treemux and Neovim/Zsh's Tmux hooks use `/usr/bin/python3`; the Tmux scripts install
their pynvim/libtmux dependencies separately.

Install neovim dependencies:

```bash
bash nvim/install-dependencies.sh
```

Install tmux plugins:

```bash
bash tmux/install-plugins.sh
```

4. Install others

```bash
# You might want to symlink dotfiles again in case some scripts overrode them
./symlink.sh
# You only need to install it to the local computer, not in SSH host computer.
./install-nerdfont.sh
# If you're using wezterm (recommended), install terminfo
wezterm/terminfo.sh
```

5. Install / Update dotfiles, apps, plugins etc.

```zsh
# WARNING: This includes calling ./symlink.sh so the dotfile symlinks will be updated.
dotupdate			# Use if you want to update to the latest commit
dotstable			# Use if you want to use the stable tag
dotupdate <tag>		# Specify the tag/commit you want to use
```

Normal bootstrap and `dotupdate` install the checked-in tool versions. To choose
new versions, refresh the lockfile explicitly, then install them:

```zsh
MISE_GITHUB_TOKEN="$(gh auth token --hostname github.com)" mise -C "$HOME" lock --global --bump
mise -C "$HOME" install --locked
mise -C "$HOME" run install-extras
```

Commit the updated `mise-config/mise.lock`. `mise lock --bump` keeps the pinned
Neovim version; edit the config to change it. The GitHub token uses an existing
`gh auth login` session for authenticated release lookups. Downloads and some
verification steps still need network access; the npm-based prettier and the
Homebrew/Pixi extras are not locked by mise.
Update Rust separately with `rustup update`; rerun `nvim/install-dependencies.sh`
to update the Neovim venv and uv-managed `virtualenv` CLI.

## SSH with WezTerm
If you ssh into a remote server, it won't understand the terminal and the UI will break (like backspace seems to work like space).  
You need to install `wezterm.terminfo` on the server.

```bash
bash wezterm/terminfo.sh <ssh_server_name>  # run this before ssh into a new server. Only need it once.
ssh <ssh_server_name>
```

## Docker

You can use the provided Dockerfile that has everything installed.

```bash
docker pull ghcr.io/kiyoon/dotfiles
docker run -it --rm \
    -u $UID:$UID \
    -e TERM=$TERM \
    -e TERM_PROGRAM=$TERM_PROGRAM \
    -e TERM_PROGRAM_VERSION=$TERM_PROGRAM_VERSION \
    ghcr.io/kiyoon/dotfiles
```
