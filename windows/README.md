```powershell
winget install -e --id Microsoft.PowerShell --source winget
winget install -e --id uutils.coreutils
winget install -e --id JernejSimoncic.Wget

winget install -e --id eza-community.eza
winget install -e --id sharkdp.bat
winget install -e --id=BurntSushi.ripgrep.MSVC
winget install -e --id=sharkdp.fd
winget install -e --id=ajeetdsouza.zoxide
winget install -e --id=junegunn.fzf
winget install -e --id Clement.bottom
winget install -e --id=bootandy.dust
winget install -e --id=sxyazi.yazi
winget install -e --id=YS-L.csvlens

winget install Neovim.Neovim
winget install -e --id Git.Git
winget install wez.wezterm
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Starship.Starship

winget install -e --id LGUG2Z.komorebi
winget install -e --id LGUG2Z.whkd
```

> [!NOTE]
> Use newer `pwsh.exe` instead of `powershell.exe`.

`nvim $profile`

```powershell
Set-Alias vi nvim -Option AllScope
```
