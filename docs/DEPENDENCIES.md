# Dependencies

This doc owns dependency sourcing policy and platform dependency guidance.

For bootstrap/build/run commands, use
[`app_architecture/BOOTSTRAP.md`](/home/home/personal/zide/app_architecture/BOOTSTRAP.md).

## Current Model

On normal Linux and macOS paths, Zide now resolves its main native library
stack through the Zig package manager, not the host package manager.

That default package-managed set is:

- SDL3
- Lua
- tree-sitter core
- FreeType
- HarfBuzz

These are still native C/C++ libraries. The change is about source/pinning and
build integration, not about pretending the runtime is pure Zig.

The practical split is now:

- Zig package manager owns the primary third-party app/library stack
- the OS still provides platform/runtime linkage and system facilities

So on Linux/macOS, manually sourcing SDL3, Lua, FreeType, HarfBuzz, and
tree-sitter from the host package manager is no longer the normal path.

## What The OS Still Provides

Even with Zig-managed library sourcing, native platforms still provide:

- graphics/window-system linkage
- Wayland/XKB/platform runtime libraries
- OpenGL/EGL/Mesa stack as applicable
- `fontconfig` on Linux for fallback font discovery

So the right mental model is:

- app/library dependencies: Zig-managed by default
- platform/runtime dependencies: still system-managed

## Linux

Linux no longer needs the old full "install all app deps from system packages"
workflow.

Current Linux-native expectations are now:

- Zig
- Wayland development/runtime stack
- `libxkbcommon`
- OpenGL / Mesa stack
- `fontconfig`

Example package sets:

Arch:

```bash
sudo pacman -S zig wayland wayland-protocols libxkbcommon mesa fontconfig
```

Ubuntu/Debian:

```bash
sudo apt install zig libwayland-dev wayland-protocols libxkbcommon-dev libgl-dev libegl-dev libfontconfig-dev
```

Fedora:

```bash
sudo dnf install zig wayland-devel wayland-protocols-devel libxkbcommon-devel mesa-libGL-devel mesa-libEGL-devel fontconfig-devel
```

Important Linux note:

- `fontconfig` still matters because Zide uses it for system fallback font
  discovery.
- The Linux-native build still links platform/system libraries such as `GL`,
  `fontconfig`, `m`, `pthread`, `dl`, `rt`, and `z`.

## macOS

The same dependency-source policy applies on macOS: the main third-party app
libraries are Zig-managed in normal flow.

At minimum, install Zig:

```bash
brew install zig
```

If extra macOS platform/toolchain requirements become necessary, update this
doc instead of reviving stale "install every library manually" guidance.

## Windows

Windows remains the exception.

Current Windows-native flow still uses vcpkg for platform-native dependency
management rather than the normal Linux/macOS Zig-managed path.

### Required tools

- Zig
- Visual Studio Build Tools
- vcpkg

### Install vcpkg

```powershell
git clone https://github.com/microsoft/vcpkg C:\dev\vcpkg-win
cd C:\dev\vcpkg-win
.\bootstrap-vcpkg.bat
```

### Install native libraries

Recommended manifest-mode install from the Zide repo root:

```powershell
C:\path\to\vcpkg\vcpkg.exe install --triplet x64-windows
```

Classic mode also works:

```powershell
.\vcpkg.exe install sdl3 freetype harfbuzz lua --triplet x64-windows
```

### Configure build

Recommended environment variables:

- `VCPKG_ROOT`
- `VCPKG_DEFAULT_TRIPLET=x64-windows`

Build:

```powershell
zig build
```

On Windows, the build looks in either:

- `./vcpkg_installed/<triplet>/`
- `<VCPKG_ROOT>/installed/<triplet>/`

Use the MSVC target with the `x64-windows` triplet:

```powershell
zig build -Dvcpkg-triplet=x64-windows -Dtarget=x86_64-windows-msvc
```

## Terminal Bundle Runtime Notes

`zig build bundle-terminal` ships a Zide-owned terminfo payload.

Current TERM selection order in the runtime is:

- `xterm-kitty`
- `xterm-zide`
- `zide-256color`
- `zide`
- `xterm-256color`

Launcher behavior:

- launcher does not force `TERMINFO` by default
- packaged installs are expected to rely on installed terminfo paths

For the user-facing compatibility surface, use
[`docs/terminal/compatibility.md`](/home/home/personal/zide/docs/terminal/compatibility.md).

## Notes

- Current text stack uses pinned Zig 0.15.2-compatible forks for FreeType and
  HarfBuzz in the Zig package graph.
- Windows runtime packaging still includes native DLLs such as SDL3, FreeType,
  HarfBuzz, and Lua from the Windows dependency path.
