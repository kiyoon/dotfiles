## PowerShell

Basic linux feels within powershell.

```powershell
winget install -e --id Microsoft.PowerShell --source winget
winget install -e --id uutils.coreutils
winget install -e --id JernejSimoncic.Wget

winget install -e --id eza-community.eza
winget install -e --id sharkdp.bat
winget install -e --id=BurntSushi.ripgrep.MSVC
winget install -e --id=sharkdp.fd
winget install -e --id=ajeetdsouza.zoxide
winget install -e --id Clement.bottom
winget install -e --id=bootandy.dust
winget install -e --id=sxyazi.yazi
winget install -e --id=YS-L.csvlens

winget install -e --id=junegunn.fzf
Install-Module -Name PSFzf

winget install Neovim.Neovim
winget install -e --id Git.Git
winget install wez.wezterm
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Starship.Starship

winget install -e --id LGUG2Z.komorebi
winget install -e --id LGUG2Z.whkd

winget install -e --id=astral-sh.uv
winget install -e --id=astral-sh.ruff
```

> [!NOTE]
> Use newer `pwsh.exe` instead of `powershell.exe`.

The profile file location is at `nvim $profile`. Put the profile file content there.

Missing commands like `grep`, `awk`, `sed` etc. comes with Cygwin.

### Cygwin

Fully-featured bash / zsh experience with Cygwin.

#### Install apt-cyg
Required additional packages:

- wget
- gnupg2
- libiconv
- ca-certificates

```bash
# Enter cygwin bash
# C:\cygwin64\bin\bash -i -l
# or, `cygbash` alias

cd
mkdir bin
cd bin
git clone https://github.com/kou1okada/apt-cyg.git
ln -s "$(realpath apt-cyg/apt-cyg)" /usr/local/bin/
```

#### Install zsh 5.9
Cygwin only has zsh up to 5.8.

```bash
apt-cyg install make
apt-cyg install gcc-core
apt-cyg install libncurses-devel
# TODO: add zsh-local-install.sh
bash zsh-local-install.sh
```

**oh-my-zsh**

```bash
apt-cyg install git
PATH="$HOME/.local/bin:$PATH" bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

# pgrep, pkill
apt-cyg install procps-ng

# starship path should not have space in its path..
# and the install script doesn't work within cygwin.
# Thus copy C:\Program Files\starship/bin/starship to /usr/local/bin
cp "$(which starship)" /usr/local/bin
```

### Caps Lock -> Ctrl
```powershell
# administrator
$hexified = "00,00,00,00,00,00,00,00,02,00,00,00,1d,00,3a,00,00,00,00,00".Split(',') | % { "0x$_"};
$kbLayout = 'HKLM:\System\CurrentControlSet\Control\Keyboard Layout';    
New-ItemProperty -Path $kbLayout -Name "Scancode Map" -PropertyType Binary -Value ([byte[]]$hexified);
```
