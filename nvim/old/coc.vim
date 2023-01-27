if !exists('g:vscode')
	call coc#add_extension('coc-pyright')
	call coc#add_extension('coc-sh')
	call coc#add_extension('coc-clangd')
	call coc#add_extension('coc-vimlsp')
	call coc#add_extension('coc-java')
	call coc#add_extension('coc-html')
	call coc#add_extension('coc-css')
	call coc#add_extension('coc-json')
	call coc#add_extension('coc-yaml')
	call coc#add_extension('coc-markdownlint')
	call coc#add_extension('coc-sumneko-lua')
	call coc#add_extension('coc-snippets')
endif

" (Default binding) Use <C-e> and <C-y> to cancel and confirm completion
" I personally use <C-n> <C-p> to confirm completion without closing the popup.
"
"let g:coc_node_args = ['--max-old-space-size=8192']	" prevent javascript heap out of memory
" Toggle CoC diagnostics
"nnoremap <silent> <F6> :call CocActionAsync('diagnosticToggle')<CR>
" Show CoC diagnostics window
nnoremap <silent> <F6> :CocDiagnostics<CR>
" navigate diagnostics
nmap <silent> <M-l> <Plug>(coc-diagnostic-next)
nmap <silent> <M-h> <Plug>(coc-diagnostic-prev)
" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif
" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gs :call CocAction('jumpDefinition', 'split')<CR>
nmap <silent> ge :call CocAction('jumpDefinition', 'tabe')<CR>
" Use Tab
au filetype python nmap <C-i> <cmd>CocCommand pyright.organizeimports<CR>
nmap <leader>rn <Plug>(coc-rename)


" coc-snippets
" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)

" Use <C-j> for select text for visual placeholder of snippet.
vmap <C-j> <Plug>(coc-snippets-select)

" Use <C-j> for jump to next placeholder, it's default of coc.nvim
let g:coc_snippet_next = '<c-j>'

" Use <C-k> for jump to previous placeholder, it's default of coc.nvim
let g:coc_snippet_prev = '<c-k>'

" Use <C-j> for both expand and jump (make expand higher priority.)
imap <C-j> <Plug>(coc-snippets-expand-jump)

" Use <leader>x for convert visual selected code to snippet
xmap <leader>x  <Plug>(coc-convert-snippet)
