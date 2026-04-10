# /// script
# requires-python = ">=3.9"
# ///

# ruff: noqa: T201

# Usage: uv run scripts/archive_code.py <directory>
# Example: uv run scripts/archive_code.py updater
# Example: uv run scripts/archive_code.py stub_launcher
#
# Outputs all tracked (non-gitignored) text files in the given directory to
# stdout in a format suitable for pasting into ChatGPT for code review.
# Binary files are skipped. Run from the repo root.

import subprocess
import sys
from pathlib import Path

SKIP_NAMES = {".gitignore", "uv.lock"}

BINARY_SUFFIXES = {
    ".zst",
    ".tar",
    ".gz",
    ".bz2",
    ".xz",
    ".zip",
    ".7z",
    ".pyc",
    ".pyo",
    ".so",
    ".dylib",
    ".dll",
    ".exe",
    ".bin",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".bmp",
    ".ico",
    ".svg",
    ".pdf",
    ".woff",
    ".woff2",
    ".ttf",
    ".otf",
    ".db",
    ".sqlite",
    ".sqlite3",
}


def is_binary(path: Path) -> bool:
    if path.suffix.lower() in BINARY_SUFFIXES:
        return True
    try:
        path.read_text(encoding="utf-8")
        return False
    except (UnicodeDecodeError, PermissionError):
        return True


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: uv run scripts/archive_code.py <directory>", file=sys.stderr)
        print("Example: uv run scripts/archive_code.py updater", file=sys.stderr)
        sys.exit(1)

    target = Path(sys.argv[1])
    if not target.is_dir():
        print(f"Error: '{target}' is not a directory.", file=sys.stderr)
        sys.exit(1)

    # Use git ls-files to list only tracked/unignored files respecting .gitignore.
    # If the target is outside the current repo (or in a different repo), run git
    # from within the target directory so that git can resolve it correctly.
    target_abs = target.resolve()
    try:
        result = subprocess.run(
            [
                "git",
                "ls-files",
                "--cached",
                "--others",
                "--exclude-standard",
                str(target),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        # Paths are relative to cwd; keep them as-is.
        files = sorted(result.stdout.splitlines())
        file_paths = [Path(p) for p in files]
    except subprocess.CalledProcessError:
        # Fallback: run git ls-files from inside the target directory and resolve
        # the returned paths back to absolute so we can read them regardless of cwd.
        result = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            capture_output=True,
            text=True,
            check=True,
            cwd=target_abs,
        )
        files = sorted(result.stdout.splitlines())
        file_paths = [target_abs / p for p in files]

    skipped: list[str] = []
    for rel_path, path in zip(files, file_paths):
        if not path.is_file():
            continue
        if path.name in SKIP_NAMES:
            continue
        if is_binary(path):
            skipped.append(rel_path)
            continue
        content = path.read_text(encoding="utf-8")
        print(f"=== {rel_path} ===")
        print(content)

    if skipped:
        print("=== SKIPPED BINARY FILES ===", file=sys.stderr)
        for s in skipped:
            print(f"  {s}", file=sys.stderr)


if __name__ == "__main__":
    main()
