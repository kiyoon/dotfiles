# My ZSH Custom for local/SSH users

I develop often on remote servers that I don't have `sudo` permission. This awesome zsh settings allow you to install **locally, without root permission**.

## ZSH Basics (Getting Started)

- [Oh My Zsh](https://ohmyz.sh/): Manage zsh configuration. Includes many small plugins.
    - [git](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git): aliases for many git commands.
    - [dirhistory](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/dirhistory): Alt+Left/Right to navigate directory history. Alt+Up to go to the parent directory.
    - It will source all files in `custom/` directory.

- [Starship](https://starship.rs/): Prompt (theme) that shows project statuses (git, conda, python version, etc.)
- Some commands are aliased (e.g., `ls` -> `eza`, `cat` -> `bat`, `vi` -> `nvim`).
    - When you want to use the original command, add `\` prefix (e.g. `\ls`, `\cat`).

## Setup

Install zsh locally. (🚨 warning: `sudo apt install zsh` may install an old version. Use the script below.)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/zsh-local-install.sh)"
```

From the cloned dotfiles directory, link the global mise config and bootstrap
standalone uv, Bun and rustup, mise, CLI tools, Oh My Zsh and conda:

```bash
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise trust
mise run setup-dotfiles
oh-my-zsh/install-installers.sh
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise -C "$HOME" env -s bash)"
```

Add settings to `~/.bashrc` that launches zsh when in bash login shell (if you don't have root permission and can't do `chsh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/launch-zsh-in-bash.sh)"
```

Install / update plugins:

```zsh
git submodule update --init --remote
```

Install the checked-in CLI versions from [mise.lock](../mise-config/mise.lock):

```zsh
mise -C "$HOME" install --locked
mise -C "$HOME" run install-extras
```

To update versions, run `mise -C "$HOME" lock --global --bump` first and commit
the resulting lockfile. See the root README for GitHub authentication when updating.

The linked `.zshrc` activates mise before loading Oh My Zsh plugins and custom files.
It also deduplicates PATH (`typeset -U path`) and no longer forces `/usr/bin` ahead of Homebrew.
uv and Bun stay outside mise: Homebrew installs them on macOS, and their official
installers place them in `~/.local/bin` and `~/.bun/bin` on Linux.

Rust/Cargo stay under rustup, using the existing Cargo home and default toolchain.
The bootstrap installs/updates stable without replacing an existing default, and
installs cargo-binstall next to it (outside mise) for ad-hoc `cargo binstall` use.
Use `rustup update` to update Rust separately from mise-managed CLI tools.
