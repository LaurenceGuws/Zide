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

## Dependency path selector

Build keeps one migration selector:

```bash
zig build -Dpath=link
```

Alternate path label:

```bash
zig build -Dpath=zig
```

Notes:
- SDL3 and Lua are now always Zig package managed in normal flow (`castholm/SDL`, `ziglua` artifact `lua`).
- Tree-sitter core runtime is now also Zig package managed in normal flow (`tree_sitter/tree-sitter`, artifact `tree-sitter`).
- `-Dpath` is retained as a migration toggle surface for upcoming dependency moves.
- Current active migration on this toggle: FreeType/HarfBuzz packaging path.
- Parity checkpoint (March 6, 2026): `zig build`, `zig build test`, `zig build -Dpath=zig`, and `zig build test -Dpath=zig` pass on the current Linux path.
- Current `-Dpath=zig` text stack uses pinned Zig 0.15.2-compatible forks:
  - FreeType: `LaurenceGuws/freetype-zig015` (`052a300780531e6ea0ffeafeec28c88eb1bf903a`)
  - HarfBuzz: `LaurenceGuws/harfbuzz-zig015` (`68406a28eea39df8c074a38fefc64c5aa23201b7`)

Important:
- Zig package-managed dependencies are still native C/C++ libraries.
- The app still links `libc` and platform/system libraries (for example on Linux: `GL`, `fontconfig`, `m`, `pthread`, `dl`, `rt`, and `z` on the zig text-stack path).
- So this migration reduces host package coupling and version drift, but it is not a pure-Zig runtime/linkage yet.

## Terminal bundle runtime notes (Linux)

`zig build bundle-terminal` now ships and uses Zide-owned terminfo inside the bundle:
- Compiles `terminfo/zide.terminfo` with `tic -x` into `terminal-bundle/terminfo`.
- Launcher exports `TERMINFO` / `TERMINFO_DIRS` with the bundled directory first.
- PTY chooses `TERM=zide-256color` (alias-compatible with `zide` entry).

Shell startup consistency for bundled launcher:
- Launcher captures caller cwd into `ZIDE_LAUNCH_CWD`.
- PTY child applies `chdir(ZIDE_LAUNCH_CWD)` and synchronizes `PWD`.
- This avoids shell startup drift between direct binary (`./zig-out/bin/zide-terminal`) and installed bundle launcher paths.

Lua implementation status (config parser backend):
- The config parser backend is now fixed to native `ziglua`.
- `-Dlua-impl` is no longer a supported build selector.

## Recommended strategy
- Linux/macOS: system packages for fast local dev.
- Windows: vcpkg to pin and install native libs consistently.

This avoids vendoring large binaries early, while keeping Windows builds reproducible.

## Windows (vcpkg)

### Install vcpkg
1) Clone vcpkg:
```
 git clone https://github.com/microsoft/vcpkg C:\dev\vcpkg-win
 cd C:\dev\vcpkg-win
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

On Windows, the build expects vcpkg-provided deps and will look in either:
- `./vcpkg_installed/<triplet>/` (manifest mode), or
- `<VCPKG_ROOT>/installed/<triplet>/` (classic mode)

If `VCPKG_ROOT` and `VCPKG_DEFAULT_TRIPLET` are set, the build can locate classic-mode deps without extra flags.

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

### Troubleshooting (Windows)
- If `vcpkg` reports `Unable to find a valid Visual Studio instance`, install **Visual Studio Build Tools 2022** with the **Desktop development with C++** workload.
- If installs fail with `permission denied` while writing `buildtrees`, use a buildtrees folder inside your user profile:
```
 .\vcpkg.exe install sdl3 freetype harfbuzz lua --triplet x64-windows --x-buildtrees-root=C:\Users\Docker\vcpkg-buildtrees
```
- If an environment variable `VCPKG_ROOT` points at the VS install (`...\VC\vcpkg`), unset it or override with `-Dvcpkg-root=...` so Zig uses the intended vcpkg checkout.

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
