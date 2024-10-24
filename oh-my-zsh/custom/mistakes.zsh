# NOTE: Bindings to prevent common mistakes

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
fi

if (($+commands[eza])); then
	alias sl='eza --icons auto --hyperlink'
fi
