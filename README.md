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
sudo pacman -S zig freetype2 harfbuzz wayland wayland-protocols libxkbcommon mesa

# Bootstrap and build
make bootstrap
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

UI renderer roadmap:
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`

Tree-sitter grammar packs:
```bash
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```
Overrides:
- `~/.config/zide/syntax.lua` (user)
- `.zide/syntax.lua` (project)

## Dependencies

- Vendored: raylib, tree-sitter (runtime + Zig parser).
- System deps: see `app_architecture/BOOTSTRAP.md` for platform packages (freetype, harfbuzz, lua, Wayland/X11, etc.).

## License

MIT
