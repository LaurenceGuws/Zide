# Zide - Zig IDE

A modern, cross-platform IDE for Zig development, built entirely in Zig.

## Features

- **Text Editor**: Rope-based text buffer with undo/redo
- **Syntax Highlighting**: Tree-sitter based, with Zig language support
- **Integrated Terminal**: PTY + VT core with scrollback (rendering polish ongoing)
- **Native Wayland**: Wayland support in progress (Hyprland first; KDE planned)
- **Low CPU Usage**: Adaptive frame rate with intelligent idle detection
- **Cross-platform roadmap**: Linux first; macOS and Windows planned

## Layout (brief)

- `src/` core app code (editor, terminal, UI)
- `vendor/` third-party sources fetched by bootstrap
- `assets/` fonts and other resources
- `app_architecture/` design + technical docs
- `docs/` agent/session instructions

## System Dependencies

### Linux (Wayland)

```bash
# Arch Linux
sudo pacman -S zig freetype2 harfbuzz sdl3 wayland wayland-protocols libxkbcommon mesa lua

# Ubuntu/Debian
sudo apt install zig libfreetype-dev libharfbuzz-dev libsdl3-dev libwayland-dev wayland-protocols libxkbcommon-dev libgl-dev libegl-dev liblua5.4-dev

# Fedora
sudo dnf install zig freetype-devel harfbuzz-devel SDL3-devel wayland-devel wayland-protocols-devel libxkbcommon-devel mesa-libGL-devel mesa-libEGL-devel lua-devel
```

### macOS

```bash
brew install zig freetype harfbuzz sdl3
```

### Windows

- Install [Zig](https://ziglang.org/download/)
- Visual Studio Build Tools (for MSVC linker)
- SDL3 development libraries (vcpkg or MSYS2 recommended)

## Bootstrap

This document is for dependencies, bootstrapping, build/run/test, and platform notes.
Current focus and active issues live in `docs/AGENT_HANDOFF.md` and the relevant
`app_architecture/**/_todo.yaml` files.

Fetch vendor dependencies:

```bash
make bootstrap
# or
./scripts/bootstrap.sh
```

Tree-sitter (runtime + Zig parser) and stb_image (PNG decode) are vendored under
`vendor/`, so no extra bootstrap step is required. Grammar packs are built and
installed via `zig build grammar-update`.

On Linux, this also generates Wayland protocol headers via `make wayland-protocols`.

UI rendering journey: `app_architecture/ui/DEVELOPMENT_JOURNEY.md`.

## Build

```bash
zig build
# or
make build
```

## Tree-sitter Grammar Packs

```bash
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```

On Windows, `grammar-update` runs the pack build scripts via `bash` (Git Bash or
MSYS2 recommended). If `bash` is not on PATH, use `--install-only` with a prebuilt
`tools/grammar_packs/dist`, or run the scripts from WSL.

If you want Android grammars, ensure an NDK is available:
- `ANDROID_NDK_ROOT` or `ANDROID_SDK_ROOT` set, or
- `~/.local/android-sdk/ndk/<version>`

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
