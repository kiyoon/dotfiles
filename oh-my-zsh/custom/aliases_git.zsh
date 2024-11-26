if [[ -f /opt/homebrew/bin/git ]]; then
	# Use homebrew git if available
	# The default git only supports English
	alias git='/opt/homebrew/bin/git'
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

# Print the URL of the current repository
alias gurl='git config --get remote.origin.url'

# git push current branch force
ggpf () {
    if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
    then
        git push origin "${*}" --force-with-lease
    else
        [[ "$#" == 0 ]] && local b="$(git_current_branch)"
        git push origin "${b:=$1}" --force-with-lease
    fi
}
