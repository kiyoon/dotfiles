#!/usr/bin/env bash
# gdust — dust, but scoped to git content instead of the working directory.
#
#   gdust                 whole tree as git sees it (the index)
#   gdust --staged        only what's staged for the next commit (green)
#   gdust --dirty         unstaged edits + untracked files (red)
#   gdust --head          what's already committed at HEAD
#   gdust -d 3 -r -z 10k  any dust flag passes straight through
#
# Builds a throwaway skeleton of sparse files at each file's real size and runs
# dust on it, so gitignored junk (.git, target/, .godot/, DVC cache) never shows
# up. Sizes come from git blobs for --staged/--head/index, and from disk for
# --dirty (untracked files have no blob yet).

set -euo pipefail

mode=index
dust_args=()
for a in "$@"; do
	case "$a" in
	--staged | --cached) mode=staged ;;
	--dirty | --red | --unstaged) mode=dirty ;;
	--head | --HEAD) mode=head ;;
	*) dust_args+=("$a") ;;
	esac
done

if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
	echo "gdust: not inside a git repository" >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Each branch emits "<bytes> <path>" lines.
emit_sizes() {
	case "$mode" in
	staged)
		git -C "$root" diff --cached --raw --abbrev=40 |
			awk -F'\t' '{split($1,a," "); if (a[5] !~ /^D/) print a[4]" "$2}' |
			git -C "$root" cat-file --batch-check='%(objectsize) %(rest)'
		;;
	dirty)
		# Worktree edits not yet staged, plus untracked-but-not-ignored files.
		# lstat so a symlink reports its own size, not its target's.
		cd "$root" && {
			git diff --name-only -z --diff-filter=ACMR
			git ls-files --others --exclude-standard -z
		} | perl -0 -ne '
			chomp;
			next unless length;
			my $s = (lstat($_))[7];
			next unless defined $s;
			print "$s $_\n";
		'
		;;
	head)
		git -C "$root" ls-tree -r -z HEAD |
			tr '\0' '\n' |
			awk -F'\t' '{split($1,a," "); print a[3]" "$2}' |
			git -C "$root" cat-file --batch-check='%(objectsize) %(rest)'
		;;
	*)
		git -C "$root" ls-files -s |
			awk -F'\t' '{split($1,a," "); print a[2]" "$2}' |
			git -C "$root" cat-file --batch-check='%(objectsize) %(rest)'
		;;
	esac
}

emit_sizes | TMP="$tmp" perl -MFile::Path=make_path -ne '
	chomp;
	my ($size, $path) = split(/ /, $_, 2);
	next unless defined $path && length $path;
	my $f = "$ENV{TMP}/$path";
	(my $d = $f) =~ s{/[^/]*$}{};
	make_path($d);
	open(my $fh, ">", $f) or next;
	truncate($fh, $size);
	close $fh;
'

if [ -z "$(ls -A "$tmp")" ]; then
	echo "gdust: nothing to show (no files for mode '$mode')" >&2
	exit 0
fi

cd "$tmp" && dust -s "${dust_args[@]+"${dust_args[@]}"}" .
