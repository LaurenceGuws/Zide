# Dependency Architecture

This doc owns the current dependency architecture for Zide.

For user/operator setup guidance, use
[`docs/DEPENDENCIES.md`](/home/home/personal/zide/docs/DEPENDENCIES.md).
For bootstrap/build/run commands, use
[`app_architecture/BOOTSTRAP.md`](/home/home/personal/zide/app_architecture/BOOTSTRAP.md).

## Current Model

Zide now treats dependency sourcing in two layers:

1. App/library dependencies
2. Platform/runtime dependencies

The app/library layer is Zig package-managed by default on normal Linux/macOS
paths.

That package-managed set currently includes:

- SDL3
- Lua
- tree-sitter core
- FreeType
- HarfBuzz

The platform/runtime layer remains system-managed.

That still includes things like:

- Wayland/runtime graphics stack
- XKB/platform window-system linkage
- OpenGL/EGL/Mesa linkage
- `fontconfig` on Linux
- standard native system libs

So the correct architecture framing is:

- Zig package manager owns the primary third-party app stack
- the OS still owns the platform/runtime surface

This is a sourcing and reproducibility improvement, not a claim that Zide is
"pure Zig" at runtime.

## Package Graph

Current pinned package graph in `build.zig.zon` includes:

- `castholm/SDL`
- `natecraddock/ziglua`
- `tree-sitter/tree-sitter`
- pinned Zig 0.15.2-compatible FreeType fork
- pinned Zig 0.15.2-compatible HarfBuzz fork

Important nuance:

- FreeType and HarfBuzz are package-managed on non-vcpkg paths now.
- Windows remains the explicit exception and keeps `vcpkg` as the native
  dependency path.

## Build Policy

Dependency policy is enforced in the build graph, not just in docs.

Current important rules:

- SDL3 is linked through the Zig package path in normal flow.
- Lua is linked through ziglua and config parsing is native ziglua.
- tree-sitter core is package-managed.
- `zide-terminal` is intentionally detached from tree-sitter linkage.
- main/editor/ide and editor-facing test/FFI targets still link tree-sitter.
- FreeType and HarfBuzz are linked through the pinned package path on
  non-vcpkg builds.

Build hygiene guardrail:

- `zig build check-build-deps`

That check exists so focused binaries do not quietly accrete dependency drift.

## Platform Split

### Linux and macOS

Linux and macOS use the Zig-managed dependency path as the default for the
main third-party app stack.

They still rely on platform/system libraries for:

- graphics
- window-system/runtime integration
- font discovery on Linux
- standard native linking requirements

### Windows

Windows remains intentionally separate:

- native dependency path is `vcpkg`
- runtime packaging still includes native DLL payloads from that path

This is not accidental drift. It is the current explicit platform policy.

## Text Stack

The text stack is no longer a system-first architecture on normal Linux/macOS
paths.

Current state:

- FreeType and HarfBuzz are sourced from pinned Zig packages
- Linux still uses `fontconfig` for fallback font discovery
- the build still links native platform/system libraries where required

That means:

- text shaping/rasterization library sourcing is Zig-managed
- font discovery remains platform-integrated on Linux

## Lua

Lua is no longer a special external/manual dependency in the normal build path.

Current state:

- ziglua provides the Lua dependency
- config parsing is native ziglua
- the old backend selector and C-bridge split are gone from the default path

Owned runtime shape:

- `src/config/lua_config_iface.zig`
- `src/config/lua_config_ziglua.zig`
- `src/config/lua_config.zig`

## Tree-sitter

tree-sitter core is package-managed now.

Additional constraints:

- the terminal-focused binary intentionally stays detached from tree-sitter
- editor-facing products keep the dependency where it materially belongs
- grammar-pack workflow remains separate from the core dependency policy

## Terminal Packaging Note

Terminal bundle packaging has a separate runtime-distribution concern:

- project-owned terminfo payload
- launcher/runtime TERM selection policy
- packaged shell cwd semantics

That is related to distribution architecture, not to the core third-party
dependency-source policy.

Use:

- [`docs/terminal/compatibility.md`](/home/home/personal/zide/docs/terminal/compatibility.md)
- [`app_architecture/terminal/VT_CORE_DESIGN.md`](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)

## Remaining Work

The main dependency architecture is no longer "in migration" in the old sense.
The remaining work is narrower:

1. keep the pinned FreeType/HarfBuzz package revisions explicit and healthy
2. continue parity validation on rendering/shaping across target environments
3. reduce remaining system-coupled links only where the change is safe and
   measurable
4. keep dependency-policy enforcement strict for focused binaries

## Historical Notes

Older migration attempts and retry history existed mainly around the
FreeType/HarfBuzz path while upstream package compatibility with Zig 0.15.2 was
still settling.

The important outcome today is:

- the package-managed text-stack path is landed
- the current architecture uses pinned forks where necessary
- retry-history is no longer the main story
