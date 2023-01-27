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
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/oh-my-zsh-custom/master/zsh-local-install.sh)"
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

Clone this repo (recurse submodules):

```zsh
mkdir ~/bin
git clone --recurse-submodules https://github.com/kiyoon/oh-my-zsh-custom ~/bin/oh-my-zsh-custom
mv ~/.zshrc ~/.zshrc.bak
ln -s ~/bin/oh-my-zsh-custom/.zshrc ~/.zshrc
```

Install apps:

```zsh
##### tig, exa, gh
bash ~/bin/oh-my-zsh-custom/apps-local-install.sh

##### Starship
mkdir ~/.local/bin -p
mkdir ~/.config -p
sh -c "$(curl -fsSL https://starship.rs/install.sh)" sh -b "$HOME/.local/bin" -y
wget https://gist.githubusercontent.com/kiyoon/53dae21ecd6c35c24c88bcce88b89d27/raw/starship.toml -P ~/.config

##### zoxide
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

##### fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

pip3 install --user pygments		# colorize (ccat)
pip3 install --user thefuck			# fix last command
conda config --set changeps1 False	# suppress conda environment name in favour of Starship
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

## Useful commands

Update all plugins:

```zsh
cd $ZSH_CUSTOM
git submodule update --remote
```

