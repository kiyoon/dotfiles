# My ZSH Custom for local/SSH users

I develop often on remote servers that I don't have `sudo` permission. This awesome zsh settings allow you to install **locally, without root permission**.

## ZSH Basics (Getting Started)

- [Oh My Zsh](https://ohmyz.sh/): Manage zsh configuration. Includes many small plugins.
    - [git](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git): aliases for many git commands.
    - [dirhistory](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/dirhistory): Alt+Left/Right to navigate directory history. Alt+Up to go to the parent directory.
    - It will source all files in `custom/` directory.

- [Starship](https://starship.rs/): Prompt (theme) that shows project statuses (git, conda, python version, etc.)
- Some commands are aliased (e.g., `ls` -> `eza`, `cat` -> `bat`, `vi` -> `nvim`).
    - When you want to use the original command, add `\` prefix (e.g. `\ls`, `\cat`).

## Setup

Install zsh locally. (🚨 warning: `sudo apt install zsh` may install an old version. Use the script below.)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/zsh-local-install.sh)"
```

Install package managers.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/install-installers.sh)"
```

Add settings to `~/.bashrc` that launches zsh when in bash login shell (if you don't have root permission and can't do `chsh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/launch-zsh-in-bash.sh)"
```

Install oh-my-zsh:

```zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Install / update plugins:

```zsh
git submodule update --init --remote
```

Install apps:

```zsh
##### tig, eza, gh, starship, ..
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/apps-local-install.sh)"
```

Copy/symlink `.zshrc` to `$HOME`.

## Cache cleanup

`cache-clean` runs each installed program's own cleanup command and respects its
configured cache locations. Open a new shell or run
`source "$DOTFILES_DIR/oh-my-zsh/custom/scripts.zsh"` to load it.

```zsh
cache-clean --list           # Show supported programs and missing dependencies
cache-clean --dry-run        # Preview commands without cleaning anything
cache-clean                  # Clean all available default targets
cache-clean uv cargo bun     # Clean only these programs
cache-clean docker           # Explicitly prune unused Docker build cache
```

It also works directly with `bash oh-my-zsh/scripts/cache-clean.sh` from this
repository. Missing programs are skipped; failures are reported while the other
targets continue. It exits with status 1 if a cleanup fails and 2 for invalid
arguments. It does not install tools or use `sudo`.

| Program | Cleanup |
| --- | --- |
| uv | All uv cache entries |
| pip (or pip3) | HTTP and wheel caches |
| Bun | Global package cache |
| npm | Package cache |
| pnpm | Unreferenced packages in the store |
| Yarn | Global cache (Classic or modern Yarn; preserves modern project caches) |
| Cargo | Registry and Git caches through `cargo-cache` |
| Go | Build, test, module download, and fuzz caches |
| Conda, Mamba, Micromamba | Archive and index caches; preserves extracted packages that environments may link to |
| Pixi | Pixi-managed caches |
| Homebrew | Native `cleanup --prune=all --scrub`, including old installed versions |
| Deno | Deno cache |
| mise | mise cache |
| ccache | Compiler cache |
| Composer | Composer cache |
| .NET | All local NuGet caches, including downloaded packages |
| Docker (explicit only) | All unused build cache on the current builder; may target a remote builder |

Cargo support requires [cargo-cache](https://github.com/matthiaskrgr/cargo-cache):
install it once with `cargo install cargo-cache`. The cleaner reports and skips
Cargo if it is missing. This cleans the shared cache; project build output is
handled separately by Cargo's `cargo clean` command.

Programs control what can be reclaimed: for example, pnpm keeps referenced
packages, and Homebrew may retain downloads for installed packages. Subsequent
builds or installs may need to download or rebuild cached dependencies.
