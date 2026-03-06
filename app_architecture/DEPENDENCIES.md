# Dependency Packaging Architecture Notes

## Goal

Track practical migration details for replacing system-managed native dependencies with Zig package-managed alternatives in controlled phases.

## Current state

- SDL3, Lua, and tree-sitter core resolve through Zig package manager in normal flow (`castholm/SDL`, `ziglua`, `tree_sitter/tree-sitter`).
- FreeType/HarfBuzz now also resolve through Zig package manager on non-vcpkg paths.
- Windows keeps vcpkg integration as the platform-specific dependency path.
- Build/runtime still link native C/C++ libraries and system libs; package migration changes sourcing/pinning, not language/runtime ABI.
- `zide-terminal` is now intentionally detached from tree-sitter linking/plumbing; tree-sitter remains linked for main/editor/ide and editor-facing test/ffi targets.
- Build hygiene guardrail: `zig build check-build-deps` enforces the app target dependency policy in `build.zig` (including terminal no-tree-sitter rule).
- Linux terminal bundle (`zig build bundle-terminal`) now compiles/ships project-owned terminfo and launches with stable shell cwd semantics:
  - bundles `zide.terminfo` via `tic -x` into `terminal-bundle/terminfo`,
  - launcher does not force `TERMINFO`/`TERMINFO_DIRS`,
  - runtime TERM preference is `xterm-zide`, then `zide-256color`, then `zide`, then `xterm-256color`,
  - launcher-provided cwd is applied in PTY child with matching `PWD` sync.

## Implemented package integration

### SDL3

- Package: `castholm/SDL`
- Build API used:
  - `const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });`
  - `const sdl_lib = sdl_dep.artifact("SDL3");`
  - Linked unconditionally in current flow.
- Validation:
  - `zig build`
  - `zig build test`

## Candidate research notes

### FreeType + HarfBuzz

- Candidate package: `hexops/mach-freetype`
- Observed API shape:
  - Exposes modules (`mach-freetype`, `mach-harfbuzz`).
  - Internally links lazy dependencies named `freetype` and `harfbuzz`.
  - Does not expose direct top-level `artifact("freetype")` / `artifact("harfbuzz")` in its own `build.zig` as currently published.
- Implication for Zide:
  - Zide currently relies on direct C header include paths and `linkSystemLibrary` for these two libs.
  - Moving to package-managed FreeType/HarfBuzz may require either:
    - direct use of package deps that expose artifacts, or
    - migration away from raw system include path assumptions to package-provided include/link surfaces.

### FreeType + HarfBuzz (attempt status)

- Date: March 5, 2026
- Attempted approach:
  - Added direct package deps for Mach-hosted `freetype` and `harfbuzz`.
  - Wired artifacts under the migration toggle path.
- Result:
  - Reverted due package build-script/toolchain incompatibility.
  - Error signature: `no field or member function named 'addStaticLibrary' in 'Build'`.
- Decision:
  - Keep DEP-02 pending and maintain current system/vcpkg text-stack linking.
  - Continue dependency migration with SDL3-only Zig package path as stable baseline.

### FreeType + HarfBuzz (retry status)

- Date: March 6, 2026
- Attempted approach:
  - Forked and pinned Zig 0.15.2-compatible FreeType/HarfBuzz package repos and wired them through extracted `linkTextStack` / `addTextStackIncludes` hooks.
- Result:
  - Build path is now healthy and passing with pinned forks.
  - Required wiring fix in Zide build graph:
    - resolve FreeType from its own dep handle (not from HarfBuzz dep artifacts),
    - link zlib (`-lz`) for FreeType gzip support.
- Decision:
  - Keep DEP-02 `in_progress` (no longer blocked).
  - Next step is parity validation + replacing forks with upstream-compatible package revisions when available.
  - Current pinned forks:
    - `LaurenceGuws/freetype-zig015` (`052a300780531e6ea0ffeafeec28c88eb1bf903a`)
    - `LaurenceGuws/harfbuzz-zig015` (`68406a28eea39df8c074a38fefc64c5aa23201b7`)

### Lua

- Candidate package: `natecraddock/ziglua`
- Known compatibility signal:
  - Repository is active and tracks modern Zig.
- Integration status:
  - Lua links via ziglua-provided `lua` artifact in normal flow.
  - Parser path is fully native ziglua.
  - `-Dlua-impl` selector has been removed.

### Lua backend status

- `src/config/lua_config_iface.zig`: canonical public API/type contract.
- `src/config/lua_config_ziglua.zig`: native ziglua implementation.
- `src/config/lua_config.zig`: thin facade routing directly to ziglua implementation.

The split is behavior-preserving for default builds and enables independent evolution of the two backends.

### Ziglua package consumption status

- `build.zig` wires ziglua into the compile graph unconditionally for config parsing:
  - Adds dependency via `b.dependency("zlua", ...)`
  - Imports module into app roots as `@import("zlua")`
- `build.zig` wires ziglua dependency in normal flow:
  - Links `artifact("lua")` for C API consumers
  - Uses emitted include tree for Lua headers
- Current status:
  - ziglua backend config parsing is native (including keybind parsing, base/editor theme parsing, and editor schema/link resolution).
  - Legacy `lua_config_capi_bridge.zig` shim has been removed.
  - No CAPI backend selector remains in build options.

## Recommended next implementation sequence

1. Keep FreeType/HarfBuzz pin revisions explicit and updated as upstream catches up.
2. Continue rendering/shaping parity checks across target environments.
3. Reduce remaining system-coupled platform links only where safe and measurable.
4. Keep dependency-policy checks strict so focused binaries stay clean.

## Non-goals for dependency migration

- No runtime feature changes.
- No UI behavior redesign.
- No blending migration work with dependency wiring commits.
