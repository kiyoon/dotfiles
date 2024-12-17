if [[ -f /opt/homebrew/bin/git ]]; then
	# Use homebrew git if available
	# The default git only supports English on macOS

	if [[ -z "$LANG" || "$LANG" == "en_US.UTF-8" ]]; then
		# user have not defined language settings or it's English
		# do nothing
	else
		# If it's set to some language other than English, use French
		# git language support is poor on other languages, so I just put it on French which supports 2.47
		alias git='LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 LANGUAGE=fr_FR.UTF-8 /opt/homebrew/bin/git'
	fi
else
	if [[ -z "$LANG" || "$LANG" == "en_US.UTF-8" ]]; then
		# user have not defined language settings or it's English
		# do nothing
	else
		# If it's set to some language other than English, use French
		# git language support is poor on other languages, so I just put it on French which supports 2.47
		alias git='LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 LANGUAGE=fr_FR.UTF-8 git'
	fi
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

# Use difftastic
if (($+commands[difft])); then
	export GIT_EXTERNAL_DIFF=difft
fi
