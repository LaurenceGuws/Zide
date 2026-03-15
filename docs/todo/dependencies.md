# Dependencies TODO

## Scope

Evaluate and phase in Zig-managed native dependencies to reduce host-package coupling without changing runtime behavior.

## Constraints

- Keep the default developer path stable and buildable at every checkpoint.
- Preserve a rollback path for each dependency move.
- Treat this track as extraction and wiring work first; behavior parity must hold.

## Entry Points

- `build.zig`
- `build.zig.zon`
- `docs/DEPENDENCIES.md`
- `app_architecture/BOOTSTRAP.md`

## Validation

- Required per slice: `zig build`, `zig build test`, `zig build check-app-imports`, `zig build check-input-imports`, `zig build check-editor-imports`
- Manual smokes: `zig build run -- --mode terminal`, `zig build run -- --mode editor`, `zig build run -- --mode ide`

## External Candidates

- SDL3: `castholm/SDL`
- FreeType/HarfBuzz: `mach-freetype` lineage, with Zig 0.15.2-compatible forks currently used for text-stack wiring
- Lua 5.4: `ziglua`
- Tree-sitter: `zig-tree-sitter` only if it improves reproducibility over current flow

## Milestones

### DEP-00 Baseline and Build Interface

- [x] `DEP-00-01` Add dependency source selection interface in build config
  Historical only; the selector was later retired.
- [x] `DEP-00-02` Document dependency migration policy and rollback expectations

### DEP-01 SDL3 Zig Package Path

- [x] `DEP-01-01` Introduce SDL3 Zig package backend behind a build selector
  Landed historically and later became part of the normal Zig-managed flow.
- [x] `DEP-01-02` Parity-check system vs Zig SDL3 builds
  Non-GUI parity passed before selector retirement; remaining SDL2-era branches were removed except one guarded DPI symbol call for SDL3 header compatibility.

### DEP-02 FreeType/HarfBuzz Zig Package Path

- [x] `DEP-02-01` Add optional Zig-managed FreeType/HarfBuzz backend
  Direct Mach package wiring was blocked on Zig 0.15.2; compatible forks were pinned and build hooks were extracted to centralize future wiring.
- [ ] `DEP-02-02` Validate font shaping and rasterization parity against the system path
  In progress. Automated terminal-focused parity checks passed; manual visual terminal/editor/font-sample parity is still required.

### DEP-03 Lua Runtime Dependency Path

- [x] `DEP-03-01` Add optional Zig-managed Lua backend
  The migration finished with native `ziglua` as the only active path.
- [ ] `DEP-03-02` Validate config reload and Lua API behavior parity
- [x] `DEP-03-03` Migrate `lua_config` ownership groups onto the ziglua backend
  Completed through staged parser, keybind, theme, runtime, and bridge removal work; config parsing is now native ziglua without the old C API bridge.

### DEP-04 Tree-sitter Packaging Decision

- [x] `DEP-04-01` Evaluate tree-sitter packaging changes vs the prior vendor strategy
- [x] `DEP-04-02` Decide keep-vendor vs package and document the result
  Decision: package-managed tree-sitter core is primary; vendored core wiring was removed from the build graph.
- [x] `DEP-04-03` Auto-bootstrap missing grammars
  Added optional one-shot grammar bootstrap plus user-facing missing-grammar guidance.

### DEP-05 Default Flip Readiness

- [ ] `DEP-05-01` Define criteria to make Zig-managed dependencies the default
- [ ] `DEP-05-02` Update docs and bootstrap guidance once defaults change

### DEP-06 Terminal Identity and Terminfo Packaging Parity

- [x] `DEP-06-01` Stabilize terminal `TERM` identity away from kitty fallback
- [x] `DEP-06-02` Align bundle vs package terminfo behavior and docs

### DEP-07 Remove Dependency-Path Selector

- [x] `DEP-07-01` Retire `-Dpath` and legacy link/zig branching

