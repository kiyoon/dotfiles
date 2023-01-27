if get(g:, 'tex_fast', 'r') =~# 'r'
  syntax match texStatement '\\\(\(label\)\?c\(page\)\?\|C\|auto\)ref\>'
        \ nextgroup=texCRefZone

  " \crefrange, \cpagerefrange (these commands expect two arguments)
  syntax match texStatement '\\c\(page\)\?refrange\>'
        \ nextgroup=texCRefZoneRange skipwhite skipnl

  " \label[xxx]{asd}
  syntax match texStatement '\\label\[.\{-}\]'
        \ nextgroup=texCRefZone skipwhite skipnl
        \ contains=texCRefLabelOpts

  syntax region texCRefZone contained matchgroup=Delimiter
        \ start="{" end="}"
        \ contains=@texRefGroup,texRefZone
  syntax region texCRefZoneRange contained matchgroup=Delimiter
        \ start="{" end="}"
        \ contains=@texRefGroup,texRefZone
        \ nextgroup=texCRefZone skipwhite skipnl
  syntax region texCRefLabelOpts contained matchgroup=Delimiter
        \ start='\[' end=']'
        \ contains=@texRefGroup,texRefZone

  highlight link texCRefZone      texRefZone
  highlight link texCRefZoneRange texRefZone
  highlight link texCRefLabelOpts texCmdArgs
endif
