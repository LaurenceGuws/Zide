<h1><img src="assets/icon/color_icon.png" alt="Z" width="44" align="absmiddle" />ide</h1>

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/LaurenceGuws/Zide?include_prereleases&label=release)](https://github.com/LaurenceGuws/Zide/releases)
[![Zig](https://img.shields.io/badge/zig-0.15.2-f7a41d)](https://ziglang.org/download/)

Zide is a terminal emulator and IDE built on a pure Zig engine core, with
first-class native implementations on each platform it targets.

## Why

Most cross-platform terminal emulators share a core problem: they abstract
over the platform to run everywhere, and in doing so they compromise the
platform. The result is acceptable everywhere and excellent nowhere.

Zide takes the opposite approach. The Zig engine core — terminal processing,
renderer backend contract, editor runtime — is the shared product. It is not
shaped by any single platform. Native implementations are not ports or
compatibility layers; they are the engine deployed at its full capability for
that environment, using the platform's own idioms and constraints as design
input.

The goal is to be the best terminal on every platform Zide runs on.

## Platforms

| Platform | Status |
|---|---|
| Linux | Active |
| Windows | Active |
| macOS | Active |
| Android | Active — native rendering in progress |

These are the current targets. The architecture is designed to take on new
native targets without core surgery. More platforms will follow.

## Architecture

```
  ┌────────────────────────────────────────────────────┐
  │                     Zig core                       │
  │   terminal engine · renderer backend contract      │
  │           editor runtime · config                  │
  └──────┬──────────────┬──────────────┬───────────────┘
         │              │              │
  ┌──────┴─────┐  ┌─────┴──────┐  ┌───┴──────────┐
  │   Linux    │  │  Windows   │  │    macOS     │  ···
  │   OpenGL   │  │  native    │  │    Metal     │
  └────────────┘  └────────────┘  └──────────────┘
                                  ┌──────────────┐
                                  │   Android    │
                                  │  GLES / JNI  │
                                  └──────────────┘
```

**The core is not platform-neutral in the sense of lowest-common-denominator.**
It is platform-neutral in the sense that no single platform gets to shape it.
When platforms need different behavior, the difference lives in the native
layer.

The renderer backend contract is intentionally open-ended — it adapts to proved
real-world truth on each platform rather than locking in speculative
abstractions. OpenGL and Metal are the current reference implementations.
Android GLES is next.

## Principles

- No fallbacks in core for platform weaknesses — handle them in the native
  layer or do not handle them
- No stale code or doc blocks at any layer
- No reinventing what the platform already provides cleanly
- Pure architecture is not negotiable for delivery speed
- Each native implementation aims to be the most competitive version of Zide
  possible in its environment

## Quick Start

See [app_architecture/BOOTSTRAP.md](app_architecture/BOOTSTRAP.md) for full
dependency and build setup.

```bash
./ops/bootstrap.sh
zig build
zig build run
```

## Android

Android host tooling is in `ops/android_terminal_host.py`.

```bash
./ops/android_terminal_host.py deploy   # build, install, launch
./ops/android_terminal_host.py logcat   # filtered device logs
./ops/android_terminal_host.py -h       # full command reference
```

## Documentation

- [docs/INDEX.md](docs/INDEX.md) — full doc map
- [docs/AGENT_HANDOFF.md](docs/AGENT_HANDOFF.md) — current focus and execution state
- [app_architecture/ENGINEERING.md](app_architecture/ENGINEERING.md) — product identity and engineering principles

External:

- <https://github.com/LaurenceGuws/docs-explorer>
- <https://github.com/LaurenceGuws/zlua-portable>
- <https://github.com/LaurenceGuws/zbar>

## Releases

[GitHub Releases](https://github.com/LaurenceGuws/Zide/releases)

## License

MIT
