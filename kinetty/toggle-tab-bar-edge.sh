#!/bin/sh
#: Flip tab_bar_edge between top and left, for the global menubar entry in
#: kinetty.toml and the keybinding in kinetty.toml. kitty runs this through its
#: remote_control_script action, which spawns it as a direct child of the kitty
#: process with a remote control channel already open on KITTY_LISTEN_ON -- so
#: `kitten @` needs no --to here and works under `allow_remote_control
#: socket-only`, which refuses the same command sent from inside a pane.
#: kitty puts its own bundle directory first on PATH, so `kitten` resolves even
#: though a background script inherits none of the shell's PATH.

set -u

#: kitty exports KITTY_PID to its windows but not to background scripts, whose
#: only kitty variable is KITTY_LISTEN_ON=fd:N. The parent process is kitty
#: itself, so PPID is what names the effective config file to read.
kitty_pid=$(ps -o ppid= -p $$ | tr -d ' ')

conf=""
for dir in "$HOME/Library/Caches/kitty" "${XDG_CACHE_HOME:-$HOME/.cache}/kitty"; do
    if [ -r "$dir/effective-config/$kitty_pid" ]; then
        conf="$dir/effective-config/$kitty_pid"
        break
    fi
done

#: load-config appends each -o override to the effective config instead of
#: rewriting the line it overrides, so the value in force is the last match.
edge=top
if [ -n "$conf" ]; then
    edge=$(awk '$1 == "tab_bar_edge" { v = $2 } END { print (v == "" ? "top" : v) }' "$conf")
fi

case "$edge" in
    left|right) new=top ;;
    *)          new=left ;;
esac

exec kitten @ load-config -o "tab_bar_edge=$new"
