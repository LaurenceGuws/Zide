# Zide Bootstrap

This doc owns practical bootstrap, build, run, and test guidance.

For dependency source policy, use [`docs/DEPENDENCIES.md`](../docs/DEPENDENCIES.md) as the authority.
For customer-facing product overview and hosted docs links, use
[`README.md`](../README.md).

## Current Dependency Model

Normal build flow now uses Zig package-managed dependencies for:

- SDL3
- Lua
- tree-sitter core
- FreeType
- HarfBuzz

Current local-package exception:

- `zlua-portable`, pinned from release tag `v0.1.0-beta.1`

That means Linux and macOS no longer use the old "install SDL3, Lua,
FreeType, HarfBuzz, and tree-sitter from the system package manager first"
workflow as the normal path.

You still need platform/system libraries and native runtime support:

- Zig
- OpenGL-capable system stack
- Wayland/XKB/system graphics libs on Linux
- `fontconfig` on Linux for system fallback font discovery

Windows now follows the same Zig package-managed dependency path by default.
See [`docs/DEPENDENCIES.md`](../docs/DEPENDENCIES.md) for the exact Windows path.

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
[`docs/DEPENDENCIES.md`](../docs/DEPENDENCIES.md) rather than copying stale package lists forward here.

### Windows

Install:

- [Zig](https://ziglang.org/download/)
- [PowerShell](https://learn.microsoft.com/powershell/) on `PATH`
- [Python 3](https://www.python.org/downloads/) for `zig build grammar-update`

Use the Windows section in
[`docs/DEPENDENCIES.md`](../docs/DEPENDENCIES.md) as the detailed authority.
For release-install layout and the first per-user installer path, use
[`app_architecture/windows/INSTALLATION.md`](windows/INSTALLATION.md).

## Bootstrap

Bootstrap the repo:

```bash
./ops/bootstrap.sh
```

Fresh local checkout example:

```bash
cd /home/home/personal
git clone git@github.com:LaurenceGuws/Zide.git zide
cd zide
./ops/bootstrap.sh
```

Local co-development note:

- if you need to change `zlua-portable` and `zide` together, temporarily swap
  the pinned package dependency for a sibling local path override

Override shape:

```zig
.zlua_portable = .{
    .path = "../zlua-portable",
},
```

Windows:

```powershell
./ops/bootstrap.ps1
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

Manual multi-GUI smoke on all platforms:

```bash
zig build gui-smokes-manual
```

Linux local desktop install surfaces:

```bash
ops/linux/install-local/deploy_channel.sh dev
ops/linux/install-local/deploy_channel.sh stable
ops/linux/install-local/sync_channel.sh dev
```

Linux local staged release:

```bash
ops/linux/Stage-CurrentLinuxDist.sh
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

Write the shipped default config to the platform user-config path:

```bash
zig build run -- --write-default-config
```

Variants:

```bash
zig build run -- --write-default-config --force
zig build run -- --write-default-config=/tmp/zide-init.lua
zig build run -- --write-default-config --stdout
zig build run -- --write-default-config --with-lua-meta
zig build run -- --write-default-config --config-scope=editor --stdout
zig build run -- --write-default-config --config-scope=terminal --stdout
```

Without `--force`, an existing user `init.lua` is preserved and only missing
files are added.

Install LuaLS metadata beside the user config so opening `~/.config/zide`
directly still gets completions:

```bash
zig build run -- --install-user-lua-meta
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
[`docs/reference/terminal_compatibility.md`](../docs/reference/terminal_compatibility.md).

## Tree-sitter Grammar Packs

```bash
zig build grammar-update -- --skip-git --continue-on-error --jobs 8
```

On Windows, `grammar-update` now uses PowerShell and Python 3 by default; Git
Bash is no longer required for the normal local path.
Installed grammar packs live under `%LOCALAPPDATA%\\Zide\\grammars` on Windows
by default.

## Test

```bash
zig build test
zig build check-app-imports
```

## Notes

- Current focus and active issues live in
  [`docs/AGENT_HANDOFF.md`](../docs/AGENT_HANDOFF.md)
  and the relevant `docs/todo/` files.
- UI rendering journey:
  [`app_architecture/ui/DEVELOPMENT_JOURNEY.md`](ui/DEVELOPMENT_JOURNEY.md)
