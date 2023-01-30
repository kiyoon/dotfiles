# My ZSH Custom for local/SSH users

I develop often on remote servers that I don't have `sudo` permission. This awesome zsh settings allow you to install **locally, without root permission**.

## Setup

Install zsh (with root):

```bash
sudo apt install zsh
chsh -s $(which zsh)
```

Install zsh locally (if you can't `sudo apt install zsh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/zsh-local-install.sh)"
```

Add the lines below to your `~/.bashrc` (if you don't have root permission and can't do `chsh`):

```bash
export PATH="$HOME/.local/bin:$PATH"
if [[ ($- == *i*) ]];
then
 export SHELL=$(which zsh)
 exec zsh -l
fi
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
bash apps-local-install.sh
```

(Optional) Additional settings:

```zsh
##### Conda
conda config --set auto_activate_base false
##### git
git config --global user.email "yoonkr33@gmail.com"
git config --global user.name "Kiyoon Kim"
git config --global core.editor nvim
git config --global pull.rebase false
git config --global url.ssh://git@github.com/.insteadOf https://github.com/

gh auth login
gh alias set r repo
```

(Optional) Apps when you have root permission:

```zsh
sudo apt update -y
sudo apt install -y xclip
```

Copy `.zshrc` to `$HOME`.
