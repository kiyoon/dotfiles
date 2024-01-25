if (($+commands[bat])); then
	alias cat='bat'
fi

if (($+commands[eza])); then
	alias ls='eza --icons auto'
	alias ll='eza -alF --icons auto'
	alias la='eza -a --icons auto'
	alias l='eza -F --icons auto'
	alias lg='eza --git-ignore --icons auto'
fi

if (($+commands[nvim])); then
	alias v='nvim'
	alias vi='nvim'
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

alias ca='conda activate'
alias cda='conda deactivate'
alias cc='conda create -n'

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

# slurm
alias sq='squeue -u $USER'
idamnii() {
	srun --time=0-05:00:00 --gres=gpu:$2 --partition=PGR-Standard -w damnii$1 --cpus-per-task=$3 --pty bash
}
