vim.cmd([[
  hi link CocInlayHint Comment
  call coc#add_extension('coc-pyright')
  call coc#add_extension('coc-sumneko-lua')
  call coc#add_extension('coc-actions')
  " CocUninstall coc-sh
  " CocUninstall coc-clangd
  " CocUninstall coc-vimlsp
  " CocUninstall coc-java
  " CocUninstall coc-html
  " CocUninstall coc-css
  " CocUninstall coc-json
  " CocUninstall coc-yaml
  " CocUninstall coc-markdownlint
  " CocUninstall coc-sumneko-lua
  " CocUninstall coc-snippets
  " CocUninstall coc-actions
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
  inoremap <silent><expr> <c-space> coc#refresh()
  " Remap keys for gotos
  nmap <silent> gd <Plug>(coc-definition)
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gi <Plug>(coc-implementation)
  nmap <silent> gr <Plug>(coc-references)
  nmap <silent> gs :call CocAction('jumpDefinition', 'split')<CR>
  nmap <silent> ge :call CocAction('jumpDefinition', 'tabe')<CR>
  " Use Tab
  au filetype python nmap <C-i> <cmd>CocCommand pyright.organizeimports<CR>
  nmap <space>pr <Plug>(coc-rename)

  " coc-snippets
  " Use <C-l> for trigger snippet expand.
  imap <A-l> <Plug>(coc-snippets-expand)

  " Use <C-j> for select text for visual placeholder of snippet.
  vmap <A-j> <Plug>(coc-snippets-select)

  " Use <A-j> for jump to next placeholder, it's default of coc.nvim
  let g:coc_snippet_next = '<A-j>'

  " Use <A-k> for jump to previous placeholder, it's default of coc.nvim
  let g:coc_snippet_prev = '<A-k>'

  " Use <A-j> for both expand and jump (make expand higher priority.)
  imap <A-j> <Plug>(coc-snippets-expand-jump)

  " Use <leader>x for convert visual selected code to snippet
  xmap <leader>x  <Plug>(coc-convert-snippet)
]])
