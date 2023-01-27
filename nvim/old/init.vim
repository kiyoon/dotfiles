" neovim init file.

set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath

" Remove the white status bar below
"set laststatus=0 ruler

" nvim-tree recommends disabling netrw, VIM's built-in file explorer
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

set termguicolors
lua vim.opt.iskeyword:append("-")                   -- treats words with `-` as single words

lua << EOF
vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = { "gitcommit", "markdown" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})
EOF

exec "source " . stdpath('config') . '/plugins.vim'
exec "source " . stdpath('config') . '/.vimrc'
exec "source " . stdpath('config') . '/vscode.vim'

" With GUI demo
nmap <leader>G <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --gui --nvim_socket_path " . v:servername . " &")<CR>
" Without GUI
nmap <leader>g <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --nvim_socket_path " . v:servername . " &")<CR>
" Quit running process
nmap <leader><leader>g <Cmd>let g:quit_nvim_hand_gesture = 1<CR>

colorscheme dracula
" colorscheme onedark
"colorscheme tokyonight-night
"colorscheme kanagawa
"color carbonfox
"color default

set cursorline
set inccommand=split

lua << EOF
	require('lualine').setup()
--	require('lualine').setup {
--	  options = {
--		-- ... your lualine config
--		theme = 'tokyonight'
--		-- ... your lualine config
--	  }
--	}
EOF

