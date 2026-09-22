## PowerShell

Basic linux feels within powershell.

```powershell
winget install -e --id jdx.mise
winget install -e --id Microsoft.PowerShell --source winget
winget install -e --id JernejSimoncic.Wget
Install-Module -Name PSFzf
winget install -e --id Git.Git
winget install -e --id GnuPG.Gpg4win
winget install wez.wezterm
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Starship.Starship
winget install -e --id LGUG2Z.komorebi
winget install -e --id LGUG2Z.whkd
```

> [!NOTE]
> Use newer `pwsh.exe` instead of `powershell.exe`.

The profile file location is at `nvim $profile`. Put the profile file content there.

Missing commands like `grep`, `awk`, `sed` etc. comes with uutils-coreutils and Cygwin.

### Mise-managed CLI tools

Global CLI tools are installed with `mise`. Native Windows uses the files in
`windows/mise-config/`; macOS and Linux use the repository's `mise-config/config.toml`.
The source directories use `mise-config` so mise does not load them as project
configs before installation.
`windows/mise.toml` links `windows/mise-config/` to `~/.config/mise` as a junction,
so `mise lock --global` updates the files in this repository. Run it from `windows/`;
the repository root links the macOS/Linux config instead:

```powershell
cd ~/.config/dotfiles/windows
mise trust
mise run setup-dotfiles  # add --force to replace an existing ~/.config/mise
```

On the first machine, install the tools and generate the lockfile:

```sh
mise install
mise lock --global
```

Commit both windows/mise-config/config.toml and windows/mise-config/mise.lock.

On a new machine where the lockfile already exists:

```sh
mise install --locked
```

To update the managed tools later:

```sh
mise upgrade
mise lock --global
```

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
