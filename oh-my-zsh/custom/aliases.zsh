if (($+commands[bat])); then
	alias cat='bat'
fi

if (($+commands[eza])); then
	alias ls='eza --icons auto --hyperlink'
	alias sl='eza --icons auto --hyperlink'
	alias ll='eza -alF --icons auto --hyperlink'
	alias la='eza -a --icons auto --hyperlink'
	alias l='eza -F --icons auto --hyperlink'
	alias lg='eza --git-ignore --icons auto --hyperlink'
fi

if (($+commands[nvim])); then
	vi() {
		if [[ "$#" -ge 2 ]]; then
			if [[ "$1" == "vi" ]]; then
				# Likely a typo because vi is typed twice.
				# ignore the first argument, and pass the rest to nvim
				# ${@:2} = slice from second to the last
				nvim "${@:2}"
				return
			elif [[ "$1" == "ls" ]]; then
				ls "${@:2}"
				return
			fi
		elif [[ "$#" -eq 1 ]]; then
			if [[ "$1" == "vi" ]]; then
				nvim
				return
			elif [[ "$1" == "ls" ]]; then
				ls
				return
			fi
		fi
		nvim "$@"
	}
	alias v='nvim'
	alias vim='nvim'
	alias vimdiff='nvim -d'
	alias vic='NVIM_APPNAME=nvim-coc nvim'
	alias lazyvim='NVIM_APPNAME=nvim-lazyvim nvim'
	alias svi='sudoedit'
	alias diffview='nvim +DiffviewOpen'
	alias dv='nvim +DiffviewOpen'
fi

if (($+commands[gh])); then
	alias ghr='gh repo'
	alias ghb='gh browse'
	alias ghc='gh repo clone'
	ghck() {
		# ${@:2} = slice from second to the last
		gh repo clone kiyoon/$1 ${@:2}
	}
	ghci() {
		# ${@:2} = slice from second to the last
		gh repo clone Innerverz-AI/$1 ${@:2}
	}
	ghcd() {
		# ${@:2} = slice from second to the last
		gh repo clone deargen/$1 ${@:2}
	}
fi

if (($+commands[ruff])); then
	alias risort='ruff check --select I --fix'
	alias rblack='ruff format'
	alias rformat='ruff format'
fi

# for some reason, it doesn't detect conda/mamba although they are ready and executable here.
# We check the $MINICONDA_PATH instead of
# if [[ $(basename "$MINICONDA_PATH") == "miniforge3" ]]; then
if (($+commands[mamba])); then
	alias ca='mamba activate'
	alias cda='mamba deactivate'
	alias cc='mamba create -n'
	alias ccg='mamba create -n $(git rev-parse --show-toplevel | xargs basename)'
	alias cag='mamba activate $(git rev-parse --show-toplevel | xargs basename)'
	alias ci='mamba install'
else
	alias ca='conda activate'
	alias cda='conda deactivate'
	alias cc='conda create -n'
	alias ccg='conda create -n $(git rev-parse --show-toplevel | xargs basename)'
	alias cag='conda activate $(git rev-parse --show-toplevel | xargs basename)'
	alias ci='conda install'
fi

# virtualenvwrapper
alias a='workon'
alias da='deactivate'
vc() {
	if [[ $# -eq 0 ]]; then
		echo "Usage: vc <virtualenv_name> [python_version]"
		echo "Use python from conda environment to create virtualenv"
		echo "If python_version is not given, use default python"
		echo "Otherwise, use conda environment named python_version"
		echo "If the conda environment does not exist, create it with python version given"
		return
	fi

	if [[ $# -eq 1 ]]; then
		mkvirtualenv $1
	else
		if [[ ! -d "$MINICONDA_PATH/envs/$2" ]]; then
			conda create -n $2 python=$2 -y
		fi
		mkvirtualenv -p "$MINICONDA_PATH/envs/$2/bin/python" "$1"
	fi
}

alias src='omz reload'
alias ns='nvidia-smi'
alias rb='gio trash'

# git
alias cdg='cd $(git rev-parse --show-toplevel)'
alias groot='git rev-parse --show-toplevel'
alias gc='git commit --verbose --gpg-sign'
alias glr='git pull --rebase'
alias gglr='ggl --rebase'

# slurm
alias sq='squeue -u $USER'
idamnii() {
	srun --time=0-05:00:00 --gres=gpu:$2 --partition=PGR-Standard -w damnii$1 --cpus-per-task=$3 --pty bash
}

if [[ -n "$TMUX" ]]; then
	alias tpl='tmux display-message -p -F "#{pane_current_path}" -t left'
	alias tpr='tmux display-message -p -F "#{pane_current_path}" -t right'
	alias tpb='tmux display-message -p -F "#{pane_current_path}" -t bottom'
	alias tpt='tmux display-message -p -F "#{pane_current_path}" -t top'
fi
