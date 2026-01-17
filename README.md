# Zide

A modern IDE for Zig development, built in Zig.

![License](https://img.shields.io/badge/license-MIT-blue.svg)

## Quick Start

```bash
# Install system dependencies (see docs/BOOTSTRAP.md for other distros)
# Arch Linux:
sudo pacman -S zig freetype2 harfbuzz wayland wayland-protocols libxkbcommon mesa

# Bootstrap and build
make bootstrap
zig build run
```

## Features

- Native Wayland support (Hyprland, Sway, etc.)
- Integrated terminal panel (backend in progress)
- Tree-sitter syntax highlighting
- Piece-table text buffer with undo/redo
- Low CPU usage when idle (<1%)

## Documentation

See [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) for:
- Full installation instructions
- Architecture overview
- Keyboard shortcuts
- Configuration options

## Dependencies

- Vendored: raylib, tree-sitter (runtime + Zig parser).
- System deps: see `docs/BOOTSTRAP.md` for platform packages (freetype, harfbuzz, lua, Wayland/X11, etc.).

## License

MIT
