# Zide - Zig IDE

A modern, cross-platform IDE for Zig development, built entirely in Zig.

## Features

- **Text Editor**: Piece-table based text buffer with undo/redo
- **Syntax Highlighting**: Tree-sitter based, with Zig language support
- **Integrated Terminal**: libvterm-based terminal emulator with full color support
- **Native Wayland**: Wayland support in progress (Hyprland first; KDE planned)
- **Low CPU Usage**: Adaptive frame rate with intelligent idle detection
- **Cross-platform**: Linux (Wayland), macOS, and Windows support

## Layout (brief)

- `src/` core app code (editor, terminal, UI)
- `vendor/` third-party sources fetched by bootstrap
- `assets/` fonts and other resources
- `docs/` documentation

## System Dependencies

### Linux (Wayland)

```bash
# Arch Linux
sudo pacman -S zig freetype2 harfbuzz wayland wayland-protocols libxkbcommon mesa

# Ubuntu/Debian
sudo apt install zig libfreetype-dev libharfbuzz-dev libwayland-dev wayland-protocols libxkbcommon-dev libgl-dev libegl-dev

# Fedora
sudo dnf install zig freetype-devel harfbuzz-devel wayland-devel wayland-protocols-devel libxkbcommon-devel mesa-libGL-devel mesa-libEGL-devel
```

### macOS

```bash
brew install zig freetype harfbuzz
```

### Windows

- Install [Zig](https://ziglang.org/download/)
- Visual Studio Build Tools (for MSVC linker)

## Bootstrap

Fetch vendor dependencies (libvterm, raylib):

```bash
make bootstrap
# or
./scripts/bootstrap.sh
```

On Linux, this also generates Wayland protocol headers via `make wayland-protocols`.

Options:
- `LIBVTERM_REF=v0.3.3` - Override libvterm version
- `RAYLIB_REF=5.5` - Override raylib version
- `FORCE=1` - Force re-download

## Build

```bash
zig build
# or
make build
```

## Run

```bash
zig build run
# or
make run
```

## Test

```bash
zig build test
# or
make test
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+N | New file |
| Ctrl+O | Open file |
| Ctrl+S | Save file |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+` | Toggle terminal |
| Ctrl+Q | Quit |

## Performance Notes

Zide uses several techniques to minimize CPU usage:

- **VSync**: Rendering is synchronized to display refresh rate
- **Dirty tracking**: Only redraws when content changes
- **Adaptive sleep**: Longer sleep intervals when idle (16ms → 100ms)
- **Efficient I/O**: Uses `poll()` to check for terminal data without busy-waiting
- **Startup grace period**: Stays responsive for 3 seconds after launch

Idle CPU usage should be under 1%.

## Wayland Notes

Zide targets native Wayland on Linux (not XWayland). Current state:

- Compositor-aware mouse scaling is implemented for Hyprland via `hyprctl`.
- KDE scaling is planned but not implemented yet.
- Validation on Hyprland/KDE is still pending.

The app sets its window title to "Zide - Zig IDE", which can be used for window rules:

```
# Hyprland example
windowrulev2 = tile, title:^(Zide)
```

## Fonts

- Bundled fonts live in `assets/fonts/` (currently JetBrains Mono Nerd Font).

## Current Focus / Known Issues

If you only read one thing, read this.

- **Current focus:** terminal text rendering quality (Nerd icons clipping, box drawing striping).
- **Symptoms:** Nerd icons clip on the right; box drawing shows stripes in some apps (btop/nvim).
- **What we tried:** LCD rendering, pixel snapping, box drawing fallback, glyph scaling; improvements but not fully fixed.
- **Docs to read next:**
  - `docs/TERMINAL_TEXT_RESEARCH.md` (kitty/alacritty/wezterm analysis)
  - `docs/TERMINAL_TEXT_STEPS.md` (planned upgrade phases)
  - `docs/AGENT_HANDOFF.md` (latest status and next steps)
