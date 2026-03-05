# Dependency Packaging Architecture Notes

## Goal

Track practical migration details for replacing system-managed native dependencies with Zig package-managed alternatives in controlled phases.

## Current state

- SDL3 and Lua resolve through Zig package manager in normal flow (`castholm/SDL`, `ziglua`).
- FreeType/HarfBuzz remain system/vcpkg managed.
- `-Dpath=link|zig` is retained as the migration toggle surface for the next dependency slice.

## Implemented package integration

### SDL3

- Package: `castholm/SDL`
- Build API used:
  - `const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });`
  - `const sdl_lib = sdl_dep.artifact("SDL3");`
  - Linked unconditionally in current flow.
- Validation:
  - `zig build`
  - `zig build -Dpath=zig`
  - `zig build test`
  - `zig build test -Dpath=zig`

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

1. Use `-Dpath` as the single migration selector while moving FreeType/HarfBuzz.
2. Prototype FreeType/HarfBuzz package wiring in a compile-only branch first.
3. Only after compile parity is stable, run rendering/shaping parity checks.
4. Stage Lua after text stack so config runtime regressions are isolated.

## Non-goals for dependency migration

- No runtime feature changes.
- No UI behavior redesign.
- No blending migration work with dependency wiring commits.
