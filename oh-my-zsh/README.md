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

Install package managers.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/install-installers.sh)"
```

Add settings to `~/.bashrc` that launches zsh when in bash login shell (if you don't have root permission and can't do `chsh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/launch-zsh-in-bash.sh)"
```

Install oh-my-zsh:

```zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Install / update plugins:

```zsh
git submodule update --init --remote
```

Install apps:

```zsh
##### tig, exa, gh, starship, ..
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/apps-local-install.sh)"
```

(Optional) Apps when you have root permission:

```zsh
sudo apt update -y
sudo apt install -y xclip
```

Copy/symlink `.zshrc` to `$HOME`.
