#!/usr/bin/env bash
# Test the deletion dispatcher with an isolated PATH containing only stubs.
# No real cache cleaner, installer, or directory-removal command can run there.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLEANER="$SCRIPT_DIR/cache-clean.sh"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
STUB_DIR="$TEST_TMP/bin"
mkdir -p "$STUB_DIR"
export CACHE_CLEAN_TEST_LOG="$TEST_TMP/commands.log"

cat >"$TEST_TMP/stub" <<'STUB'
#!/bin/bash
program="${0##*/}"
printf '%s %s\n' "$program" "$*" >>"$CACHE_CLEAN_TEST_LOG"
if [[ "$program" == "${CACHE_CLEAN_TEST_FAIL_PROGRAM:-}" ]]; then
	exit "${CACHE_CLEAN_TEST_FAIL_STATUS:-37}"
fi
if [[ "$program" == yarn && "$*" == --version ]]; then
	printf '%s\n' "${CACHE_CLEAN_TEST_YARN_VERSION:-4.9.0}"
fi
STUB

for program in uv pip pip3 cargo cargo-cache bun npm pnpm yarn go conda mamba micromamba pixi brew deno mise ccache composer dotnet docker; do
	cp "$TEST_TMP/stub" "$STUB_DIR/$program"
	chmod +x "$STUB_DIR/$program"
done

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$3"; }
absent() { if grep -Fq -- "$2" "$1"; then fail "$3"; fi; }

run_cleaner() {
	: >"$CACHE_CLEAN_TEST_LOG"
	run_status=0
	PATH="$STUB_DIR" /bin/bash "$CLEANER" "$@" >"$TEST_TMP/output" 2>&1 || run_status=$?
}

run_cleaner --dry-run
[[ "$run_status" -eq 0 ]] || fail 'default preview failed'
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == 'yarn --version' ]] || fail 'preview ran a cleanup command'
absent "$TEST_TMP/output" 'docker builder' 'Docker must require an explicit target'

run_cleaner --list
[[ "$run_status" -eq 0 ]] || fail 'listing failed'
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == 'yarn --version' ]] || fail 'listing ran a cleanup command'
contains "$TEST_TMP/output" 'docker builder prune' 'listing must expose optional Docker cleanup'

run_cleaner uv bun --unknown
[[ "$run_status" -eq 2 && ! -s "$CACHE_CLEAN_TEST_LOG" ]] || fail 'unknown options must fail before any cleanup'
run_cleaner uv 'bun; exit 0'
[[ "$run_status" -eq 2 && ! -s "$CACHE_CLEAN_TEST_LOG" ]] || fail 'unknown targets must fail before any cleanup'

run_cleaner uv bun uv --dry-run
[[ "$run_status" -eq 0 && ! -s "$CACHE_CLEAN_TEST_LOG" ]] || fail 'trailing preview option was not honored'
run_cleaner uv bun uv
[[ "$run_status" -eq 0 ]] || fail 'explicit targets failed'
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == $'uv cache clean\nbun pm cache rm' ]] || fail 'selection must preserve order and deduplicate targets'

export CACHE_CLEAN_TEST_FAIL_PROGRAM=uv
run_cleaner uv bun
[[ "$run_status" -eq 1 ]] || fail 'cleanup failures must return nonzero'
contains "$CACHE_CLEAN_TEST_LOG" 'bun pm cache rm' 'other targets must run after a failure'
contains "$TEST_TMP/output" '1 succeeded, 0 skipped, 1 failed' 'failure summary is incorrect'
export CACHE_CLEAN_TEST_FAIL_STATUS=130
run_cleaner uv bun
[[ "$run_status" -eq 130 ]] || fail 'interrupt exit status must propagate'
absent "$CACHE_CLEAN_TEST_LOG" bun 'interrupt must stop subsequent cleanups'
unset CACHE_CLEAN_TEST_FAIL_PROGRAM CACHE_CLEAN_TEST_FAIL_STATUS

mv "$STUB_DIR/cargo-cache" "$TEST_TMP/cargo-cache"
run_cleaner cargo bun
[[ "$run_status" -eq 0 ]] || fail 'missing optional dependency should be skipped'
contains "$TEST_TMP/output" 'requires cargo-cache' 'missing Cargo dependency needs an actionable explanation'
absent "$CACHE_CLEAN_TEST_LOG" cargo 'missing cargo-cache must not trigger cargo clean or an install'
contains "$CACHE_CLEAN_TEST_LOG" 'bun pm cache rm' 'missing dependency must not block other targets'
mv "$TEST_TMP/cargo-cache" "$STUB_DIR/cargo-cache"
run_cleaner cargo
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == 'cargo cache --remove-dir all' ]] || fail 'Cargo must clean its shared cache through cargo-cache'

mv "$STUB_DIR/pip" "$TEST_TMP/pip"
run_cleaner pip
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == 'pip3 cache purge' ]] || fail 'pip3 fallback failed'
mv "$STUB_DIR/pip3" "$TEST_TMP/pip3"
run_cleaner pip
[[ "$run_status" -eq 0 && ! -s "$CACHE_CLEAN_TEST_LOG" ]] || fail 'missing pip should be skipped'
contains "$TEST_TMP/output" '[skip] pip:' 'missing pip should be reported'
mv "$TEST_TMP/pip" "$STUB_DIR/pip"
mv "$TEST_TMP/pip3" "$STUB_DIR/pip3"

export CACHE_CLEAN_TEST_YARN_VERSION=1.22.22
run_cleaner yarn
contains "$CACHE_CLEAN_TEST_LOG" 'yarn cache clean' 'Yarn Classic cleanup missing'
absent "$CACHE_CLEAN_TEST_LOG" --mirror 'Yarn Classic does not support --mirror'
export CACHE_CLEAN_TEST_YARN_VERSION=4.9.0
run_cleaner yarn
contains "$CACHE_CLEAN_TEST_LOG" 'yarn cache clean --mirror' 'modern Yarn must preserve project caches'
export CACHE_CLEAN_TEST_YARN_VERSION=unknown
run_cleaner yarn
absent "$CACHE_CLEAN_TEST_LOG" 'yarn cache clean' 'unknown Yarn must not guess potentially destructive flags'
unset CACHE_CLEAN_TEST_YARN_VERSION

run_cleaner conda mamba micromamba
[[ "$run_status" -eq 0 ]] || fail 'Conda-family cleanup failed'
absent "$CACHE_CLEAN_TEST_LOG" --all 'Conda-family cleanup must preserve extracted packages'
absent "$CACHE_CLEAN_TEST_LOG" --packages 'Conda-family cleanup must preserve extracted packages'
absent "$CACHE_CLEAN_TEST_LOG" --force-pkgs-dirs 'Conda-family cleanup must preserve environments'
contains "$CACHE_CLEAN_TEST_LOG" --tarballs 'archive cleanup missing'
contains "$CACHE_CLEAN_TEST_LOG" --index-cache 'index cleanup missing'

run_cleaner docker
[[ "$(cat "$CACHE_CLEAN_TEST_LOG")" == 'docker builder prune --all --force' ]] || fail 'Docker must only prune build cache'

run_cleaner
[[ "$run_status" -eq 0 ]] || fail 'default cleanup failed'
contains "$TEST_TMP/output" '18 succeeded, 0 skipped, 0 failed' 'default summary is incorrect'
absent "$CACHE_CLEAN_TEST_LOG" docker 'default cleanup must not contact Docker'

# Verify the shell entry point forwards arguments and quotes the dotfiles path.
mkdir -p "$TEST_TMP/dotfiles with spaces/oh-my-zsh/scripts"
cp "$CLEANER" "$TEST_TMP/dotfiles with spaces/oh-my-zsh/scripts/cache-clean.sh"
: >"$CACHE_CLEAN_TEST_LOG"
PATH="$STUB_DIR:/bin:/usr/bin" /bin/zsh -f -c '
	# Capture the root in a function without changing HOME or loading .zshrc.
	function dotfiles_dir { print -r -- "$cache_clean_test_root"; }
	cache_clean_test_root="$1"
	source "$2"
	cache-clean --dry-run uv bun
' zsh "$TEST_TMP/dotfiles with spaces" "$SCRIPT_DIR/../custom/scripts.zsh" >"$TEST_TMP/output" 2>&1 || fail 'zsh wrapper failed'
[[ ! -s "$CACHE_CLEAN_TEST_LOG" ]] || fail 'zsh wrapper lost --dry-run'
contains "$TEST_TMP/output" '[dry-run] bun: bun pm cache rm' 'zsh wrapper lost target arguments'

printf 'All cache-clean tests passed.\n'
