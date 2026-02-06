# Dependencies

This doc explains how to install Zide's native dependencies per OS, with a focus on low-level reproducibility.

## Overview
Zide depends on the following native libraries:
- SDL3 (windowing/input)
- FreeType (font rasterization)
- HarfBuzz (text shaping)
- Lua 5.4 (config scripting)
- OpenGL (platform-specific)

SDL3 is the default build target.

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

Note: vcpkg relies on PowerShell (pwsh). If vcpkg fails with an error like
"The cloud file provider is not running" for a path under
`%USERPROFILE%\OneDrive\Documents\PowerShell\powershell.config.json`, either:
- Start/sign-in to OneDrive (so the placeholder file becomes readable), or
- Delete that `powershell.config.json` placeholder file.

2) Install the required libraries (x64).

Recommended (manifest mode, from the Zide repo root):
```
 C:\path\to\vcpkg\vcpkg.exe install --triplet x64-windows
```

This writes dependencies into `./vcpkg_installed/x64-windows/`.

Classic mode (installs into `<VCPKG_ROOT>/installed/<triplet>/`) also works:
```
 .\vcpkg.exe install sdl3 freetype harfbuzz lua --triplet x64-windows
```

### Configure build
Export (or pass) vcpkg paths so `build.zig` can locate headers/libs.

Recommended environment variables:
- `VCPKG_ROOT` = path to vcpkg repo
- `VCPKG_DEFAULT_TRIPLET` = `x64-windows`

Build with vcpkg enabled:
```
 zig build -Duse-vcpkg=true
```

On Windows, `zig build` defaults to using vcpkg when the vcpkg manifest install
directory (`./vcpkg_installed/`) is present.

On Windows, use the MSVC target when using the `x64-windows` triplet:
```
 zig build -Duse-vcpkg=true -Dvcpkg-triplet=x64-windows -Dtarget=x86_64-windows-msvc
```

You can also pass paths explicitly:
```
 zig build -Duse-vcpkg=true -Dvcpkg-root=C:\\path\\to\\vcpkg -Dvcpkg-triplet=x64-windows
```

Then build on Windows:
```
 zig build
```

If cross-compiling from Linux, you still need Windows libraries on disk. vcpkg can build them, but you must also provide a Windows target toolchain.

## Linux
Install the deps using your distro package manager:
- SDL3 dev package
- FreeType dev package
- HarfBuzz dev package
- Lua 5.4 dev package
- OpenGL dev package

Examples (Ubuntu):
```
 sudo apt install libsdl3-dev libfreetype6-dev libharfbuzz-dev liblua5.4-dev libgl1-mesa-dev
```

Examples (Arch):
```
 sudo pacman -S sdl3 freetype2 harfbuzz lua mesa
```

## macOS
Use Homebrew:
```
 brew install sdl3 freetype harfbuzz lua
```

## Notes
- Use the same SDL3 version for headers and libraries to avoid ABI mismatches.
