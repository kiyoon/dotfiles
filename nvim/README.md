# Neovim IDE config

## Installing

This config will install lazy.nvim and many plugins automatically when you first launch vim.

Some plugins have dependencies and you can locally install everything by running:

```bash
./install-linux.sh
```

Optionally,

```bash
sudo apt install xclip		# neovim, tmux clipboard support
sudo apt install lua-check	# linter for lua

# Github Copilot
nvim +"lua require('lazy').install({wait=true})" +qa
nvim '+Copilot setup' +q
nvim '+Copilot enable' +q
```

It is recommended to use the `stable` tag of this repo.

```bash
git checkout stable
```

It is recommended to use plugin versions that match the `lazy-lock.json` file.

```bash
nvim +"lua require('lazy').restore({wait=true})" +qa
```

After installing dependencies, check health inside nvim:

```vim
:checkhealth kiyoon
```

## This config adds these functionalities:

### Custom commands

- `gp`: Select last pasted text
- `\i`: Insert import statement at the beginning of the file. (Only for Python). Use it with normal or visual mode.

### Plugins

- Alt + [ or ] to see next suggestions for Github Copilot.
- [tpope/vim-commentary](https://github.com/tpope/vim-commentary)
- [tpope/vim-surround](https://github.com/tpope/vim-surround)
- `\nt`: open Nvim Tree. `g?` to open help.
- `<space>w`, `<space>b`, `<space>e`: word motion
- treesitter-textobjects: `vim` to select function, `vil` to select class, `(a`, `)a` to swap parameters, `]m`, `]l` etc. to move between functions/classes, `\df`, `\dF` to show popup definitions.
- [kiyoon/tmuxsend.vim](https://github.com/kiyoon/tmuxsend.vim).

## Useful VIM commands

- `va(`, `va{`, `va"`, ...: select opening to closing of parentheses (do more `a(` for wider range)
- `vi(`: same as above but exclude parentheses.
- `viw` : select a word
- `qq<command>q`: record macro at @q, then quit.
- `10@q`: run macro @q 10 times.
- Choose block with `<C-v>` and press `<S-i>`. It will add the change to all the lines selected.
- Alt + key in insert / visual mode to perform normal mode action (just like ESC + key)
