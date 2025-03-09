# Patch coreutils to use GNU coreutils on Mac.
# For example, `rm some_dir -rf` will not work on Mac by default.

if [[ $OSTYPE == "darwin"* ]]; then
	if (($+commands[coreutils])); then
		alias cp='coreutils cp'
		alias rm='coreutils rm'
		alias mv='coreutils mv'
		alias mkdir='coreutils mkdir'
	fi
fi
