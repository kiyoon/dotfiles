# /// script
# requires-python = ">=3.10"
# dependencies = ["cyclopts>=4.0.0"]
# ///

"""
webpify.py — batch convert images to WebP using `cwebp` (libwebp), with optional target-size fallback.

Prereq:
  - `cwebp` must be installed and on PATH.
    - macOS: brew install webp
    - Ubuntu/Debian: sudo apt-get install webp

Examples (uv run):

  # Convert PNGs to WebP into out/ (lossy, default q=82)
  uv run webpify.py convert -o out *.png

  # Lossless WebP
  uv run webpify.py convert -o out --lossless *.png

  # Near-lossless (great for text/UI screenshots): 0..100 (higher = closer to lossless)
  uv run webpify.py convert -o out --near-lossless 80 *.png

  # Target size (MB): try chosen mode first; if too big, auto fall back and step quality down
  uv run webpify.py convert -o out --target-mb 4.9 --quality 90 --min-quality 45 --quality-step 5 *.png

  # Start lossless but enforce target: lossless -> (if needed) near-lossless -> lossy q step-down
  uv run webpify.py convert -o out --lossless --target-mb 4.9 *.png

  # Folder recursively + keep tree
  uv run webpify.py convert -o out --keep-tree --base-dir shots shots/
"""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from cyclopts import App

app = App("webpify-cwebp")

IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}


@dataclass(frozen=True)
class Options:
    out: Path
    keep_tree: bool = False
    base_dir: Path | None = None

    # encoding strategy
    lossless: bool = False
    near_lossless: int | None = None  # 0..100
    quality: int = 82  # 0..100 (lossy)
    method: int = 6  # 0..6

    # alpha handling (screenshots sometimes have alpha)
    alpha_quality: int = 100  # 0..100

    # metadata
    keep_metadata: bool = False  # if False, strip all metadata

    # target size fallback
    target_mb: float | None = None
    min_quality: int = 40
    quality_step: int = 5


def _check_cwebp() -> None:
    if shutil.which("cwebp") is None:
        raise SystemExit(
            "ERROR: `cwebp` not found on PATH. Install it first:\n"
            "  macOS: brew install webp\n"
            "  Ubuntu/Debian: sudo apt-get install webp"
        )


def _expand_inputs(inputs: tuple[Path, ...]) -> list[Path]:
    out: list[Path] = []
    for p in inputs:
        s = str(p)
        if any(ch in s for ch in ("*", "?", "[")):  # glob
            out.extend(sorted(Path().glob(s)))
        elif p.is_dir():
            out.extend(
                sorted(
                    [
                        x
                        for x in p.rglob("*")
                        if x.is_file() and x.suffix.lower() in IMG_EXTS
                    ]
                )
            )
        else:
            out.append(p)

    seen: set[Path] = set()
    uniq: list[Path] = []
    for x in out:
        try:
            rp = x.resolve()
        except Exception:
            rp = x
        if rp not in seen:
            seen.add(rp)
            uniq.append(x)
    return uniq


def _out_path(inp: Path, opt: Options) -> Path:
    if opt.keep_tree:
        base = opt.base_dir or Path.cwd()
        try:
            rel = inp.resolve().relative_to(base.resolve())
        except Exception:
            rel = Path(inp.name)
        dst = (opt.out / rel).with_suffix(".webp")
        dst.parent.mkdir(parents=True, exist_ok=True)
        return dst

    opt.out.mkdir(parents=True, exist_ok=True)
    return (opt.out / inp.name).with_suffix(".webp")


def _target_bytes(opt: Options) -> int | None:
    if opt.target_mb is None or opt.target_mb <= 0:
        return None
    return int(opt.target_mb * 1024 * 1024)


def _filesize(p: Path) -> int:
    try:
        return p.stat().st_size
    except FileNotFoundError:
        return 0


def _run_cwebp(inp: Path, outp: Path, args: list[str]) -> None:
    # -quiet reduces noise; still fails with non-zero exit code
    cmd = ["cwebp", "-quiet", str(inp), "-o", str(outp), *args]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        msg = (r.stderr or r.stdout or "").strip()
        raise RuntimeError(msg or f"cwebp failed (code {r.returncode})")


def _common_args(opt: Options) -> list[str]:
    args: list[str] = [
        "-m",
        str(max(0, min(6, int(opt.method)))),
        "-alpha_q",
        str(max(0, min(100, int(opt.alpha_quality)))),
    ]

    if opt.keep_metadata:
        # keep everything
        args += ["-metadata", "all"]
    else:
        # strip everything (default is none, but explicit is clearer)
        args += ["-metadata", "none"]

    return args


def _encode_once(
    inp: Path, tmp: Path, *, mode: str, q: int | None, opt: Options
) -> None:
    """
    mode:
      - "lossless"
      - "near_lossless"
      - "lossy"
    """
    args = _common_args(opt)

    if mode == "lossless":
        args += ["-lossless"]
        # NOTE: cwebp lossless ignores -q for color, but can affect alpha in some builds; keep simple.
    elif mode == "near_lossless":
        nl = opt.near_lossless if opt.near_lossless is not None else 80
        nl = max(0, min(100, int(nl)))
        # near-lossless is used with -q and -near_lossless
        # We'll set -q to 100 for stability unless caller provides q
        args += [
            "-near_lossless",
            str(nl),
            "-q",
            str(max(0, min(100, int(q if q is not None else 100)))),
        ]
    elif mode == "lossy":
        qq = max(0, min(100, int(q if q is not None else opt.quality)))
        args += ["-q", str(qq)]
    else:
        raise ValueError(mode)

    _run_cwebp(inp, tmp, args)


def _encode_with_target(inp: Path, tmp: Path, opt: Options) -> tuple[bool, str]:
    """
    Strategy when target_mb is set:
      1) try requested mode:
         - if opt.lossless: lossless
         - elif opt.near_lossless is not None: near_lossless
         - else: lossy(q=opt.quality)
      2) if too big:
         - if started lossless: try near_lossless (if not set, default 80)
         - then lossy: step quality down until target met or min_quality reached
    """
    target = _target_bytes(opt)
    if target is None:
        # no target: just one encode in requested mode
        if opt.lossless:
            _encode_once(inp, tmp, mode="lossless", q=None, opt=opt)
            sz = _filesize(tmp)
            return True, f"lossless ({sz / 1024 / 1024:.2f}MB)"
        if opt.near_lossless is not None:
            _encode_once(inp, tmp, mode="near_lossless", q=100, opt=opt)
            sz = _filesize(tmp)
            return True, f"near-lossless {opt.near_lossless} ({sz / 1024 / 1024:.2f}MB)"
        _encode_once(inp, tmp, mode="lossy", q=opt.quality, opt=opt)
        sz = _filesize(tmp)
        return True, f"lossy q={opt.quality} ({sz / 1024 / 1024:.2f}MB)"

    # 1) requested mode first
    if opt.lossless:
        _encode_once(inp, tmp, mode="lossless", q=None, opt=opt)
        sz = _filesize(tmp)
        if sz <= target:
            return (
                True,
                f"ok lossless ({sz / 1024 / 1024:.2f}MB <= {opt.target_mb:.2f}MB)",
            )

        # 2) try near-lossless next (use provided value or default 80)
        _encode_once(inp, tmp, mode="near_lossless", q=100, opt=opt)
        sz = _filesize(tmp)
        if sz <= target:
            nl = opt.near_lossless if opt.near_lossless is not None else 80
            return True, f"ok near-lossless {nl} ({sz / 1024 / 1024:.2f}MB)"

        # then fall through to lossy stepping
        start_q = min(100, max(0, int(opt.quality)))
    elif opt.near_lossless is not None:
        _encode_once(inp, tmp, mode="near_lossless", q=100, opt=opt)
        sz = _filesize(tmp)
        if sz <= target:
            return (
                True,
                f"ok near-lossless {opt.near_lossless} ({sz / 1024 / 1024:.2f}MB)",
            )
        start_q = min(100, max(0, int(opt.quality)))
    else:
        _encode_once(inp, tmp, mode="lossy", q=opt.quality, opt=opt)
        sz = _filesize(tmp)
        if sz <= target:
            return True, f"ok lossy q={opt.quality} ({sz / 1024 / 1024:.2f}MB)"
        start_q = min(100, max(0, int(opt.quality)))

    # 3) lossy quality step-down
    step = max(1, int(opt.quality_step))
    min_q = max(0, min(100, int(opt.min_quality)))

    q = start_q
    last_sz = _filesize(tmp)

    while q > min_q:
        q = max(min_q, q - step)
        _encode_once(inp, tmp, mode="lossy", q=q, opt=opt)
        last_sz = _filesize(tmp)
        if last_sz <= target:
            return (
                True,
                f"ok lossy q={q} ({last_sz / 1024 / 1024:.2f}MB <= {opt.target_mb:.2f}MB)",
            )

    return (
        False,
        f"miss target; last lossy q={q}, size={last_sz / 1024 / 1024:.2f}MB > {opt.target_mb:.2f}MB",
    )


@app.command
def convert(
    inputs: tuple[Path, ...],
    *,
    out: Path,
    lossless: bool = False,
    near_lossless: int | None = None,
    quality: int = 82,
    method: int = 6,
    alpha_quality: int = 100,
    keep_metadata: bool = False,
    target_mb: float | None = None,
    min_quality: int = 40,
    quality_step: int = 5,
    keep_tree: bool = False,
    base_dir: Path | None = None,
) -> None:
    """
    Convert images to .webp into an output directory.

    inputs: file paths, directories, or glob patterns (e.g. "*.png", "shots/").
    """
    _check_cwebp()

    opt = Options(
        out=out,
        keep_tree=keep_tree,
        base_dir=base_dir,
        lossless=lossless,
        near_lossless=near_lossless,
        quality=quality,
        method=method,
        alpha_quality=alpha_quality,
        keep_metadata=keep_metadata,
        target_mb=target_mb,
        min_quality=min_quality,
        quality_step=quality_step,
    )

    files = _expand_inputs(inputs)
    if not files:
        raise SystemExit("No input files matched.")

    converted = 0
    target_miss = 0

    for inp in files:
        if inp.is_dir():
            continue
        dst = _out_path(inp, opt)
        tmp = dst.with_suffix(dst.suffix + ".tmp")
        try:
            met, note = _encode_with_target(inp, tmp, opt)
            tmp.replace(dst)
            print(f"{inp} -> {dst} [{note}]")
            converted += 1
            if opt.target_mb is not None and not met:
                target_miss += 1
        except Exception as e:
            try:
                tmp.unlink(missing_ok=True)
            except Exception:
                pass
            print(f"ERROR: {inp} ({e})")

    print(f"\nDone. Converted={converted}, TargetMiss={target_miss}")
    if opt.target_mb is not None and target_miss:
        raise SystemExit(1)


if __name__ == "__main__":
    app()
