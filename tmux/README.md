# .tmux.conf

My IDE-like Tmux configuration and tutorial!

**🔑 Key features:**

- Battery, CPU, GPU, RAM status with [tmux-dracula-fork](https://github.com/kiyoon/tmux-dracula)
- File tree viewer with [treemux](https://github.com/kiyoon/treemux)
- Seamless mouse support
- PID and pane ID viewing for all panes, helping to write scripts instantly.
- More intuitive keybindings

Tmux's default keybindings are quite unintuitive, so I've changed a few.

- Prefix changed: `Ctrl+b` -> `Ctrl+a`: easier to type frequently and does not collide with vim scrolling.
- Split vertically: `Ctrl+b + %` -> `Ctrl+a + -`
- Split horizontally: `Ctrl+b + "` -> `Ctrl+a + \`
- Open/split window on current directory: `Ctrl+a + C`, `Ctrl+a + _`, `Ctrl+a + |` (in US layout, just press shift to open on current directory)

## 🛠️ Installation

1. Make sure your terminal has nerd font set up
2. Put `.tmux.conf` in your home directory
3. Run `./install-plugins.sh`

## 💻 Useful tmux commands

First of all, launch tmux: `tmux`  
or, `tmux new -s <session_name>`

### Create window and navigate

- Ctrl+a + c: create window
- `echo $TMUX_PANE`: see pane number (%0, %1, ..)
- `echo ${TMUX_PANE##%}`: see pane number (0, 1, ..)
- `exit`: exit window
- Ctrl+a + n: next window
- Ctrl+a + p: previous window
- Ctrl+a + \<number\>: jump to the window number
- Ctrl+a + '\<number\>\<Enter\>: jump to the window number (use when bigger than 9)
- Ctrl+a + ,: change window title
- Ctrl+Shift+s+Left / Right: re-order windows

### Detach and resume

- Ctrl+a + d: detach tmux session
- `tmux ls`: list sessions
- `tmux attach` or `tmux a`: attach session
- `tmux attach -t <session_name>`: attach session (specified by the number or name)
- Ctrl+a + s: select and move session

### Divide window (create pane) and navigate

- Ctrl+a + \\: divide screen (vertical)
- Ctrl+a + -: divide screen (horizontal)
- Ctrl+a + |: divide screen (vertical, current dir)
- Ctrl+a + \_: divide screen (horizontal, current dir)
- Ctrl+a + h/j/k/l: move between panes
- Alt + \<ArrowKey\>: move between panes
- Ctrl+a + q + \<number\>: see pane number and move between panes
- Ctrl+a + H/J/K/L: resize panes

You can even use mouse right click.

### Swap panes

- Ctrl+a + {: swap with the prvious pane
- Ctrl+a + }: swap with the next pane
- Ctrl+a + `:swap-pane -U/-D/-L/-R`: swap with another pane
- Ctrl+a + Ctrl+o: rotate pane clockwise
- Ctrl+a + Alt+o: rotate pane anticlockwise

### Change horizontal split to vertical (and vice verca)

- Ctrl+a + `:move-pane -h -t '.{up-of}'`: horizontal split to vertical
- Ctrl+a + `:move-pane -t '.{left-of}'`: vertical split to horizontal

### Copy / scroll

- Ctrl+a + \[: Copy mode (use vim commands to scroll)
  - Ctrl+f: page down (front page)
  - Ctrl+b: page up (back page)
  - Ctrl+d: half page down
  - Ctrl+u: half page up
- In copy mode, `v` to select region. `y` to copy and `q` to exit copy mode. Then Ctrl+a + ] to paste.
- You can use mouse drag to copy.
- Ctrl+a + =: see buffer list

### Kill

- Ctrl+a + x: kill current pane
- Ctrl+a + X: kill session

### Plugins

- Ctrl+a + I: Install plugins
- Ctrl+a + U: Update plugins
- (tmux-yank): Ctrl+a + y: copy bash command line
- (tmux-yank): Ctrl+a + Y: copy PWD
- ([treemux](https://github.com/kiyoon/treemux)): Ctrl+a + \<Tab\>: toggle file browser on the side
- ([treemux](https://github.com/kiyoon/treemux)): Ctrl+a + \<Backspace\>: toggle file browser on the side, and focus on it

### Other tips 💡

- If you press Ctrl+s by mistake, it will freeze. Ctrl+q to unfreeze.
- On a nested tmux, use Ctrl+a + a + \<command\>.
- Ctrl+a `:attach -c /new/dir`: change default directory for new windows.
- Shift + drag: bypass tmux mouse integration and select terminal.

## 📜 Advanced: scripting with tmux

- `tmux new-session -d -s <session_name>`: start a session in detached mode.
- `tmux new-window -t <session_name>:<window_index>`: create a window. You can omit the index. You can add the command at the end, but it will automatically be closed when the command finishes.
- `tmux send-keys -t <session_name>:<window_index>.<pane_index> C-u 'some -new command' Enter`: write in a pane. You can use left/right instead of the pane index.
- `tmux kill-window -t <session_name>:<window_index>`: kill window.
- `tmux kill-session -t <session_name>`: kill all windows and session.
- `tmux display -pt "${TMUX_PANE:?}" '#{pane_index}'`: get current pane index
- `tmux list-panes -s -F '#D #{pane_pid} #{pane_current_command}'`: list pane's unique identifier, pid, and the commands. (`-s` for current session, `-a` for all sessions.)

### Example: run batch job

Below will create 3 windows and run python commands like:

- `CUDA_VISIBLE_DEVICES=0 python train.py --arg 1`
- `CUDA_VISIBLE_DEVICES=1 python train.py --arg 2`
- `CUDA_VISIBLE_DEVICES=2 python train.py --arg 3`

```bash
#!/bin/bash

script_dir=$(dirname "$(realpath -s "$0")")
sess="session_name"

tmux new -d -s "$sess" -c "$script_dir"   # Use default directory as this script directory

for window in {0..2}
do
    # Window 0 or 1 may already exist so it will print error. Ignore that.
    tmux new-window -t "$sess:$window"

    command="CUDA_VISIBLE_DEVICES=$window python train.py --arg $((window+1))"
    tmux send-keys -t "$sess:$window" "$command" Enter
done
```

## References

- https://yesmeck.github.io/tmuxrc/
- https://github.com/yesmeck/tmuxrc/blob/master/tmux.conf
- https://www.hamvocke.com/blog/a-guide-to-customizing-your-tmux-conf/
- https://unix.stackexchange.com/questions/318281/how-to-copy-and-paste-with-a-mouse-with-tmux
