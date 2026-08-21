# Benchmarks

## Package Manager choice

There is no single best package manager for every machine. The main trade-offs for
these dotfiles are compatibility, administrator access, package operation speed,
and per-command startup overhead.

| Manager | Platforms | Linux administrator access | Command invocation | Main trade-off |
| --- | --- | --- | --- | --- |
| Homebrew | macOS, Linux | Its default Linux prefix setup may need administrator access, so it cannot be used on every machine. | Installed programs run directly. | Best compatibility on macOS, including formulae, casks, and taps, but package-manager operations are relatively slow. |
| Zerobrew | macOS, Linux | Its default Linux installation is user-local and does not normally need administrator access. | Installed programs run directly. | Designed for faster package operations, but it is experimental and not fully compatible with every Homebrew bottle. |
| Pixi | macOS, Linux, Windows | No | A global command normally runs through a small trampoline. | Good cross-platform, sudo-free package installation, but the trampoline adds startup overhead, especially on Windows. |
| Mise | macOS, Linux, Windows | No | `mise activate` exposes the installed binary directly; optional shims invoke Mise first. | Direct PATH activation is fast, but Mise shims had considerably more overhead than Pixi trampolines. |

Homebrew remains the safest default on macOS. On Linux, Zerobrew is attractive for
machines without administrator access, but its use of Homebrew bottles introduces
a compatibility risk: bottles may contain paths for Homebrew's
`/home/linuxbrew/.linuxbrew` prefix. Zerobrew attempts to relocate them into its
user-local prefix, but embedded library or resource paths are not always rewritten.
In the Linux smoke test, 41 of 45 formulae passed, one was partially linked, and
three installed but failed their runtime checks.

The tested Pixi and Mise ripgrep installations avoid that Homebrew-prefix
compatibility problem. Pixi global tools use cached trampolines. In this test,
running the trampoline did not start the dependency solver or walk the Conda
environment metadata, but it still had a measurable cost. Mise has no per-command
wrapper when normal shell activation puts the installed binary on `PATH`; it pays
a separate prompt-refresh cost that was not included here. Its optional shims were
slower than Pixi on both tested operating systems.

A Mise-managed tool directory can also be added to `PATH` manually, just like a
Homebrew prefix. That is fast and reasonable for a fixed global tool version, but
Mise install paths are versioned and backend-specific, so a static entry can become
stale after an upgrade and cannot follow per-project version selection. Normal
`mise activate` automates the same direct-`PATH` approach whenever the prompt or
working directory changes; shims are not required for interactive global usage.

### Ripgrep startup benchmark

Measured on 2026-08-18 with ripgrep 15.2.0. Startup is
`rg --no-config --version`; search is a warm-cache search over a deterministic
1 MiB file. Each benchmark used one persistent session, a pinned CPU, 100 warmups,
and balanced command ordering.

| OS | Invocation | Startup median | Cached 1 MiB search median |
| --- | --- | ---: | ---: |
| Linux | Mise-managed binary (direct path) | 1.107 ms | 3.117 ms |
| Linux | Zerobrew | 1.685 ms | 3.953 ms |
| Linux | Pixi global trampoline | 1.875 ms | 4.009 ms |
| Linux | Mise shim | 13.926 ms | 15.982 ms |
| Windows | Mise-managed binary (direct path) | 8.850 ms | 13.064 ms |
| Windows | Winget | 10.213 ms | 14.514 ms |
| Windows | Pixi global trampoline | 17.140 ms | 22.459 ms |
| Windows | Mise shim | 65.731 ms | 72.273 ms |

Normal `mise activate` ultimately places the same Mise-managed binary on `PATH`.
The cleanest package-manager overhead comparison is the paired mean difference
between each launcher and its own underlying ripgrep binary. The behavior is
described in the [Pixi trampoline documentation](https://pixi.sh/latest/global_tools/trampolines/)
and the [Mise shim performance documentation](https://mise.jdx.dev/dev-tools/shims.html#performance);
the exact timings below are measurements from these tests.

| Launcher | Linux paired mean startup overhead | Linux paired mean search overhead | Windows paired mean startup overhead | Windows paired mean search overhead |
| --- | ---: | ---: | ---: | ---: |
| Pixi global trampoline | +0.374 ms | +0.366 ms | +7.102 ms | +8.389 ms |
| Mise shim | +13.384 ms | +13.388 ms | +57.361 ms | +59.583 ms |

The absolute Linux results include differences between ripgrep builds, so they are
not purely package-manager effects. On Windows, the Mise-managed binary and Winget
target were byte-identical. Winget is included only as a native Windows baseline
because Homebrew and Zerobrew do not run natively on Windows. The launcher-overhead
table is therefore more useful than small differences between direct binaries.

The timings above measure installed command execution, not package installation or
update speed. Homebrew and Zerobrew do not add a wrapper when launching `rg`;
Homebrew's speed disadvantage is in package-manager operations.

### Conclusion

Pixi is a last resort, not a default. It is used only on Linux machines where a
tool cannot reasonably be installed any other way: no administrator access, no
official static binary, no cargo/mise route, and a source build that would need
cmake plus system development headers (e.g. poppler for `pdftoppm`). On Windows
it is avoided entirely — the trampoline added +7.102 ms startup overhead per
invocation in these tests. Even on Linux it is avoided for speed-sensitive or
frequently invoked tools (ripgrep, fd, eza and similar): those are installed
with cargo-binstall, official static binaries, or bun instead, because Pixi's
+0.374 ms trampoline startup overhead (Linux, table above) is paid on every
single invocation.

### References

- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux)
- [Zerobrew project status and relationship with Homebrew](https://github.com/lucasgelfond/zerobrew#relationship-with-homebrew)
- [Zerobrew Linux prefix compatibility example](https://github.com/lucasgelfond/zerobrew/issues/159)
- [Pixi global-tool trampolines](https://pixi.sh/latest/global_tools/trampolines/)
- [Mise shims and PATH activation](https://mise.jdx.dev/dev-tools/shims.html)
- [Mise native Windows shim implementation](https://github.com/jdx/mise/blob/main/crates/mise-shim/src/main.rs)
