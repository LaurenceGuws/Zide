# Config Architecture Migration

## Scope

Drive the `zide` Lua/config subsystem to a DRY, loosely coupled architecture
with a hard ownership boundary between:

- low-level reusable Lua mechanics
- `zide`-internal generic config parsing helpers
- `zide` app-specific config semantics

## Architectural Target

### Layer 1: Shared Lua Mechanics

Owned by [`zlua-portable`](/home/home/personal/zlua-portable).

Allowed responsibilities:

- Lua state wrapping
- stack access
- field lookup
- scalar reads
- table iteration
- generic borrowed/owned reader helpers

Forbidden responsibilities:

- `zide` config paths
- `zide` enums
- `zide` merge rules
- `zide` runtime policy

### Layer 2: Zide Config Reader

Owned by `src/config`.

This layer adapts `zlua-portable` to `zide` config parsing without introducing
product semantics into the shared package.

Target responsibilities:

- string / bool / int / float field helpers
- enum-from-string helpers
- string-or-list helpers
- keyed table iteration helpers
- array entry helpers
- nested table helpers

### Layer 3: Zide Domain Parsers

Owned by `src/config`.

Files in this layer should mostly express config meaning rather than Lua stack
manipulation:

- `lua_config_log_parse.zig`
- `lua_config_runtime_parse.zig`
- `lua_config_font_parse.zig`
- `lua_config_theme_parse.zig`
- `lua_config_keybind_parse.zig`
- `lua_config_ziglua_parse.zig`

## Current Findings

- `zlua-portable` is already the active low-level helper seam.
- `lua_config_ziglua_parse.zig` is still the coordinator hotspot and still owns
  too much scalar extraction.
- `keybind`, `font`, and parts of `log` still mix product semantics with raw
  Lua traversal.
- `theme` is large but mostly app-specific; it should be cleaned up, not pushed
  into the shared library.

## Validation

- `zig build test`
- `zig build test-config`
- short GUI dry run with `ZLUA_PORTABLE_TRACE=1` when verifying shared-path use

## Active Queue

### Phase 0 Boundary Lock

- [ ] `CFG-ARCH-00-01` Keep `zlua-portable` free of `zide` config semantics
- [ ] `CFG-ARCH-00-02` Add a dedicated internal config-reader layer in `src/config`
- [ ] `CFG-ARCH-00-03` Record the layer boundary in architecture docs

### Phase 1 Reader Layer

- [ ] `CFG-ARCH-01-01` Add `src/config/lua_config_reader.zig`
- [ ] `CFG-ARCH-01-02` Move keybind parsing onto the reader layer
- [ ] `CFG-ARCH-01-03` Move font parsing onto the reader layer
- [ ] `CFG-ARCH-01-04` Move common scalar reads in `lua_config_ziglua_parse.zig` onto the reader layer

### Phase 2 Parser Decoupling

- [ ] `CFG-ARCH-02-01` Make `lua_config_ziglua_parse.zig` a coordinator, not a raw stack owner
- [ ] `CFG-ARCH-02-02` Consolidate repeated string-or-list parsing behind one helper path
- [ ] `CFG-ARCH-02-03` Consolidate repeated nested-section parsing behind one helper path
- [ ] `CFG-ARCH-02-04` Remove remaining low-value direct `ziglua` field access from non-theme parsers

### Phase 3 Theme And Schema Discipline

- [ ] `CFG-ARCH-03-01` Audit `lua_config_theme_parse.zig` for helper-only extraction without moving app semantics into `zlua-portable`
- [ ] `CFG-ARCH-03-02` Define which parser helpers are truly generic enough to live in `zlua-portable`
- [ ] `CFG-ARCH-03-03` Leave app-owned schema/policy in `zide`

### Phase 4 Coverage And Drift Control

- [ ] `CFG-ARCH-04-01` Add parser-boundary tests for helper behavior and alias forms
- [ ] `CFG-ARCH-04-02` Add coverage for string-vs-list and nested-table shapes
- [ ] `CFG-ARCH-04-03` Keep architecture docs in sync after each completed migration slice

## Done Criteria

- `zlua-portable` owns only generic Lua mechanics
- `zide` has one internal config-reader layer
- domain parsers mostly express config meaning, not stack manipulation
- `lua_config_ziglua_parse.zig` acts as coordinator/facade
- parser behavior is pinned by targeted tests
