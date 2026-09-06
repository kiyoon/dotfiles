#!/usr/bin/env bash
# Use each program's cache API so it can honor its own paths and configuration.
# Compatible with macOS's Bash 3.2; no package manager is needed to run this script.

set -u
trap 'exit 130' INT
trap 'exit 143' TERM

default_targets=(uv pip bun npm pnpm yarn cargo go conda mamba micromamba pixi brew deno mise ccache composer dotnet)
all_targets=("${default_targets[@]}" docker)

usage() {
	cat <<'EOF'
Usage: cache-clean [--dry-run] [PROGRAM ...]
       cache-clean --list [PROGRAM ...]

Clean caches through installed programs' own commands. With no program names,
run all default targets, skipping unavailable programs. No sudo or installs.

  -n, --dry-run  Show commands without running cleanup (may query versions).
  -l, --list     List available targets, commands, and missing dependencies.
  -h, --help     Show this help.

Default targets:
  uv pip bun npm pnpm yarn cargo go conda mamba micromamba pixi brew deno
  mise ccache composer dotnet

Explicit target only:
  docker        Prune all unused build cache on the current Docker builder.

Bun's global cache is cleared from a temporary empty package, because
bun pm cache rm refuses to run outside a package.
Cargo needs cargo-cache (install with: cargo install cargo-cache).
Conda/Mamba clean archive and index caches, preserving extracted packages.
Homebrew also removes old installed versions as part of its native cleanup.
Go and NuGet clear downloaded packages; future builds may need downloads.

Examples:
  cache-clean --dry-run
  cache-clean
  cache-clean uv cargo bun
  cache-clean docker

Failures do not stop other targets. Exit status: 0 = no failures (missing
programs are skipped), 1 = cleanup failed, 2 = invalid arguments.
EOF
}

mode=run
targets=()
for argument in "$@"; do
	case "$argument" in
	-n | --dry-run) mode=preview ;;
	-l | --list) mode=list ;;
	-h | --help) usage; exit 0 ;;
	-*) printf 'cache-clean: unknown option: %s\n' "$argument" >&2; exit 2 ;;
	*)
		known=false
		for target in "${all_targets[@]}"; do
			if [[ "$target" == "$argument" ]]; then known=true; break; fi
		done
		if [[ "$known" == false ]]; then
			printf 'cache-clean: unknown program: %s (see --list)\n' "$argument" >&2
			exit 2
		fi
		# Repeated program names should only clean once.
		duplicate=false
		# Bash 3.2 treats an empty array as unset under set -u.
		if [[ ${#targets[@]} -gt 0 ]]; then
			for target in "${targets[@]}"; do
				if [[ "$target" == "$argument" ]]; then duplicate=true; break; fi
			done
		fi
		if [[ "$duplicate" == false ]]; then targets+=("$argument"); fi
		;;
	esac
done

if [[ ${#targets[@]} -eq 0 ]]; then
	if [[ "$mode" == list ]]; then
		targets=("${all_targets[@]}")
	else
		targets=("${default_targets[@]}")
	fi
fi

available() { command -v "$1" >/dev/null 2>&1; }

# bun pm cache rm clears the global cache but refuses to run without a package.json,
# so Bun's cleanup runs from a temporary empty package instead of the caller's directory.
scratch_package=
trap 'if [[ -n "$scratch_package" ]]; then rm -rf "$scratch_package"; fi' EXIT
# Sets scratch_package in this shell (not via command substitution) so the EXIT trap can remove it.
ensure_scratch_package() {
	if [[ -z "$scratch_package" ]]; then
		scratch_package=$(mktemp -d "${TMPDIR:-/tmp}/cache-clean.XXXXXX") || return 1
		printf '{}\n' > "$scratch_package/package.json" || return 1
	fi
}

# Sets an argument array, never an eval-able command string.
prepare_command() {
	local target="$1" yarn_version
	cleanup_command=()
	cleanup_in_scratch_package=false
	skip_reason="$target is not installed or not on PATH"
	if [[ "$target" == pip ]]; then
		if available pip; then
			cleanup_command=(pip cache purge)
		elif available pip3; then
			cleanup_command=(pip3 cache purge)
		else
			skip_reason='neither pip nor pip3 is on PATH'
			return 1
		fi
		return 0
	fi
	available "$target" || return 1
	case "$target" in
	uv) cleanup_command=(uv cache clean) ;;
	bun) cleanup_command=(bun pm cache rm); cleanup_in_scratch_package=true ;;
	npm) cleanup_command=(npm cache clean --force) ;;
	pnpm) cleanup_command=(pnpm store prune) ;;
	yarn)
		if ! yarn_version=$(yarn --version); then
			skip_reason='could not determine Yarn version'
			return 1
		fi
		case "$yarn_version" in
		0.* | 1.*) cleanup_command=(yarn cache clean) ;;
		[2-9].* | [1-9][0-9].*) cleanup_command=(yarn cache clean --mirror) ;;
		*) skip_reason="unrecognized Yarn version: $yarn_version"; return 1 ;;
		esac
		;;
	cargo)
		# cargo clean clears project builds, not the shared registry/git cache.
		if ! available cargo-cache; then
			skip_reason='requires cargo-cache; install with: cargo install cargo-cache'
			return 1
		fi
		cleanup_command=(cargo cache --remove-dir all)
		;;
	go) cleanup_command=(go clean -cache -testcache -modcache -fuzzcache) ;;
	conda | mamba | micromamba)
		# --all includes extracted packages that environments may symlink to.
		cleanup_command=("$target" clean --tarballs --index-cache --yes)
		;;
	pixi) cleanup_command=(pixi clean cache --yes) ;;
	brew) cleanup_command=(brew cleanup --prune=all --scrub) ;;
	deno) cleanup_command=(deno clean) ;;
	mise) cleanup_command=(mise cache clear) ;;
	ccache) cleanup_command=(ccache --clear) ;;
	composer) cleanup_command=(composer --no-interaction --no-plugins --no-scripts clear-cache) ;;
	dotnet) cleanup_command=(dotnet nuget locals all --clear) ;;
	docker) cleanup_command=(docker builder prune --all --force) ;;
	esac
}

run_cleanup() {
	if [[ "$cleanup_in_scratch_package" == true ]]; then
		ensure_scratch_package || return 1
		(cd "$scratch_package" && "${cleanup_command[@]}")
	else
		"${cleanup_command[@]}"
	fi
}

completed=0
skipped=0
failed=0
for target in "${targets[@]}"; do
	if ! prepare_command "$target"; then
		printf '[skip] %s: %s\n' "$target" "$skip_reason"
		skipped=$((skipped + 1))
		continue
	fi
	case "$mode" in
	run) printf '\n[clean] %s:' "$target" ;;
	preview) printf '[dry-run] %s:' "$target" ;;
	list) printf '[available] %s:' "$target" ;;
	esac
	printf ' %q' "${cleanup_command[@]}"
	if [[ "$target" == docker ]]; then printf ' (explicit target only)'; fi
	if [[ "$cleanup_in_scratch_package" == true ]]; then printf ' (from a temporary empty package)'; fi
	printf '\n'
	if [[ "$mode" != run ]]; then
		completed=$((completed + 1))
		continue
	fi
	if run_cleanup; then
		completed=$((completed + 1))
	else
		result=$?
		# An interrupted cleanup should not start deleting the next cache.
		if [[ "$result" -eq 130 || "$result" -eq 143 ]]; then exit "$result"; fi
		printf '[failed] %s exited with status %s\n' "$target" "$result" >&2
		failed=$((failed + 1))
	fi
done

if [[ "$mode" == run ]]; then
	printf '\nCache cleanup: %s succeeded, %s skipped, %s failed.\n' "$completed" "$skipped" "$failed"
else
	printf '\n%s available, %s skipped. No cleanup commands were run.\n' "$completed" "$skipped"
fi
[[ "$failed" -eq 0 ]]
