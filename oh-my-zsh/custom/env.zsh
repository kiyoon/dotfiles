# We don't want linuxbrew python to be used as default python, so we add it to the end of the path.
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH:/home/linuxbrew/.linuxbrew/bin"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH:/home/linuxbrew/.linuxbrew/lib"
export MANPATH="$HOME/.local/share/man:$MANPATH"

if [[ $OSTYPE == "linux-gnu"* ]]; then
	export TERMINFO="$HOME/.local/share/terminfo" # tmux needs this
fi
export BAT_THEME="Dracula"

if (($+commands[nvim])); then
	export SUDO_EDITOR="$commands[nvim]"
fi

# setup fzf Ctrl+t and Alt+c
if (($+commands[fzf])); then
	if (($+commands[fd])); then
		export FZF_DEFAULT_OPTS='-m --bind ctrl-s:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
		export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
	fi
fi

# Inside tmux, home and end keys don't work
# https://stackoverflow.com/questions/18600188/home-end-keys-do-not-work-in-tmux
# Binding keys in tmux.conf works in neovim but doesn't in zsh or maybe zsh-vi-mode
# so we bind them here so it works in zsh as well.
bindkey "^[OF" end-of-line
bindkey "^[OH" beginning-of-line

# https://stackoverflow.com/questions/41287226/ssh-asking-every-single-time-for-passphrase


if ! pgrep -u $UID ssh-agent >/dev/null; then
  ssh-agent -t 3h > ~/.ssh/.agent.pid
fi
source ~/.ssh/.agent.pid >&/dev/null

# https://unix.stackexchange.com/questions/90853/how-can-i-run-ssh-add-automatically-without-a-password-prompt
# if [ -z "$SSH_AUTH_SOCK" ]; then
# 	eval $(ssh-agent -s)
# 	# ssh-add
# fi

# NOTE: virtualenvwrapper settings.
# mkvirtualenv <name>
# mkvirtualenv <name> -p <python3>
# workon <name>
# deactivate
# rmvirtualenv <name>
# lsvirtualenv
# lssitepackages
# It will automatically activate the virtualenv when you cd into a git repo with the same name as the virtualenv
# or when you cd into a directory with a .venv file in it.

export WORKON_HOME=~/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON="/usr/bin/python3"  # Usage of python3
