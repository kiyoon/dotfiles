if (($+commands[ruff])); then
	alias risort='ruff check --select I --fix'
	# alias rformat='ruff format'  # dangerous because it starts with rf
fi

# for some reason, it doesn't detect conda/mamba although they are ready and executable here.
# We check the $MAMBA_ROOT_PREFIX instead of
if [[ $(basename "$MAMBA_ROOT_PREFIX") == "miniforge3" ]]; then
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

# python virtualenv
alias da='deactivate'

