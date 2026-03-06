# Zide

A modern IDE for Zig development, built in Zig.

![License](https://img.shields.io/badge/license-MIT-blue.svg)

## About the App

Zide is an IDE built in Zig to the furthest extent possible that makes sense for our goals. The goal is a modern IDE built for revamped workspace and micro-service development. One practical driver: opening many microservices in a single workspace (e.g., 8 Java LSPs) can consume ~16GB RAM and slow everything down.

We design every piece with embedded-style resource constraints in mind. That means aggressive caching, smart lifecycle management for tooling (e.g., spin up LSPs, cache results, hot-reload only edited blocks/references, then shut them down), and a strong focus on raw responsiveness and performance.

## Quick Start

```bash
# Install system dependencies (see app_architecture/BOOTSTRAP.md for other distros)
# Arch Linux:
sudo pacman -S zig sdl3 freetype2 harfbuzz lua wayland wayland-protocols libxkbcommon mesa

# Bootstrap and build
./scripts/bootstrap.sh
zig build run
```

## Features

- Native Wayland support (Hyprland, Sway, etc.)
- Integrated terminal panel (PTY + VT core with scrollback; rendering polish ongoing)
- Tree-sitter syntax highlighting (dynamic grammar packs)
- Rope text buffer with undo/redo
- Low CPU usage when idle (<1%)
- Cross-platform roadmap (Linux first; macOS/Windows planned)

## Documentation

See [app_architecture/BOOTSTRAP.md](app_architecture/BOOTSTRAP.md) for:
- Full installation instructions
- Architecture overview
- Keyboard shortcuts
- Configuration options

Terminal compatibility and terminfo:
- `docs/terminal/compatibility.md`
- this is the current beta terminal support surface
- Install the bundled terminal entry for best app detection:

```bash
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

Open a new terminal inside Zide and verify:

```bash
printf '%s\n' "$TERM"
```

Expected value is `xterm-zide` (preferred), with `zide-256color` as an alternate identity when applicable.

UI renderer roadmap:
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`

Tree-sitter grammar packs:
```bash
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```
Overrides:
- `~/.config/zide/syntax.lua` (user)
- `.zide/syntax.lua` (project)

## Linux Dev Channels

For local Linux testing, you can install two launcher channels:

- `zide-stable` (release build + color icon)
- `zide-test` (dev build + gray icon)

Commands:

```bash
scripts/dev/deploy_linux_channel.sh stable
scripts/dev/deploy_linux_channel.sh test

# or both
scripts/dev/deploy_linux_channels.sh
```

This is a dev tool workflow (local installs under `~/.local`), not release packaging.

## Dependencies

- Zig package-managed in normal flow: SDL3, Lua, tree-sitter core runtime.
- Zig package-managed in normal flow: FreeType/HarfBuzz (non-vcpkg paths).
- Bundled third-party source: `stb_image` C source in-tree.
- System/runtime package details: see `app_architecture/BOOTSTRAP.md` and `docs/DEPENDENCIES.md`.

## License

MIT
