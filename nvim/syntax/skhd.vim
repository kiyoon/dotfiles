" ~/.vim/syntax/skhd.vim
if exists("b:current_syntax")
  finish
endif

" Comments: whole line from '#'
syn match skhdComment   /^#.*/ 

" Modifiers (shift, ctrl, alt, cmd, fn)
syn keyword skhdModifier shift ctrl alt option cmd fn super hyper
" highlight the '+' and '-' and ':' separators
syn match   skhdOperator   /[+:-]/

" Keys (a–z, digits, function‐keys, arrows…)
syn keyword skhdKey up down left right home end pageup pagedown tab escape space enter  

" The yabai command and its subcommands
syn match skhdCommand /\<yabai\>\|\<open\>/
syn match skhdSubCmd   /\<window\>\|\<space\>\|\<display\>/

" ───────────────────────────────────────────────────────────────────
"  Treat anything after a single “:” (not double‑colon) as bash
" ───────────────────────────────────────────────────────────────────
" load Vim’s built‑in shell rules
syntax include @bash syntax/bash.vim

" After `:` (not `::`) is a bash command, but not when it is preceded by a `\`
syntax region skhdBash matchgroup=skhdOperator start=/[^:]\zs:\s*/ skip=/\\\s*$/ end=/$/ keepend contains=@bash

" ────────────────────────────────────────────────────────────────
"  Key‑map group definitions and switches
" ────────────────────────────────────────────────────────────────
" In skhd, you can define groups and assign hotkeys to them as follows:
" 1. Group‑definition lines that start with :: <group>
" 2. Switch operator (<)
" 3. Target group names after the ;

" Lines like `:: default` or `:: passthrough`
"   match the whole thing as a GroupDef, but capture the group name
syn match   skhdGroupDef    /^::\s*\w\+/
syn match   skhdGroupName   /::\s*\zs\w\+/

" The `<` switch token in lines like
"   passthrough < cmd + shift + alt - b ; default
syn match   skhdSwitch      /<\s*/

" The target (or “fall‑through”) group after the semicolon
"   ... ; default
syn match   skhdTargetGroup /;\s*\zs\w\+/


" ────────────────────────────────────────────────────────────────
"  Linking to standard Vim highlight groups
" ────────────────────────────────────────────────────────────────
hi def link skhdComment    Comment
hi def link skhdHeadline   Title
hi def link skhdModifier   Keyword
hi def link skhdOperator   Operator
hi def link skhdKey        Identifier
hi def link skhdCommand    Function
hi def link skhdSubCmd     Statement
hi def link skhdGroupDef      Label
hi def link skhdGroupName     Identifier
hi def link skhdSwitch        Operator
hi def link skhdTargetGroup   Type

let b:current_syntax = "skhd"
