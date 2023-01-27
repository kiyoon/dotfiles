if exists('g:vscode')
	" tpope/vim-commentary behaviour for VSCode-neovim
	xmap gc  <Plug>VSCodeCommentary
	nmap gc  <Plug>VSCodeCommentary
	omap gc  <Plug>VSCodeCommentary
	nmap gcc <Plug>VSCodeCommentaryLine

	" Use uppercase target labels and type as a lower case
	"let g:EasyMotion_use_upper = 1
	 " type `l` and match `l`&`L`
	let g:EasyMotion_smartcase = 1
	" Smartsign (type `3` and match `3`&`#`)
	let g:EasyMotion_use_smartsign_us = 1

	" \f{char} to move to {char}
	" within line
	map f <Plug>(easymotion-bd-fl)
	map t <Plug>(easymotion-bd-tl)
	map <space>w <Plug>(easymotion-bd-wl)
	map <space>e <Plug>(easymotion-bd-el)
	"nmap <Leader>f <Plug>(easymotion-overwin-f)

	" <space>m{char}{char} to move to {char}{char}
	" anywhere, even across windows
	map  <space>f <Plug>(easymotion-bd-f2)
	nmap <space>f <Plug>(easymotion-overwin-f2)
endif
