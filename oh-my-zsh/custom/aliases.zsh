if (($+commands[bat])); then
	alias cat='bat'
fi

if (($+commands[exa])); then
	alias ls='exa --icons'
	alias ll='exa -alF --icons'
	alias la='exa -a --icons'
	alias l='exa -F --icons'
	alias lg='exa --git-ignore --icons'
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

alias src='omz reload'
alias ns='nvidia-smi'
alias rb='gio trash'

# git
alias cdgit='cd $(git rev-parse --show-toplevel)'

# slurm
alias sq='squeue -u $USER'
idamnii() {
	srun --time=0-05:00:00 --gres=gpu:$2 --partition=PGR-Standard -w damnii$1 --cpus-per-task=$3 --pty bash
}
