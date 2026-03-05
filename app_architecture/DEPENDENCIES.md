# Dependency Packaging Architecture Notes

## Goal

Track practical migration details for replacing system-managed native dependencies with Zig package-managed alternatives in controlled phases.

## Current state

- `-Ddep-source=system` (default): current system/vcpkg-native behavior.
- `-Ddep-source=zig`: SDL3 resolves through Zig package manager (`castholm/SDL`), while FreeType/HarfBuzz/Lua remain system/vcpkg managed.
- Guardrail: `-Ddep-source=zig` is currently incompatible with `-Duse-vcpkg=true`.

## Implemented package integration

### SDL3

- Package: `castholm/SDL`
- Build API used:
  - `const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });`
  - `const sdl_lib = sdl_dep.artifact("SDL3");`
  - Link route selected via `-Ddep-source`.
- Validation:
  - `zig build`
  - `zig build -Ddep-source=zig`
  - `zig build test`
  - `zig build test -Ddep-source=zig`

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
  - Wired artifacts under `-Ddep-source=zig`.
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
- Pending integration check:
  - Confirm whether Zide can keep existing C API usage while linking via ziglua-provided artifact/module boundary, or whether Lua interaction should be moved to ziglua bindings.

### Lua backend split scaffold (implemented)

- `src/config/lua_config_capi.zig`: current production C-API implementation (moved intact).
- `src/config/lua_config_iface.zig`: canonical public API/type contract for backend parity checks.
- `src/config/lua_config_ziglua.zig`: ziglua backend placeholder with matching signatures.
- `src/config/lua_config.zig`: facade/selector routing to backend via build option.
- Build selector:
  - `-Dlua-impl=capi` (default)
  - `-Dlua-impl=ziglua` (fully implemented native parser path)

The split is behavior-preserving for default builds and enables independent evolution of the two backends.

### Ziglua package consumption status

- `build.zig` now wires ziglua into the compile graph when `-Dlua-impl=ziglua`:
  - Adds dependency via `b.dependency("zlua", ...)`
  - Imports module into app roots as `@import("zlua")`
- Current status:
  - ziglua backend config parsing is native (including keybind parsing, base/editor theme parsing, and editor schema/link resolution).
  - Legacy `lua_config_capi_bridge.zig` shim has been removed.
  - CAPI backend remains available under `-Dlua-impl=capi`.

## Recommended next implementation sequence

1. Add an explicit text-stack source selector (`system|zig`) separate from SDL selector semantics.
2. Prototype FreeType/HarfBuzz package wiring in a compile-only branch first.
3. Only after compile parity is stable, run rendering/shaping parity checks.
4. Stage Lua after text stack so config runtime regressions are isolated.

## Non-goals for dependency migration

- No runtime feature changes.
- No UI behavior redesign.
- No blending migration work with dependency wiring commits.
