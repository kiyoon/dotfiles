
" settings profile based on OS name
"let os = 'fc'
" let os = 'ubuntu'
"
" if os ==? 'fc'
"   let use_vimplug         = 0
" elseif os ==? 'ubuntu'
"   let use_vimplug         = 1
" endif

" directory path where the vimrc is installed
" let vimrc_installed_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
"
" if use_vimplug
"   exec "source " . vimrc_installed_dir . "/plugins.vim"
" endif


" If you prefer the Omni-Completion tip window to close when a selection is
" made, these lines close it on movement in insert mode or when leaving
" insert mode
"autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
"autocmd InsertLeave * if pumvisible() == 0|pclose|endif
"

syntax on

if !has('nvim')
  " colorscheme zaibatsu
  colorscheme sorbet
endif

" Open new split panes to right and bottom, which feels more natural than Vim’s default:
set splitbelow
set splitright

" show relative line numbers only when in normal mode
set number

augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END

" highlight search
set hlsearch

" search as characters are entered
set incsearch

" view matching brace
set sm

" scroll offset
set scrolloff=2

" number of undo history
set history=100

" case insensitive search
"
set ignorecase
set smartcase
"/copyright      : Case insensitive
"/Copyright      : Case sensitive
"/copyright\C    : Case sensitive
"/Copyright\c    : Case insensitive

if !has('nvim')
  set timeoutlen=10000  " leader key timeout = 10s
endif

" map common typos: :W, :Q, :Wq, :WQ, q:
" if you need q:, use :<C-f> to open command history
command! -bang -range=% -complete=file -nargs=* W <line1>,<line2>write<bang> <args>
command! -bang -range=% -complete=file -nargs=* Wq <line1>,<line2>write<bang> <args> | quit
command! -bang -range=% -complete=file -nargs=* WQ <line1>,<line2>write<bang> <args> | quit
command! -bang Q quit<bang>
nmap q: :q

" map F1 to Esc because of typos
" noremap <F1> :call MapF1()<CR>
" function! MapF1()
"   if &buftype == "help"
"     exec 'quit'
"   else
"     exec 'help'
"   endif
" endfunction
noremap <F1> <Esc>
inoremap <F1> <Esc>

" :w\ normally saves to the file named \ but this remap prevents it.
"cnoremap w\ w<CR>

"""""""""""""""""
" <leader>l to toggle location list
" https://vim.fandom.com/wiki/Toggle_to_open_or_close_the_quickfix_window
function! GetBufferList()
  redir =>buflist
  silent! ls!
  redir END
  return buflist
endfunction

function! ToggleList(bufname, pfx)
  let buflist = GetBufferList()
  for bufnum in map(filter(split(buflist, '\n'), 'v:val =~ "'.a:bufname.'"'), 'str2nr(matchstr(v:val, "\\d\\+"))')
    if bufwinnr(bufnum) != -1
      exec(a:pfx.'close')
      return
    endif
  endfor
  if a:pfx == 'l' && len(getloclist(0)) == 0
      echohl ErrorMsg
      echo "Location List is Empty."
      return
  endif
  let winnr = winnr()
  exec(a:pfx.'open')
  if winnr() != winnr
    wincmd p
  endif
endfunction

nmap <silent> <leader>l :call ToggleList("Location List", 'l')<CR>
" nmap <silent> <leader>e :call ToggleList("Quickfix List", 'c')<CR>
" nnoremap <C-j> :lnext<CR>
" nnoremap <C-k> :lprevious<CR>


" highlight cursor line
"set cursorline

" set each buffer store up to 1000 lines(<1000), maximum buffer size
" 1000kb(s1000)
set viminfo='20,<1000,s1000

" Maintain undo history between sessions (persistent undo)
set undofile 
" backup
set backup
" backup ext to date
:au BufWritePre * let &bex = '-' . strftime("%Y%m%d_%H%M%S") . '~'
" set auto backupdir to ~/.vim/backup
function! InitBackupDir()
  if has('nvim')
    let l:parent = stdpath('data') . '/'
  else
    if has('win32') || has('win32unix') "windows/cygwin
      let l:separator = '_'
    else
      let l:separator = '.'
    endif
    let l:parent = $HOME . '/' . l:separator . 'vim/'
  endif

  let l:backup = l:parent . 'backup/'
  let l:undo = l:parent . 'undo/'
  let l:tmp = l:parent . 'tmp/'
  if exists('*mkdir')
    if !isdirectory(l:parent)
      call mkdir(l:parent)
    endif
    if !isdirectory(l:backup)
      call mkdir(l:backup)
    endif
    if !isdirectory(l:undo)
      call mkdir(l:undo)
    endif
    if !isdirectory(l:tmp)
      call mkdir(l:tmp)
    endif
  endif
  let l:missing_dir = 0
  if isdirectory(l:backup)
    execute 'set backupdir=' . escape(l:backup, ' ') . '/,.'
  else
    let l:missing_dir = 1
  endif
  if isdirectory(l:undo)
    execute 'set undodir=' . escape(l:undo, ' ') . '/,.'
  else
    let l:missing_dir = 1
  endif
  if isdirectory(l:tmp)
    execute 'set directory=' . escape(l:tmp, ' ') . '/,.'
  else
    let l:missing_dir = 1
  endif
  if l:missing_dir
    echo 'Warning: Unable to create backup directories:' l:backup 'and' l:undo 'and' l:tmp
    echo 'Try: mkdir -p' l:backup
    echo 'and: mkdir -p' l:undo
    echo 'and: mkdir -p' l:tmp
    set backupdir=.
    set directory=.
    set undodir=.
  endif
endfunction
call InitBackupDir()

" make backspace working properly
set backspace=indent,eol,start

" set tab length to 4 spaces
set tabstop=4
set shiftwidth=4

" automatic indent on bash
filetype plugin indent on

" use tab as spaces in python, tex
autocmd FileType sh,python,tex,lua,toml,yaml,json,javascript,typescript set expandtab

" latex settings (global values require vim-latex plugin)
autocmd FileType tex,lua,toml,yaml,json,javascript,typescript set tabstop=2
autocmd FileType tex,lua,toml,yaml,json,javascript,typescript set shiftwidth=2
autocmd FileType tex set iskeyword+=:
" let g:tex_flavor='latex'
" let g:Tex_DefaultTargetFormat = 'pdf'
" let g:Tex_MultipleCompileFormats='pdf, aux'

" turn off automatic new line when the text is too long in a line (e.g. SML)
autocmd FileType sml set textwidth=0 wrapmargin=0
autocmd FileType vim set textwidth=0 wrapmargin=0

set wildmenu


" zf folding comment set
" set commentstring=%s
" autocmd FileType c,cpp,java,html,php setl commentstring=//%s 
" autocmd FileType sh,python setl commentstring=#%s 
" autocmd FileType matlab setl commentstring=%%s
" autocmd FileType sml setl commentstring=(*%s*)
"autocmd FileType html,php setl commentstring=<!--%s-->

" set foldcolumn automatically if there is at least one fold
" WARNING: this function causes cursor to flicker when using with folke/which-key.nvim
" in neovim just set
" vim.o.foldcolumn = 'auto:3'

if !has('nvim')
  set foldmethod=marker
  function HasFolds()
    "Attempt to move between folds, checking line numbers to see if it worked.
    "If it did, there are folds.

    function! HasFoldsInner()
      let origline=line('.')  
      :norm zk
      if origline==line('.')
        :norm zj
        if origline==line('.')
          return 0
        else
          return 1
        endif
      else
        return 1
      endif
      return 0
    endfunction

    " suppress all sounds when this function calls
  "  set belloff=all
    set noeb vb t_vb=
    let l:winview=winsaveview() "save window and cursor position
    let foldsexist=HasFoldsInner()
    if foldsexist
      set foldcolumn=3
    else
      "Move to the end of the current fold and check again in case the
      "cursor was on the sole fold in the file when we checked
      if line('.')!=1
        :norm [z
        :norm k
      else
        :norm ]z
        :norm j
      endif
      let foldsexist=HasFoldsInner()
      if foldsexist
        set foldcolumn=3
      else
        set foldcolumn=0
      endif
    end
    call winrestview(l:winview) "restore window/cursor position

    " enable bell sounds again
  "  set belloff=
    set novb eb
  endfunction

  " This HasFolds function doesn't work well with the fern plugin.
  let fold_blacklist = ['fern']
  autocmd CursorHold,BufWinEnter ?* if index(fold_blacklist, &ft) < 0 | call HasFolds() | endif

  " match behaviour of Y with C and D
  nnoremap Y y$
  vnoremap Y $y

  " paste mode by <F3>, and leave automatically
  set pastetoggle=<F3>
  autocmd InsertLeave * set nopaste
endif

" restore the cursor position
function! ResCur()
  if line("'\"") <= line("$")
    normal! g`"
    return 1
  endif
endfunction

augroup resCur
  autocmd!
  autocmd BufWinEnter * call ResCur()
augroup END

" Select last pasted
" https://vim.fandom.com/wiki/Selecting_your_pasted_text
nnoremap <expr> gp '`[' . strpart(getregtype(), 0, 1) . '`]'

" Add python import at the beginning of the file.
" Copy the word, find the first import statement and attach import before the first one.
" If the first line first word of the file is import, it will search the second import statement.
" It will also try to restore the previous search string (@/).
function! AddPythonImport(module)
  normal! gg
  let import_searched = search('import')
  if import_searched
    normal! O
  else
    normal! gg
    " comment check: https://stackoverflow.com/questions/73356266/how-can-i-check-if-the-current-line-is-commented-in-vim-script
    let commented = ! match(getline('.'), ' *#.*')
    if commented
      normal! o
    else
      normal! O
    endif
  endif
  call setline('.', 'import ' . a:module)
  "call feedkeys('iimport ' . a:module)
  "call feedkeys("\<ESC>")
endfunction

autocmd FileType python nnoremap <leader>i "syiw:call AddPythonImport(@s)<CR>
autocmd FileType python vnoremap <leader>i "sy:call AddPythonImport(@s)<CR>

" Below <expr> example will behave differently when there is no 'import' in the file.
" This is not a practical common but it's for example sake.
"nnoremap <expr> + search('import') > 0 ? 'Oimport os' : 'ggOimport os'

" nvim 0.10 automatically uses osc52
" if has('clipboard')
"   set clipboard^=unnamed,unnamedplus
" endif

" WSL yank support
if has('wsl')
  let s:clip = '/mnt/c/Windows/System32/clip.exe'  " change this path according to your mount point
  if executable(s:clip)
    augroup WSLYank
      autocmd!
      autocmd TextYankPost * if v:event.operator ==# 'y' | call system(s:clip, @0) | endif
    augroup END
  endif
endif

" visual mode indent change
vnoremap < <gv
vnoremap > >gv

" normal mode new line
" From vim-unimpaired
function! BlankUp(count) abort
  put!=repeat(nr2char(10), a:count)
  ']+1
  silent! call repeat#set("\<Plug>unimpairedBlankUp", a:count)
endfunction

function! BlankDown(count) abort
  put =repeat(nr2char(10), a:count)
  '[-1
  silent! call repeat#set("\<Plug>unimpairedBlankDown", a:count)
endfunction

nnoremap <space>O :call BlankUp(v:count1)<CR>
nnoremap <space>o :call BlankDown(v:count1)<CR>

" https://vim.fandom.com/wiki/Moving_lines_up_or_down
nnoremap <A-Down> :m .+1<CR>==
nnoremap <A-Up> :m .-2<CR>==
inoremap <A-Down> <Esc>:m .+1<CR>==gi
inoremap <A-Up> <Esc>:m .-2<CR>==gi
vnoremap <A-Down> :m '>+1<CR>gv=gv
vnoremap <A-Up> :m '<-2<CR>gv=gv

augroup move_lines
  autocmd!
  autocmd FileType python nnoremap <A-Down> :m .+1<CR>
  autocmd FileType python nnoremap <A-Up> :m .-2<CR>
  autocmd FileType python inoremap <A-Down> <Esc>:m .+1<CR>gi
  autocmd FileType python inoremap <A-Up> <Esc>:m .-2<CR>gi
  autocmd FileType python vnoremap <A-Down> :m '>+1<CR>gv
  autocmd FileType python vnoremap <A-Up> :m '<-2<CR>gv
augroup END


if !exists('*Tj_save_and_exec')
  function! Tj_save_and_exec() abort
    :silent! write
    :source %
    return
  endfunction
endif

" Execute this file
nnoremap <space><space>x <cmd>call Tj_save_and_exec()<CR>

" Execute selection
xnoremap <space><space>x :so<CR>

" Disable continuation of comments
" It seems like plugins enable this
" Use autocmd to override plugin
autocmd BufNewFile,BufRead * setlocal formatoptions-=cro

" Quickfix
nmap <A-j> <cmd>cn<CR>
nmap <A-k> <cmd>cp<CR>

nnoremap <space>y "+y
xnoremap <space>y "+y
vnoremap <space>y "+y

" Auto save
" https://stackoverflow.com/questions/17365324/auto-save-in-vim-as-you-type
command AutoSave au CursorHold,CursorHoldI <buffer> if &readonly == 0 && filereadable(bufname('%')) | silent write | endif

" set nottimeout
set ttimeoutlen=0

" word back and forward like bash
imap <silent> <a-b> <c-o>B
imap <silent> <a-f> <c-o>W

