#$Env:PATH += ";$env:USERPROFILE\bin"

Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
# example command - use $Location with a different command:
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }
# pass your override to PSFzf:
Set-PsFzfOption -AltCCommand $commandOverride
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-PsFzfOption -TabExpansion

Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine

Set-Alias vi nvim -Option AllScope
function eza_ls { & eza --icons auto --hyperlink $args }
Set-Alias ls eza_ls -Option AllScope 
function eza_ll { & eza -alF --icons auto --hyperlink $args }
Set-Alias ll eza_ll -Option AllScope 
function eza_la { & eza -a --icons auto --hyperlink $args }
Set-Alias la eza_la -Option AllScope 
function eza_l { & eza -F --icons auto --hyperlink $args }
Set-Alias l eza_l -Option AllScope 
function eza_lg { & eza --git-ignore --icons auto --hyperlink $args }
Set-Alias lg eza_lg -Option AllScope 

# https://github.com/uutils/coreutils
#arch, b2sum, b3sum, base32, base64, basename, basenc, cat, cksum, comm, cp, csplit, cut,
#    date, dd, df, dir, dircolors, dirname, du, echo, env, expand, expr, factor, false, fmt,
#    fold, hashsum, head, hostname, join, link, ln, ls, md5sum, mkdir, mktemp, more, mv, nl,
#    nproc, numfmt, od, paste, pr, printenv, printf, ptx, pwd, readlink, realpath, rm, rmdir,
#    seq, sha1sum, sha224sum, sha256sum, sha3-224sum, sha3-256sum, sha3-384sum, sha3-512sum,
#    sha384sum, sha3sum, sha512sum, shake128sum, shake256sum, shred, shuf, sleep, sort, split,
#    sum, sync, tac, tail, tee, test, touch, tr, true, truncate, tsort, uname, unexpand, uniq,
#    unlink, vdir, wc, whoami, yes
function coreutils_arch { & coreutils arch $args }
Set-Alias arch coreutils_arch -Option AllScope 
function coreutils_basename { & coreutils basename $args }
Set-Alias basename coreutils_basename -Option AllScope 
