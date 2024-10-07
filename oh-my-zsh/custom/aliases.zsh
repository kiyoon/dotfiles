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
	alias csvi='nvim -u ~/.config/nvim/csv_init.lua'
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

if [[ -f /opt/homebrew/bin/git ]]; then
	# Use homebrew git if available
	# The default git only supports English
	alias git='/opt/homebrew/bin/git'
fi

# for some reason, it doesn't detect conda/mamba although they are ready and executable here.
# We check the $MINICONDA_PATH instead of
if [[ $(basename "$MINICONDA_PATH") == "miniforge3" ]]; then
# if (($+commands[mamba])); then
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
alias glr='git pull --rebase'

gglr() {
	# from oh-my-zsh glr but with --rebase option
	if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
	then
			git pull --rebase origin "${*}"
	else
			[[ "$#" == 0 ]] && local b="$(git_current_branch)"
			git pull --rebase origin "${b:=$1}"
	fi
}

ssh_add_if_notyet() {
	ssh-add -l | grep -q `ssh-keygen -lf ~/.ssh/id_ed25519 | awk '{print $2}'` || ssh-add ~/.ssh/id_ed25519
}
unalias gc  # defined in oh-my-zsh git plugin
gc () {
	ssh_add_if_notyet
	git commit --verbose --gpg-sign "$@"
}


# slurm
alias sq='squeue -u $USER'
idamnii() {
	srun --time=0-05:00:00 --gres=gpu:$2 --partition=PGR-Standard -w damnii$1 --cpus-per-task=$3 --pty bash
}

if [[ -n "$TMUX" ]]; then
	# get pwd of another pane (left, right, top, bottom)
	alias tpl='tmux display-message -p -F "#{pane_current_path}" -t left'
	alias tpr='tmux display-message -p -F "#{pane_current_path}" -t right'
	alias tpb='tmux display-message -p -F "#{pane_current_path}" -t bottom'
	alias tpt='tmux display-message -p -F "#{pane_current_path}" -t top'

	# send pwd or absolute file path to another pane
	function stp() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stp <left|right|top|bottom> [file_path (optional)]"
			return 1
	 	elif [[ "$#" -eq 1 ]]; then
			tmux send-keys -t $1 "$(pwd)"
		else
			tmux send-keys -t $1 "$(realpath "$2")"
		fi
	}
	alias stpl='stp left'
	alias stpr='stp right'
	alias stpb='stp bottom'
	alias stpt='stp top'

	function stpf() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stpf <left|right|top|bottom> [file_path (optional)]"
			return 1
		fi
		stp "$@"
		tmux select-pane -t $1
	}
	alias stpfl='stpf left'
	alias stpfr='stpf right'
	alias stpfb='stpf bottom'
	alias stpft='stpf top'

	# alias stpl='tmux send-keys -t left "$(pwd)"'
	# alias stpr='tmux send-keys -t right "$(pwd)"'
	# alias stpb='tmux send-keys -t bottom "$(pwd)"'
	# alias stpt='tmux send-keys -t top "$(pwd)"'

	# send pwd to another pane and focus (left, right, top, bottom)
	alias stplf='tmux send-keys -t left "$(pwd)"; tmux select-pane -t left'
	alias stprf='tmux send-keys -t right "$(pwd)"; tmux select-pane -t right'
	alias stpbf='tmux send-keys -t bottom "$(pwd)"; tmux select-pane -t bottom'
	alias stptf='tmux send-keys -t top "$(pwd)"; tmux select-pane -t top'

	# send pwd to another window (1, 2, 3, ...)
	function stw() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stw <window_number> [file_path (optional)]"
			return 1
		elif [[ "$#" -eq 1 ]]; then
			tmux send-keys -t $1. "$(pwd)"
		else
			tmux send-keys -t $1. "$(realpath "$2")"
		fi

	}
	
	# send pwd to another window and focus (1, 2, 3, ...)
	function stwf() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stwf <window_number> [file_path (optional)]"
			return 1
		fi
		stw "$@"
		tmux select-window -t $1.
	}
fi

alias vii='NVIM_APPNAME=nvim-test nvim'
