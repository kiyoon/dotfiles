# Neovim IDE config

This configuration is compatible with both Vim and Neovim, but Neovim will have full of features.

### Vim features

- Backup every save automatically to ~/.vim/backup
- You can undo whenever (even after closing the file)
- Fold indicator if fold exists in a file.
- Detect file extension, and change behaviour accordingly
  - Python - expand tabs to space
  - Comment string (#, //, ...): used to make folds

### Neovim features

## Vim setup tips (2022)

1. Use Neovim over Vim. Faster, and better plugin support. Largely compatible with most vim scripts and plugins. It also enabled full mouse control inside tmux, whilst the original vim did not work for me at least.
2. Use Vim-Plug over Vundle, pathogen etc. Easier to install plugins (no need extra setup like source compilation)
3. Use Coc over YouCompleteMe, Syntastic etc. Much easier plugin handling with very good default code completion and linting.

## Installing

This config will install vim-plug and many plugins automatically when you first launch vim.

Some plugins have dependencies and you can locally install everything by running:

```bash
./install-linux.sh
```

Optionally,

```bash
sudo apt install xclip		# neovim, tmux clipboard support

# Github Copilot
nvim +PlugInstall +qall
nvim '+Copilot setup' +q
nvim '+Copilot enable' +q
```

## This config adds these functionalities:

### Custom commands

- `<F3>`: Toggle paste mode
- `gp`: Select last pasted text
- `\i`: Insert import statement at the beginning of the file. (Only for Python). Use it with normal or visual mode.

### Plugins

- Select lines and press `<C-i>` to sort the Python import lines.
- :Isort to sort the entire Python imports.
- Alt + [ or ] to see next suggestions for Github Copilot.
- [tpope/vim-commentary](https://github.com/tpope/vim-commentary)
- [tpope/vim-surround](https://github.com/tpope/vim-surround)
- `\nt`: open Nvim Tree. `g?` to open help.
- `\s`, `\w`, `\b`, `\e`, `\f`: easy motion
- `,w`, `,b`, `,e`: word motion
- vil/val to select line, vie/vae to select file, vii/vai to select indent.
- treesitter-textobjects: `vif` to select function, `vic` to select class, `\a`, `\A` to swap parameters, `]m`, `]]` etc. to move between functions/classes, `\df`, `\dF` to show popup definitions.
- [kiyoon/tmuxsend.vim](https://github.com/kiyoon/tmuxsend.vim).

## Useful VIM commands

- `va(`, `va{`, `va"`, ...: select opening to closing of parentheses (do more `a(` for wider range)
- `vi(`: same as above but exclude parentheses.
- `viw` : select a word
- `qq<command>q`: record macro at @q, then quit.
- `10@q`: run macro @q 10 times.
- Choose block with `<C-v>` and press `<S-i>`. It will add the change to all the lines selected.
