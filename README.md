<h1><img src="assets/icon/color_icon.png" alt="Z" width="44" align="absmiddle" />ide</h1>

Zide is a Zig-first terminal and IDE stack focused on performance, low idle
cost, and explicit runtime ownership.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/LaurenceGuws/Zide?include_prereleases&label=release)](https://github.com/LaurenceGuws/Zide/releases)
[![Zig](https://img.shields.io/badge/zig-0.15.2-f7a41d)](https://ziglang.org/download/)

## Current Product Focus

The active product focus is Android terminal excellence.

Current implementation direction:

- terminal-first on Android
- strong shared Zig core
- native host behavior where platform UX requires it
- no compatibility shims or stale fallback paths by default

## Quick Start

Use the build/bootstrap authority doc:

- [app_architecture/BOOTSTRAP.md](app_architecture/BOOTSTRAP.md)

Typical local flow:

```bash
./ops/bootstrap.sh
zig build
zig build run
```

## Android Terminal Host

Android host tooling is owned by:

- [ops/android_terminal_host.py](ops/android_terminal_host.py)

Help:

```bash
./ops/android_terminal_host.py -h
```

Common flow:

```bash
./ops/android_terminal_host.py deploy
./ops/android_terminal_host.py logcat
```

## Documentation

Primary entrypoints:

- [docs/INDEX.md](docs/INDEX.md)
- [docs/AGENT_HANDOFF.md](docs/AGENT_HANDOFF.md)
- [docs/todo/android/implementation.md](docs/todo/android/implementation.md)
- [app_architecture/platform/android/RENDER_BACKEND.md](app_architecture/platform/android/RENDER_BACKEND.md)
- [app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md](app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md)

External docs explorer/tooling repos:

- <https://github.com/LaurenceGuws/docs-explorer>
- <https://github.com/LaurenceGuws/zlua-portable>
- <https://github.com/LaurenceGuws/zbar>

## Releases

- [GitHub Releases](https://github.com/LaurenceGuws/Zide/releases)

## License

MIT
