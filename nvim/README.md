# Neovim IDE config

## Neovim Basics (Getting Started)

- Neovim config is written in Lua (vimscript is still supported but lua is more intuitive).
- [lazy.nvim](https://github.com/folke/lazy.nvim): Plugin manager that allows lazy loading on demand.
    - Settings for ALL plugins can be found in [`lua/kiyoon/lazy.lua`](lua/kiyoon/lazy.lua).
    - Read each plugin's documentation! (With wezterm config in this repo, the plugin names will be hyperlinks.) Some of them are explained below.
- [init.lua](init.lua) is the main entry point for the config.
    - It sources the `.vimrc` file. Some configs are easier to write in vimscript and they will be compatible with both vim and neovim.
    - It also sets up the `lazy` plugin manager.
- Treesitter: Syntax tree parser. It is used for syntax highlighting, indentation, and text objects.
    - [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): Automatically install parsers for many languages and support basic features like syntax highlighting and indentation.
    - [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects): Language-aware text objects (e.g. `vam` to select a function, `vaa` to select an argument, etc. See below.)
- LSP: Language Server Protocol. It is used for autocompletion and type checking.
    - [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig): Configuration for LSP servers.
    - [pyright](https://github.com/microsoft/pyright): LSP server for Python (type checker)
    - [lua-ls (lua-language-server)](https://github.com/LuaLS/lua-language-server): LSP server for Lua
    - See [lua/kiyoon/lsp/init.lua](lua/kiyoon/lsp/init.lua).



## This config adds these functionalities:

I use both `\` **and** `<space>` as leader key, but having different functionalities.  
Press and you'll see the available commands with [which-key.nvim](https://github.com/folke/which-key.nvim)

### Custom commands

- `gp`: Select last pasted text

#### For Python
- Insert import statement at the beginning of the file. (Only for Python). Use it with normal or visual mode.
    - `\i`: Insert import and move cursor to that position.
    - `Alt+Enter`: Insert import and stay at the current position.
    - See [`lua/kiyoon/python_import.lua`](lua/kiyoon/python_import.lua).
- When you see a lightbulb in python file, it means ruff fixes are available. `<space>pa` to preview and apply ruff fixes.
- `<space>tp` : Change `os.path` to `pathlib.Path` (e.g. `os.path.join(a, b) -> Path(a) / b`)
    - `<space>tP` to bypass wrapping the object with `Path()`. (e.g. `os.path.join(a, b) -> a / b`)
    - `<space>t` and wait for which-key to see more useful commands for Python.

### Plugins

- [Comment.nvim](https://github.com/numToStr/Comment.nvim): `gcc` to toggle comment on a line, `gc` to toggle comment on a visual selection.
- [nvim-surround](https://github.com/kylechui/nvim-surround)
    - In visual mode, `S"` to surround with double quotes.
    - In normal mode, `cs"'` to change surrounding from double quotes to single quotes.
    - Similar to [vim-surround](https://github.com/tpope/vim-surround) but with highlighting and `dsf` to delete function call.
- [vim-wordmotion](https://github.com/chaoren/vim-wordmotion): `<space>w`, `<space>b`, `<space>e` to move cursor by "real" word, `di<space>w` to delete inside word, etc.
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects): `vim` to select function, `vil` to select class, `(a`, `)a` to swap parameters, `]m`, `]l` etc. to move between functions/classes, `\df`, `\dF` to show popup definitions.
    - See [lua/kiyoon/treesitter.lua](lua/kiyoon/treesitter.lua) for configured keybindings.
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip)
    - Define snippets (i.e. keywords) and expand them with `Alt+j`.
    - See [luasnippets/](luasnippets/).
- [kiyoon/tmuxsend.vim](https://github.com/kiyoon/tmuxsend.vim): Send text to tmux pane from nvim.
- Alt + \[ or \] to see next suggestions for Github Copilot.
- `\nt`: open Nvim Tree. `g?` to open help.

## Useful VIM commands

- `va(`, `va{`, `va"`, ...: select opening to closing of parentheses (do more `a(` for wider range)
- `vi(`: same as above but exclude parentheses.
- `viw` : select a word
- `qq<command>q`: record macro at @q, then quit.
- `10@q`: run macro @q 10 times.
- Choose block with `<C-v>` and press `<S-i>`. It will add the change to all the lines selected.
- `/pattern` to find and `cgn`: change next found pattern. `.` to repeat.
- `:g/pattern/command`: apply command at found patterns (`:v` to inverse)
    - <https://vim.fandom.com/wiki/Power_of_g>

## Installing

This config will install lazy.nvim and many plugins automatically when you first launch vim.

Some plugins have dependencies and you can locally install everything by running:

```bash
./install-dependencies.sh
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

