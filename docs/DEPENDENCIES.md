# Dependencies

This doc owns dependency sourcing policy and platform dependency guidance.

For bootstrap/build/run commands, use
[`app_architecture/BOOTSTRAP.md`](../app_architecture/BOOTSTRAP.md).

## Current Model

On normal Linux, macOS, and Windows paths, Zide now resolves its main native
library stack through the Zig package manager, not the host package manager.

That default package-managed set is:

- SDL3
- Lua
- `zlua-portable` via pinned Zig package release dependency
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

## Local Co-Development Override

Normal repo truth is now back on published pinned package dependencies,
including `zlua-portable`.

For ordinary co-development, a sibling path override remains the intended
development escape hatch.

Recommended override shape:

```zig
.zlua_portable = .{
    .path = "../zlua-portable",
},
```

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

Current macOS GL bring-up note:

- compile/build truth is now green on the active arm64 host
- `zlua-portable` is back on a published pinned package path after the
  `v0.1.0-beta.2` package fix

## Windows

Windows now uses the same Zig package-managed dependency path as Linux and
macOS by default.

### Required tools

- Zig
- PowerShell
- Python 3 for `zig build grammar-update`

### Local grammar-maintenance layout

For local Tree-sitter grammar maintenance, keep the sibling repos together:

```text
personal/
  zide/
  zide-tree-sitter/
```

`zig build grammar-update` in `zide` now proxies into sibling repo
`zide-tree-sitter`.

### Configure build

Build:

```powershell
zig build
```

Current default Windows native target is `x86_64-windows-msvc`.

Current supported Windows-native policy:

- app/library dependencies come from the Zig package graph
- there is no live `vcpkg` fallback path
- grammar packs install under `%LOCALAPPDATA%\\Zide\\grammars` by default
- interactive multi-GUI smoke flow uses:
  - `zig build gui-smokes-manual`

For the supported Windows runtime/install layout, use
[`app_architecture/windows/INSTALLATION.md`](../app_architecture/windows/INSTALLATION.md).

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
[`docs/reference/terminal_compatibility.md`](reference/terminal_compatibility.md).

## Notes

- Current text stack uses pinned Zig 0.15.2-compatible forks for FreeType and
  HarfBuzz in the Zig package graph.
- Windows uses the Zig-managed package path for runtime artifacts too.
