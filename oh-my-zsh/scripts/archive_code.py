# /// script
# requires-python = ">=3.9"
# ///

# ruff: noqa: T201

# Usage: archive-code <directory> [--include-known]
# Example: archive-code updater
# Example: archive-code ~/project/wezterm-gureum/godot-ghostty --include-known
#
# Outputs all tracked (non-gitignored) text files in the given directory to
# stdout in a format suitable for pasting into an LLM for code review.
# Binary files are skipped. Paths in the `=== path ===` headers are always
# relative to <directory>, regardless of where you run this from.
#
# --include-known narrows the output to a known filename/extension allowlist
# (TS/JS, Python, Rust, C#, C/C++/Objective-C, Godot/GDScript, shell, docs and
# the usual config files) so that asset-heavy repos stay paste-sized.
#
# Keep in sync with agent-watcher's copy, which is the canonical one:
#   ~/project/agent-watcher/src/agent_watcher/helpers/archive_code.py
# (that one returns a pydantic model; this one is standalone so `uv run` needs
# no dependencies.)

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass, field
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

KNOWN_INCLUDE_FILENAMES = {
    "package.json",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "tsconfig.json",
    "tsconfig.base.json",
    "vite.config.ts",
    "vitest.config.ts",
    "webpack.config.js",
    "webpack.config.ts",
    "next.config.js",
    "next.config.ts",
    "eslint.config.js",
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    "prettier.config.js",
    ".prettierrc",
    "requirements.txt",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "Pipfile",
    "poetry.lock",
    "Cargo.toml",
    "Cargo.lock",
    "rust-toolchain.toml",
    ".editorconfig",
    "README.md",
    "global.json",
    "NuGet.config",
    "Directory.Build.props",
    "Directory.Build.targets",
    ".sln",
    # C / C++ / Objective-C build entry points
    "CMakeLists.txt",
    "Makefile",
    "makefile",
    "GNUmakefile",
    "meson.build",
    # Godot
    "project.godot",
    "export_presets.cfg",
}

KNOWN_INCLUDE_EXTENSIONS = {
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
    ".json",
    ".md",
    ".yml",
    ".yaml",
    ".toml",
    ".py",
    ".pyi",
    ".rs",
    ".cs",
    ".csproj",
    ".props",
    ".targets",
    ".config",
    ".conf",
    ".sln",
    ".sh",
    # C / C++ / Objective-C
    ".c",
    ".h",
    ".cc",
    ".cpp",
    ".cxx",
    ".hh",
    ".hpp",
    ".hxx",
    ".m",
    ".mm",
    ".cmake",
    # Godot / GDScript
    ".gd",
    ".gdshader",
    ".gdshaderinc",
    ".gdextension",
    ".tscn",
    ".tres",
    ".escn",
    ".godot",
}


@dataclass
class ArchiveResult:
    stdout_text: str
    stderr_text: str
    skipped_files: list[str] = field(default_factory=list)


def is_binary(path: Path) -> bool:
    if path.suffix.lower() in BINARY_SUFFIXES:
        return True
    try:
        path.read_text(encoding="utf-8")
        return False
    except (UnicodeDecodeError, PermissionError):
        return True


def _list_files(target: Path) -> tuple[list[str], list[Path]]:
    """Return (rel_paths, abs_paths) for all files under target.

    rel_paths are always relative to target (never to the caller's CWD), so
    archive headers like ``=== foo.py ===`` are deterministic regardless of
    where the caller runs from.
    """
    target_abs = target.resolve()

    # Run git from target_abs so returned paths are relative to target.
    # This handles both "target is the repo root" and "target is a subdirectory"
    # uniformly, and works even when target is outside the caller's git repo.
    try:
        result = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            capture_output=True,
            text=True,
            check=True,
            cwd=target_abs,
        )
        files = sorted(result.stdout.splitlines())
        file_paths = [target_abs / p for p in files]
        return files, file_paths
    except subprocess.CalledProcessError:
        pass

    # Non-git fallback: plain recursive walk
    all_paths = sorted(p for p in target_abs.rglob("*") if p.is_file())
    files = [str(p.relative_to(target_abs)) for p in all_paths]
    return files, all_paths


def _has_shebang(path: Path) -> bool:
    """Whether path starts with ``#!``.

    Extensionless executables (``tools/termctl``, ``bin/build``) are real source
    but carry no suffix to match on, so the allowlist admits them by shebang.
    """
    try:
        with path.open("rb") as fh:
            return fh.read(2) == b"#!"
    except OSError:
        return False


def _allow_known(path: Path) -> bool:
    if path.name in KNOWN_INCLUDE_FILENAMES:
        return True
    suffix = path.suffix.lower()
    if suffix:
        return suffix in KNOWN_INCLUDE_EXTENSIONS
    # No suffix (or a bare dotfile like .envrc): only take it if it is a script.
    return _has_shebang(path)


def archive_directory(target: Path, include_known_only: bool = False) -> ArchiveResult:
    if not target.is_dir():
        raise ValueError(f"'{target}' is not a directory")

    files, file_paths = _list_files(target)
    out_chunks: list[str] = []
    skipped: list[str] = []

    for rel_path, path in zip(files, file_paths):
        if not path.is_file():
            continue
        if path.name in SKIP_NAMES:
            continue
        if include_known_only and not _allow_known(path):
            continue
        if is_binary(path):
            skipped.append(rel_path)
            continue
        content = path.read_text(encoding="utf-8")
        out_chunks.append(f"=== {rel_path} ===\n{content}")

    stderr = ""
    if skipped:
        stderr_lines = ["=== SKIPPED BINARY FILES ===", *[f"  {s}" for s in skipped]]
        stderr = "\n".join(stderr_lines)

    return ArchiveResult(
        stdout_text="\n".join(out_chunks), stderr_text=stderr, skipped_files=skipped
    )


def archive_main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Archive code into prompt-friendly text"
    )
    parser.add_argument("directory")
    parser.add_argument(
        "--include-known",
        action="store_true",
        help="Include only known filename and extension allowlist for TS/Python/React/Rust/C#/C/Godot projects",
    )
    args = parser.parse_args(argv)

    target = Path(args.directory)
    if not target.is_dir():
        print(f"Error: '{target}' is not a directory.", file=sys.stderr)
        return 1

    result = archive_directory(target, include_known_only=args.include_known)
    if result.stdout_text:
        print(result.stdout_text)
    if result.stderr_text:
        print(result.stderr_text, file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(archive_main())
