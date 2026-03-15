# Dependencies

This doc owns dependency source policy and platform dependency guidance.

For bootstrap/build/run commands, use
[`app_architecture/BOOTSTRAP.md`](/home/home/personal/zide/app_architecture/BOOTSTRAP.md).

## Current Dependency Source Policy

Normal build flow now uses Zig package-managed dependencies for:

- SDL3
- Lua
- tree-sitter core
- FreeType
- HarfBuzz

This is the stable default policy on non-vcpkg paths.

Important:

- These are still native C/C++ libraries built and linked through Zig.
- This reduces system package coupling, but does not make the runtime "pure
  Zig" or free of platform/system linkage.

## Linux and macOS

On Linux and macOS, the old requirement to preinstall SDL3, Lua, FreeType,
HarfBuzz, and tree-sitter from the system package manager is no longer the
normal flow.

You still need platform/system support libraries.

### Linux

Current Linux-native expectations:

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

Why `fontconfig` still matters:

- Zide still uses Linux `fontconfig` for system fallback font discovery.
- The build links `fontconfig` on Linux-native paths.

### macOS

At minimum, install Zig:

```bash
brew install zig
```

If additional platform/toolchain setup becomes necessary, update this doc
instead of reviving stale "install every library manually" advice in the
README.

## Windows

Windows remains the exception. Current Windows-native flow still uses vcpkg for
platform-native dependency management.

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
  HarfBuzz.
- Linux still links platform/system libraries such as `GL`, `fontconfig`, `m`,
  `pthread`, `dl`, `rt`, and `z`.
- Windows runtime packaging still includes native DLLs such as SDL3, FreeType,
  HarfBuzz, and Lua from the Windows dependency path.
