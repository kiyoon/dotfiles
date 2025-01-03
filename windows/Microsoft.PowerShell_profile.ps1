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
function coreutils_b2sum { & coreutils b2sum $args }
Set-Alias b2sum coreutils_b2sum -Option AllScope
function coreutils_b3sum { & coreutils b3sum $args }
Set-Alias b3sum coreutils_b3sum -Option AllScope
function coreutils_base32 { & coreutils base32 $args }
Set-Alias base32 coreutils_base32 -Option AllScope
function coreutils_base64 { & coreutils base64 $args }
Set-Alias base64 coreutils_base64 -Option AllScope
function coreutils_basename { & coreutils basename $args }
Set-Alias basename coreutils_basename -Option AllScope 
function coreutils_basenc { & coreutils basenc $args }
Set-Alias basenc coreutils_basenc -Option AllScope
# function coreutils_cat { & coreutils cat $args }
# Set-Alias cat coreutils_cat -Option AllScope
function coreutils_cksum { & coreutils cksum $args }
Set-Alias cksum coreutils_cksum -Option AllScope
function coreutils_comm { & coreutils comm $args }
Set-Alias comm coreutils_comm -Option AllScope
function coreutils_cp { & coreutils cp $args }
Set-Alias cp coreutils_cp -Option AllScope
function coreutils_csplit { & coreutils csplit $args }
Set-Alias csplit coreutils_csplit -Option AllScope
function coreutils_cut { & coreutils cut $args }
Set-Alias cut coreutils_cut -Option AllScope
function coreutils_date { & coreutils date $args }
Set-Alias date coreutils_date -Option AllScope
function coreutils_dd { & coreutils dd $args }
Set-Alias dd coreutils_dd -Option AllScope
function coreutils_df { & coreutils df $args }
Set-Alias df coreutils_df -Option AllScope
function coreutils_dir { & coreutils dir $args }
Set-Alias dir coreutils_dir -Option AllScope
function coreutils_dircolors { & coreutils dircolors $args }
Set-Alias dircolors coreutils_dircolors -Option AllScope
function coreutils_dirname { & coreutils dirname $args }
Set-Alias dirname coreutils_dirname -Option AllScope
function coreutils_du { & coreutils du $args }
Set-Alias du coreutils_du -Option AllScope
function coreutils_echo { & coreutils echo $args }
Set-Alias echo coreutils_echo -Option AllScope
function coreutils_env { & coreutils env $args }
Set-Alias env coreutils_env -Option AllScope
function coreutils_expand { & coreutils expand $args }
Set-Alias expand coreutils_expand -Option AllScope
function coreutils_expr { & coreutils expr $args }
Set-Alias expr coreutils_expr -Option AllScope
function coreutils_factor { & coreutils factor $args }
Set-Alias factor coreutils_factor -Option AllScope
function coreutils_false { & coreutils false $args }
Set-Alias false coreutils_false -Option AllScope
function coreutils_fmt { & coreutils fmt $args }
Set-Alias fmt coreutils_fmt -Option AllScope
function coreutils_fold { & coreutils fold $args }
Set-Alias fold coreutils_fold -Option AllScope
function coreutils_hashsum { & coreutils hashsum $args }
Set-Alias hashsum coreutils_hashsum -Option AllScope
function coreutils_head { & coreutils head $args }
Set-Alias head coreutils_head -Option AllScope
function coreutils_hostname { & coreutils hostname $args }
Set-Alias hostname coreutils_hostname -Option AllScope
function coreutils_join { & coreutils join $args }
Set-Alias join coreutils_join -Option AllScope
function coreutils_link { & coreutils link $args }
Set-Alias link coreutils_link -Option AllScope
function coreutils_ln { & coreutils ln $args }
Set-Alias ln coreutils_ln -Option AllScope
# function coreutils_ls { & coreutils ls $args }
# Set-Alias ls coreutils_ls -Option AllScope
function coreutils_md5sum { & coreutils md5sum $args }
Set-Alias md5sum coreutils_md5sum -Option AllScope
function coreutils_mkdir { & coreutils mkdir $args }
Set-Alias mkdir coreutils_mkdir -Option AllScope
function coreutils_mktemp { & coreutils mktemp $args }
Set-Alias mktemp coreutils_mktemp -Option AllScope
function coreutils_more { & coreutils more $args }
Set-Alias more coreutils_more -Option AllScope
function coreutils_mv { & coreutils mv $args }
Set-Alias mv coreutils_mv -Option AllScope
function coreutils_nl { & coreutils nl $args }
Set-Alias nl coreutils_nl -Option AllScope
function coreutils_nproc { & coreutils nproc $args }
Set-Alias nproc coreutils_nproc -Option AllScope
function coreutils_numfmt { & coreutils numfmt $args }
Set-Alias numfmt coreutils_numfmt -Option AllScope
function coreutils_od { & coreutils od $args }
Set-Alias od coreutils_od -Option AllScope
function coreutils_paste { & coreutils paste $args }
Set-Alias paste coreutils_paste -Option AllScope
function coreutils_pr { & coreutils pr $args }
Set-Alias pr coreutils_pr -Option AllScope
function coreutils_printenv { & coreutils printenv $args }
Set-Alias printenv coreutils_printenv -Option AllScope
function coreutils_printf { & coreutils printf $args }
Set-Alias printf coreutils_printf -Option AllScope
function coreutils_ptx { & coreutils ptx $args }
Set-Alias ptx coreutils_ptx -Option AllScope
function coreutils_pwd { & coreutils pwd $args }
Set-Alias pwd coreutils_pwd -Option AllScope
function coreutils_readlink { & coreutils readlink $args }
Set-Alias readlink coreutils_readlink -Option AllScope
function coreutils_realpath { & coreutils realpath $args }
Set-Alias realpath coreutils_realpath -Option AllScope
function coreutils_rm { & coreutils rm $args }
Set-Alias rm coreutils_rm -Option AllScope
function coreutils_rmdir { & coreutils rmdir $args }
Set-Alias rmdir coreutils_rmdir -Option AllScope
function coreutils_seq { & coreutils seq $args }
Set-Alias seq coreutils_seq -Option AllScope
function coreutils_sha1sum { & coreutils sha1sum $args }
Set-Alias sha1sum coreutils_sha1sum -Option AllScope
function coreutils_sha224sum { & coreutils sha224sum $args }
Set-Alias sha224sum coreutils_sha224sum -Option AllScope
function coreutils_sha256sum { & coreutils sha256sum $args }
Set-Alias sha256sum coreutils_sha256sum -Option AllScope
function coreutils_sha3-224sum { & coreutils sha3-224sum $args }
Set-Alias sha3-224sum coreutils_sha3-224sum -Option AllScope
function coreutils_sha3-256sum { & coreutils sha3-256sum $args }
Set-Alias sha3-256sum coreutils_sha3-256sum -Option AllScope
function coreutils_sha3-384sum { & coreutils sha3-384sum $args }
Set-Alias sha3-384sum coreutils_sha3-384sum -Option AllScope
function coreutils_sha3-512sum { & coreutils sha3-512sum $args }
Set-Alias sha3-512sum coreutils_sha3-512sum -Option AllScope
function coreutils_sha384sum { & coreutils sha384sum $args }
Set-Alias sha384sum coreutils_sha384sum -Option AllScope
function coreutils_sha3sum { & coreutils sha3sum $args }
Set-Alias sha3sum coreutils_sha3sum -Option AllScope
function coreutils_sha512sum { & coreutils sha512sum $args }
Set-Alias sha512sum coreutils_sha512sum -Option AllScope
function coreutils_shake128sum { & coreutils shake128sum $args }
Set-Alias shake128sum coreutils_shake128sum -Option AllScope
function coreutils_shake256sum { & coreutils shake256sum $args }
Set-Alias shake256sum coreutils_shake256sum -Option AllScope
function coreutils_shred { & coreutils shred $args }
Set-Alias shred coreutils_shred -Option AllScope
function coreutils_shuf { & coreutils shuf $args }
Set-Alias shuf coreutils_shuf -Option AllScope
function coreutils_sleep { & coreutils sleep $args }
Set-Alias sleep coreutils_sleep -Option AllScope
function coreutils_sort { & coreutils sort $args }
Set-Alias sort coreutils_sort -Option AllScope
function coreutils_split { & coreutils split $args }
Set-Alias split coreutils_split -Option AllScope
function coreutils_sum { & coreutils sum $args }
Set-Alias sum coreutils_sum -Option AllScope
function coreutils_sync { & coreutils sync $args }
Set-Alias sync coreutils_sync -Option AllScope
function coreutils_tac { & coreutils tac $args }
Set-Alias tac coreutils_tac -Option AllScope
function coreutils_tail { & coreutils tail $args }
Set-Alias tail coreutils_tail -Option AllScope
function coreutils_tee { & coreutils tee $args }
Set-Alias tee coreutils_tee -Option AllScope
function coreutils_test { & coreutils test $args }
Set-Alias test coreutils_test -Option AllScope
function coreutils_touch { & coreutils touch $args }
Set-Alias touch coreutils_touch -Option AllScope
function coreutils_tr { & coreutils tr $args }
Set-Alias tr coreutils_tr -Option AllScope
function coreutils_true { & coreutils true $args }
Set-Alias true coreutils_true -Option AllScope
function coreutils_truncate { & coreutils truncate $args }
Set-Alias truncate coreutils_truncate -Option AllScope
function coreutils_tsort { & coreutils tsort $args }
Set-Alias tsort coreutils_tsort -Option AllScope
function coreutils_uname { & coreutils uname $args }
Set-Alias uname coreutils_uname -Option AllScope
function coreutils_unexpand { & coreutils unexpand $args }
Set-Alias unexpand coreutils_unexpand -Option AllScope
function coreutils_uniq { & coreutils uniq $args }
Set-Alias uniq coreutils_uniq -Option AllScope
function coreutils_unlink { & coreutils unlink $args }
Set-Alias unlink coreutils_unlink -Option AllScope
function coreutils_vdir { & coreutils vdir $args }
Set-Alias vdir coreutils_vdir -Option AllScope
function coreutils_wc { & coreutils wc $args }
Set-Alias wc coreutils_wc -Option AllScope
function coreutils_whoami { & coreutils whoami $args }
Set-Alias whoami coreutils_whoami -Option AllScope
function coreutils_yes { & coreutils yes $args }
Set-Alias yes coreutils_yes -Option AllScope

