# Dependencies

This doc explains how to install Zide's native dependencies per OS, with a focus on low-level reproducibility.

## Overview
Zide depends on the following native libraries:
- SDL2 (windowing/input)
- FreeType (font rasterization)
- HarfBuzz (text shaping)
- Lua 5.4 (config scripting)
- OpenGL (platform-specific)

We currently compile against SDL2 headers. The runtime may still pick up SDL3 if installed globally; this is tracked in `app_architecture/ui/DEVELOPMENT_JOURNEY.md` as a known issue.

## Recommended strategy
- Linux/macOS: system packages for fast local dev.
- Windows: vcpkg to pin and install native libs consistently.

This avoids vendoring large binaries early, while keeping Windows builds reproducible.

## Windows (vcpkg)

### Install vcpkg
1) Clone vcpkg:
```
 git clone https://github.com/microsoft/vcpkg
 cd vcpkg
 .\bootstrap-vcpkg.bat
```

2) Install the required libraries (x64):
```
 .\vcpkg.exe install sdl2 freetype harfbuzz lua --triplet x64-windows
```

### Configure build
Export (or pass) vcpkg paths so `build.zig` can locate headers/libs.

Recommended environment variables:
- `VCPKG_ROOT` = path to vcpkg repo
- `VCPKG_DEFAULT_TRIPLET` = `x64-windows`

Then build on Windows:
```
 zig build
```

If cross-compiling from Linux, you still need Windows libraries on disk. vcpkg can build them, but you must also provide a Windows target toolchain.

## Linux
Install the deps using your distro package manager:
- SDL2 dev package
- FreeType dev package
- HarfBuzz dev package
- Lua 5.4 dev package
- OpenGL dev package

Examples (Ubuntu):
```
 sudo apt install libsdl2-dev libfreetype6-dev libharfbuzz-dev liblua5.4-dev libgl1-mesa-dev
```

Examples (Arch):
```
 sudo pacman -S sdl2 freetype2 harfbuzz lua mesa
```

## macOS
Use Homebrew:
```
 brew install sdl2 freetype harfbuzz lua
```

## Notes
- On Windows, SDL2 also provides the OpenGL import libs you need.
- If you see SDL3 runtime logs, ensure SDL2 is ahead in PATH or remove SDL3 from the environment. We still compile against SDL2 headers.
