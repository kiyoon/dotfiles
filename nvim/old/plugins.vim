" Automatic installation of vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" Plugin install at once but activate conditionally
function! Cond(Cond, ...)
  let opts = get(a:000, 0, {})
  return a:Cond ? opts : extend(opts, { 'on': [], 'for': [] })
endfunction

call plug#begin()

Plug 'kiyoon/tmuxsend.vim'
nnoremap <silent> - <Plug>(tmuxsend-smart)	" `1-` sends a line to pane .1
xnoremap <silent> - <Plug>(tmuxsend-smart)	" same, but for visual mode block
nnoremap <silent> _ <Plug>(tmuxsend-plain)	" `1_` sends a line to pane .1 without adding a new line
xnoremap <silent> _ <Plug>(tmuxsend-plain)
nnoremap <silent> <space>- <Plug>(tmuxsend-uid-smart)	" `3<space>-` sends to pane %3
xnoremap <silent> <space>- <Plug>(tmuxsend-uid-smart)
nnoremap <silent> <space>_ <Plug>(tmuxsend-uid-plain)
xnoremap <silent> <space>_ <Plug>(tmuxsend-uid-plain)
nnoremap <silent> <C-_> <Plug>(tmuxsend-tmuxbuffer)		" `<C-_>` yanks to tmux buffer
xnoremap <silent> <C-_> <Plug>(tmuxsend-tmuxbuffer)

Plug 'wookayin/vim-autoimport'
nmap <silent> <M-CR>   :ImportSymbol<CR>
imap <silent> <M-CR>   <Esc>:ImportSymbol<CR>a

Plug 'svermeulen/vim-subversive'
" <space>siwie to substitute word from entire buffer
" <space>siwip to substitute word from paragraph
" <space>siwif to substitute word from function 
" <space>siwic to substitute word from class
" <space>ssip to substitute word from paragraph
nmap <space>s <plug>(SubversiveSubstituteRange)
xmap <space>s <plug>(SubversiveSubstituteRange)
nmap <space>ss <plug>(SubversiveSubstituteWordRange)

" Vim-yoink{{{
" This plugin does not work with tmux.nvim
" Scroll through paste by C-n C-p
" Change the default buffer by [y ]y
" :Yanks to see the yank history
" :ClearYanks to clear the yank history
" Plug 'svermeulen/vim-yoink'
" nmap <c-n> <plug>(YoinkPostPasteSwapBack)
" nmap <c-p> <plug>(YoinkPostPasteSwapForward)
" nmap p <plug>(YoinkPaste_p)
" nmap P <plug>(YoinkPaste_P)
" "nmap gp <plug>(YoinkPaste_gp)
" nmap gP <plug>(YoinkPaste_gP)
" nmap [y <plug>(YoinkRotateBack)
" nmap ]y <plug>(YoinkRotateForward)
" nmap y <plug>(YoinkYankPreserveCursorPosition)
" xmap y <plug>(YoinkYankPreserveCursorPosition)
" nmap <c-=> <plug>(YoinkPostPasteToggleFormat)}}}

Plug 'tpope/vim-surround'
Plug 'kana/vim-textobj-user'
Plug 'kana/vim-textobj-entire'	    " vie, vae to select entire buffer (file)
Plug 'kana/vim-textobj-fold'		" viz, vaz to select fold
Plug 'glts/vim-textobj-comment'		" vic, vac to select comment

Plug 'chaoren/vim-wordmotion'
let g:wordmotion_prefix = ','

" use normal easymotion when in VIM mode
"Plug 'easymotion/vim-easymotion', Cond(!exists('g:vscode'))
" use VSCode easymotion when in VSCode mode
Plug 'asvetliakov/vim-easymotion', Cond(exists('g:vscode'), { 'as': 'vsc-easymotion' })

if !exists('g:vscode')
	Plug 'neoclide/coc.nvim', {'branch': 'release'}
	Plug 'github/copilot.vim'
endif

if has("nvim")
	if !exists('g:vscode')
		Plug 'numToStr/Comment.nvim'
	endif
	
	" Colour schemes
	Plug 'folke/tokyonight.nvim', { 'branch': 'main' }
	Plug 'rebelot/kanagawa.nvim'
	Plug 'EdenEast/nightfox.nvim'
	Plug 'Mofiqul/dracula.nvim'
	Plug 'navarasu/onedark.nvim'

	Plug 'nvim-lualine/lualine.nvim'

	Plug 'nvim-lua/plenary.nvim'
	Plug 'sindrets/diffview.nvim'
	nnoremap <leader>dv :DiffviewOpen<CR>
	nnoremap <leader>dc :DiffviewClose<CR>
	nnoremap <leader>dq :DiffviewClose<CR>:q<CR>

	Plug 'smjonas/inc-rename.nvim'

	Plug 'lewis6991/gitsigns.nvim'

	Plug 'nvim-tree/nvim-web-devicons'
	Plug 'nvim-tree/nvim-tree.lua'

	" Treesitter Better syntax highlighting
	Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
	Plug 'nvim-treesitter/nvim-treesitter-textobjects'
	Plug 'nvim-treesitter/nvim-treesitter-context'
	Plug 'lukas-reineke/indent-blankline.nvim'
	Plug 'kiyoon/treesitter-indent-object.nvim'
	Plug 'RRethy/nvim-treesitter-textsubjects'
	Plug 'andymass/vim-matchup'		" % to match up if, else, etc. Enabled in the treesitter config below
	Plug 'mrjones2014/nvim-ts-rainbow'
	Plug 'Wansmer/treesj'

	" Hop, leap
	Plug 'phaazon/hop.nvim'
	Plug 'mfussenegger/nvim-treehopper'
	Plug 'ggandor/leap.nvim'
	Plug 'mizlan/iswap.nvim'

	" Mason makes it easier to install language servers
	" Always load mason, mason-lspconfig and nvim-lspconfig in order.
	Plug 'williamboman/mason.nvim'
	Plug 'williamboman/mason-lspconfig.nvim'
	Plug 'neovim/nvim-lspconfig'

	Plug 'goolord/alpha-nvim'
	Plug 'lewis6991/impatient.nvim'

	Plug 'nvim-telescope/telescope.nvim', { 'branch': '0.1.x' }
	Plug 'kiyoon/telescope-insert-path.nvim'


	" Wilder.nvim
	function! UpdateRemotePlugins(...)
		" Needed to refresh runtime files
		let &rtp=&rtp
		UpdateRemotePlugins
	endfunction

	Plug 'gelguy/wilder.nvim', { 'do': function('UpdateRemotePlugins') }
	Plug 'romgrk/fzy-lua-native'
	Plug 'nixprime/cpsm'

	" LSP
	Plug 'folke/neodev.nvim'
	Plug 'hrsh7th/nvim-cmp' " The completion plugin
	Plug 'hrsh7th/cmp-buffer' " buffer completions
	Plug 'hrsh7th/cmp-path' " path completions
	" Plug 'saadparwaiz1/cmp_luasnip' " snippet completions
	Plug 'hrsh7th/cmp-nvim-lsp'
	Plug 'hrsh7th/cmp-nvim-lua'
	Plug 'jose-elias-alvarez/null-ls.nvim'
	Plug 'j-hui/fidget.nvim'

	" LSP diagnostics
	Plug 'folke/trouble.nvim'
	" Plug 'doums/dmap.nvim'

	" DAP
	Plug 'mfussenegger/nvim-dap'
	Plug 'mfussenegger/nvim-dap-python'
	Plug 'rcarriga/nvim-dap-ui'
	Plug 'Weissle/persistent-breakpoints.nvim'

	Plug 'aserowy/tmux.nvim'
	Plug 'akinsho/bufferline.nvim'
	Plug 'RRethy/vim-illuminate'
	"Plug 'ahmedkhalf/project.nvim'
	
	" Snippet
	" Plug 'L3MON4D3/LuaSnip', {'tag': 'v1.*'}
	Plug 'rafamadriz/friendly-snippets'

	if isdirectory(expand('~/bin/miniconda3/envs/jupynium'))
		Plug 'kiyoon/jupynium.nvim', { 'do': '~/bin/miniconda3/envs/jupynium/bin/pip install .' }
	endif
	Plug 'rcarriga/nvim-notify'
endif

" All of your Plugins must be added before the following line
call plug#end()            " required
filetype plugin indent on    " required

exec "source " . stdpath('config') . '/coc.vim'

if has("nvim")
	lua require('impatient')
	lua require('Comment').setup()
	lua require('gitsigns').setup()
	lua require('leap').add_default_mappings()

	lua require('user.lsp')
	" lua require "user.lsp.cmp"

	lua require('user.dap')
	lua require("inc_rename").setup()

	" Navigate tmux, and nvim splits.
	" Sync nvim buffer with tmux buffer.
	lua require("tmux").setup({ copy_sync = { enable = true, sync_clipboard = false, sync_registers = true }, resize = { enable_default_keybindings = false } })
	

	lua require('user.alpha')
	lua require('user.wilder')
	lua require('user.nvim_tree')
	lua require('user.treesitter')
	lua require('user.indent_blankline')
	lua require('user.tokyonight')
	lua require('user.illuminate')
	lua require('user.hop')
	lua require('user.bufferline')
	lua require('user.telescope')
	lua require('user.jupynium')

	" lua require'dmap'.setup()

	" lua require('user.luasnip')

	lua vim.notify = require("notify")

	" lua vim.api.nvim_set_keymap('n', 'x', '<Cmd>lua vim.notify({vim.inspect(vim.fn.getpos("v")), vim.inspect(vim.fn.getcurpos())})<cr>', {})
endif

