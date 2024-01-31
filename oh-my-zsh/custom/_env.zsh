if [[ -d "$HOME/bin/miniforge3" ]]; then
	export MINICONDA_PATH="$HOME/bin/miniforge3"
elif [[ -d "$HOME/miniforge3" ]]; then
	export MINICONDA_PATH="$HOME/miniforge3"
elif [[ -d "$HOME/bin/miniconda3" ]]; then
	export MINICONDA_PATH="$HOME/bin/miniconda3"
elif [[ -d "$HOME/miniconda3" ]]; then
	export MINICONDA_PATH="$HOME/anaconda3"
elif [[ -d "$HOME/anaconda3" ]]; then
	export MINICONDA_PATH="$HOME/miniconda3"
elif [[ -d "/usr/local/Caskroom/miniforge/base" ]]; then
	# Mac Homebrew
	export MINICONDA_PATH="/usr/local/Caskroom/miniforge/base"
elif [[ -d "/usr/local/Caskroom/miniconda/base" ]]; then
	# Mac Homebrew
	export MINICONDA_PATH="/usr/local/Caskroom/miniconda/base"
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$MINICONDA_PATH/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
        . "$MINICONDA_PATH/etc/profile.d/conda.sh"
    else
        export PATH="$MINICONDA_PATH/bin:$PATH"
    fi
fi
unset __conda_setup
if [ -f "$MINICONDA_PATH/etc/profile.d/mamba.sh" ]; then
    . "$MINICONDA_PATH/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<
#
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

# git root
git_root=$(git rev-parse --show-toplevel 2> /dev/null)
if [[ -n "$git_root" ]]; then
	basename_git_root=$(basename "$git_root")
	if [[ -d "$MINICONDA_PATH/envs/$basename_git_root" ]]; then
		# Auto activate conda when the current directory is a git repo with the same name as the conda env
		conda activate $basename_git_root
	elif [[ -d "$WORKON_HOME/$basename_git_root" ]]; then
		# Auto activate virtualenv when the current directory is a git repo with the same name as the virtualenv
		workon $basename_git_root
	fi
fi


# Force resetting TERM_PROGRAM to wezterm
# This is required to view images over ssh or maybe tmux
if [[ "$TERM" == "wezterm" ]]; then
	if [[ -z "$TERM_PROGRAM" ]]; then
		export TERM_PROGRAM=WezTerm
		export TERM_PROGRAM_VERSION=20230712-072601-f4abf8fd
	fi
fi


# fzf-tab completion
if (($+commands[eza])); then
	if (($+commands[bat])); then
		# Preview on cd with eza
		# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -w $(( $(tput cols)/2 - 3 )) --color=always --git-ignore $realpath'
		zstyle ':fzf-tab:complete:*' fzf-preview 'if [[ -d $realpath ]]; then \
				eza -w $(( $(tput cols)/2 - 3 )) --color=always --git-ignore $realpath; \
			else bat --color=always --style=numbers --line-range=:1000 $realpath; fi'
	fi
fi

# Ignore some patterns in cd completion
# NOTE: fzf-tab only changes the UI of the completion, not the completion itself.
# So we need to change the zsh completion
zstyle ':completion:*:*:cd:*:*' ignored-patterns '*__pycache__' '*.egg-info'
