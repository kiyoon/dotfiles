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

From the cloned dotfiles directory, link the global mise config and bootstrap
standalone uv, Bun and rustup, mise, CLI tools, Oh My Zsh and conda:

```bash
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
mise trust
mise run setup-dotfiles
oh-my-zsh/install-installers.sh
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise -C "$HOME" env -s bash)"
```

Add settings to `~/.bashrc` that launches zsh when in bash login shell (if you don't have root permission and can't do `chsh`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kiyoon/dotfiles/master/oh-my-zsh/launch-zsh-in-bash.sh)"
```

Install / update plugins:

```zsh
git submodule update --init --remote
```

Install the checked-in CLI versions from [mise.lock](../mise-config/mise.lock):

```zsh
mise -C "$HOME" install --locked
mise -C "$HOME" run install-extras
```

To update versions, run `mise -C "$HOME" lock --global --bump` first and commit
the resulting lockfile. See the root README for GitHub authentication when updating.

The linked `.zshrc` activates mise before loading Oh My Zsh plugins and custom files.
It also deduplicates PATH (`typeset -U path`) and no longer forces `/usr/bin` ahead of Homebrew.
uv and Bun stay outside mise: Homebrew installs them on macOS, and their official
installers place them in `~/.local/bin` and `~/.bun/bin` on Linux.

Rust/Cargo stay under rustup, using the existing Cargo home and default toolchain.
The bootstrap installs/updates stable without replacing an existing default, and
installs cargo-binstall next to it (outside mise) for ad-hoc `cargo binstall` use.
Use `rustup update` to update Rust separately from mise-managed CLI tools.

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
| Bun | Global install cache and cached `bunx` packages, run from a temporary empty package because `bun pm cache rm` refuses to run outside one |
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

## Codex usage

`codex-usage` prints the current Codex rate-limit windows for every Codex home
(`~/.codex` plus any `~/.codex-*` that has an `auth.json`). Each run is one live
request per home to the endpoint Codex's own `/status` uses, authenticated with
the tokens Codex CLI already stores, so there is nothing extra to log in to. It
never refreshes tokens itself (Codex CLI owns them); an expired token is
reported, and starting Codex in that home refreshes it. Open a new shell or run
`source "$DOTFILES_DIR/oh-my-zsh/custom/scripts.zsh"` to load it.

```zsh
codex-usage                          # All homes; the arrow marks the home a bare `codex` uses
codex-usage --json                   # Raw API response per home
CODEX_HOMES=~/.codex-x codex-usage   # Override discovery (or pass home directories as arguments)
```

Offline tests: `python3 oh-my-zsh/scripts/tests/codex-usage_test.py`.
