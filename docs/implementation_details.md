# Implementation details (Not important)

## Some keybindings exist just for Keychron knob

To support Keychron knob, I mapped the knob using VIA as following:

- Counter Clockwise: `F3` (`F2` on Mac)
- Clockwise: `F6`
- Press: `F7`
- Fn + Counter Clockwise: `F8`
- Fn + Clockwise: `F10`
- Fn + Press: `F9`

You'll see the keymaps in tmux, wezterm, zsh and neovim.

For example,

```sh
# 01_env.sh
bindkey "^[OR" dirhistory_zle_dirhistory_back  # F3, knob counter-clockwise
bindkey "^[[15~" dirhistory_zle_dirhistory_back  # F2, knob counter-clockwise (mac)
bindkey "^[[17~" dirhistory_zle_dirhistory_future  # F6, knob clockwise
bindkey "^[[18~" dirhistory_zle_dirhistory_up  # F7, knob click 
```

In NeoVim, `<F13>` means `Shift + F1`, `<F25>` means `Ctrl + F1`.

Sometimes it is hard to pass the exact key sequence to the terminal. For example, skhd intercepts `F6` and it can't
pass the same key to the terminal. Thus, I used `F5` in some cases.
