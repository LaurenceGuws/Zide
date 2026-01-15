# Zide - Zig IDE

A modern, cross-platform IDE for Zig development, built entirely in Zig.

## Features

- **Text Editor**: Piece-table based text buffer with undo/redo
- **Syntax Highlighting**: Tree-sitter based, with Zig language support
- **Integrated Terminal**: libvterm-based terminal emulator with full color support
- **Native Wayland**: First-class support for Wayland compositors (Hyprland, Sway, etc.)
- **Low CPU Usage**: Adaptive frame rate with intelligent idle detection
- **Cross-platform**: Linux (Wayland), macOS, and Windows support

## Architecture

```
zide/
├── src/
│   ├── main.zig              # Application entry point & main loop
│   ├── editor/               # Text editing engine
│   │   ├── buffer.zig        # Piece-table text buffer
│   │   ├── editor.zig        # High-level editor API
│   │   ├── syntax.zig        # Tree-sitter syntax highlighting
│   │   └── types.zig         # Data structures
│   ├── terminal/             # Terminal emulator
│   │   ├── terminal.zig      # Terminal session management
│   │   ├── vterm.zig         # libvterm wrapper
│   │   ├── vterm_shim.c      # C helper for libvterm callbacks
│   │   ├── pty_unix.zig      # Unix PTY backend
│   │   └── pty_windows.zig   # Windows ConPTY backend
│   └── ui/                   # User interface
│       ├── renderer.zig      # raylib rendering abstraction
│       ├── terminal_font.zig # FreeType/HarfBuzz font rendering
│       └── widgets.zig       # UI components (tabs, status bar, etc.)
├── vendor/                   # External dependencies (fetched by bootstrap)
│   ├── libvterm/             # Terminal emulation library
│   ├── raylib/               # Graphics/input library
│   └── wayland-protocols/    # Generated Wayland protocol headers (Linux)
├── assets/
│   └── fonts/                # Bundled fonts (Iosevka Nerd Font)
├── build.zig                 # Zig build configuration
├── build.zig.zon             # Package dependencies
├── Makefile                  # Convenience targets
└── scripts/
    └── bootstrap.sh          # Dependency fetcher
```

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

Zide uses native Wayland on Linux (not XWayland). This provides:

- Proper window tiling on Hyprland, Sway, etc.
- Correct HiDPI/fractional scaling
- Smooth window resizing
- Lower latency input

The app sets its window title to "Zide - Zig IDE", which can be used for window rules:

```
# Hyprland example
windowrulev2 = tile, title:^(Zide)
```

## Roadmap

- [ ] File tree sidebar
- [ ] Multiple split panes
- [ ] LSP integration (ZLS)
- [ ] Git integration
- [ ] Search/replace
- [ ] Command palette
- [ ] Configuration file
- [ ] Plugin system
