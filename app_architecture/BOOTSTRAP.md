# Zide Bootstrap

This doc owns practical bootstrap, build, run, and test guidance.

For dependency source policy, use [`docs/DEPENDENCIES.md`](/home/home/personal/zide/docs/DEPENDENCIES.md) as the authority.
For customer-facing product overview and hosted docs links, use
[`README.md`](/home/home/personal/zide/README.md).

## Current Dependency Model

Normal build flow now uses Zig package-managed dependencies for:

- SDL3
- Lua
- tree-sitter core
- FreeType
- HarfBuzz

That means Linux and macOS no longer use the old "install SDL3, Lua,
FreeType, HarfBuzz, and tree-sitter from the system package manager first"
workflow as the normal path.

You still need platform/system libraries and native runtime support:

- Zig
- OpenGL-capable system stack
- Wayland/XKB/system graphics libs on Linux
- `fontconfig` on Linux for system fallback font discovery

Windows remains the exception: the current Windows-native dependency flow still
uses vcpkg. See [`docs/DEPENDENCIES.md`](/home/home/personal/zide/docs/DEPENDENCIES.md) for the exact Windows path.

## System Dependencies

### Linux

Linux package-manager installation is now mostly about platform/runtime support,
not primary app-library sourcing.

Arch example:

```bash
sudo pacman -S zig wayland wayland-protocols libxkbcommon mesa fontconfig
```

Ubuntu/Debian example:

```bash
sudo apt install zig libwayland-dev wayland-protocols libxkbcommon-dev libgl-dev libegl-dev libfontconfig-dev
```

Fedora example:

```bash
sudo dnf install zig wayland-devel wayland-protocols-devel libxkbcommon-devel mesa-libGL-devel mesa-libEGL-devel fontconfig-devel
```

### macOS

Install Zig first:

```bash
brew install zig
```

If local toolchain or platform runtime requirements drift, defer to
[`docs/DEPENDENCIES.md`](/home/home/personal/zide/docs/DEPENDENCIES.md) rather than copying stale package lists forward here.

### Windows

Install:

- [Zig](https://ziglang.org/download/)
- Visual Studio Build Tools
- vcpkg-based native dependencies

Use the Windows/vcpkg section in
[`docs/DEPENDENCIES.md`](/home/home/personal/zide/docs/DEPENDENCIES.md) as the detailed authority.

## Bootstrap

Bootstrap the repo:

```bash
./scripts/bootstrap.sh
```

Windows:

```powershell
./scripts/bootstrap.ps1
```

Tree-sitter (runtime + Zig parser) and `stb_image` are vendored. Grammar packs
are handled separately via `zig build grammar-update`.

The main app-library stack is not vendored and not expected to come from the
system package manager in normal Linux/macOS flow; it is pinned in the Zig
package graph.

## Build

Default build:

```bash
zig build
```

Mode-focused builds:

```bash
zig build -Dmode=terminal
zig build -Dmode=editor
```

Useful build reports:

- `zig build report-build-mode`
- `zig build report-build-bootstrap`
- `zig build report-build-focused-policy`
- `zig build report-build-target`
- `zig build check-build-report-tools`
- `zig build report-build-all`

## Run

```bash
zig build run
```

## Terminal Setup

Install the bundled terminfo entry:

```bash
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

Then start a fresh shell inside Zide and verify:

```bash
printf '%s\n' "$TERM"
```

Current runtime TERM selection order is:

- `xterm-kitty` when available
- `xterm-zide`
- `zide-256color`
- `zide`
- `xterm-256color`

For the full compatibility surface, use
[`docs/terminal/compatibility.md`](/home/home/personal/zide/docs/terminal/compatibility.md).

## Tree-sitter Grammar Packs

```bash
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```

On Windows, `grammar-update` runs via `bash` (Git Bash or MSYS2 recommended).

## Test

```bash
zig build test
```

## Notes

- Current focus and active issues live in
  [`docs/AGENT_HANDOFF.md`](/home/home/personal/zide/docs/AGENT_HANDOFF.md)
  and the relevant `app_architecture/*todo*.md` files.
- UI rendering journey:
  [`app_architecture/ui/DEVELOPMENT_JOURNEY.md`](/home/home/personal/zide/app_architecture/ui/DEVELOPMENT_JOURNEY.md)
