# File Layout TODO

## Scope

Clean up file and folder layout for ownership clarity, navigability, and removal of split-vs-flat structural smells.

## Constraints

- Split large general folders into focused ownership domains.
- Split true god-files into cohesive submodules.
- Collapse extraction-residue micro-files only when their ownership boundary is fake.
- Avoid bulk moves without an explicit domain map and per-slice validation.
- Extraction-only rules apply unless a task explicitly scopes behavior changes.

## Context

- `app_architecture/review/archive/FILE_LAYOUT_HOTSPOTS_REVIEW.md`
- `app_architecture/review/archive/SRC_APP_DOMAIN_MAP.md`
- `docs/todo/terminal/modularization.md`
- `docs/todo/ui/widget_modularization.md`
- `docs/todo/editor/modularization.md`
- `docs/todo/ui/renderer.md`

## Validation

- Per slice: `zig build test`, `zig build check-app-imports`, `zig build check-editor-imports`, `zig build check-input-imports`, `zig build -Dmode=terminal -Doptimize=ReleaseFast`

## Strict Cleanup Queue

- [x] `FL-APP-01` Define a stable `src/app` domain map and move one slice at a time
- [ ] `FL-ED-01` Split `src/editor/editor.zig` into focused editor subsystem modules
- [x] `FL-ED-02` Split `src/editor/syntax.zig` into focused syntax modules
- [x] `FL-UI-01` Split `terminal_widget_draw.zig` by draw ownership
- [x] `FL-UI-02` Split `editor_widget_draw.zig` by draw ownership
- [x] `FL-UI-03` Thin `src/ui/renderer.zig` against `src/ui/renderer/`
- [x] `FL-UI-04` Move `terminal_font.zig` under a focused font/text subsystem
- [x] `FL-TERM-01` Collapse low-value `session_*` micro-files into fewer coherent owners
- [x] `FL-UI-05` Collapse low-value `src/ui/renderer` micro-files
- [x] `FL-CFG-01` Split `lua_config_ziglua_parse.zig` by parser, validation, and domain mapping concerns
- [x] `FL-R-01` Re-rank remaining hotspots and hand terminal-heavy owners back to architecture work

## Phases

### Phase 0 Structural Baseline

- [x] `FL-0-01` Record the file-layout hotspot review and reference comparisons
- [x] `FL-0-02` Adopt file-layout cleanup as an active architecture track

### Phase 1 Folder-Level Dumping Ground Cleanup

- [x] `FL-APP-01` Define a stable domain map for `src/app`
- [x] `FL-APP-02` Move terminal-owned app runtime files under `src/app/terminal/`
  Completed through staged terminal subtree moves with validation passing.
- [x] `FL-APP-03` Move editor, search, and tab runtime files under focused app subtrees
  Completed through `src/app/search/`, `src/app/editor/`, and `src/app/tabs/`.

### Phase 2 Large File Splits

- [ ] `FL-ED-01` Split `src/editor/editor.zig` into focused editor subsystem modules
  In progress. Search/highlight, selection state, navigation, and edit operations have already been extracted.
- [x] `FL-ED-02` Split `src/editor/syntax.zig` into a focused syntax subdir
- [x] `FL-UI-01` Split terminal widget draw ownership
- [x] `FL-UI-02` Split editor widget draw ownership
- [x] `FL-UI-03` Thin the root renderer around focused renderer modules
- [x] `FL-UI-04` Move terminal font ownership into a focused font subsystem
  Completed through cache, fallback, special glyph, shaping, and system fallback slices.
- [x] `FL-CFG-01` Split `lua_config_ziglua_parse.zig`
  Completed through theme, keybind, log, font, and runtime parser slices; the root parser now acts as a facade.

### Phase 3 Over-Split Artifact Collapse

- [x] `FL-TERM-01` Collapse low-value `session_*` micro-files
  Completed by merging clipboard and publication helpers into stronger owners.
- [x] `FL-UI-05` Collapse low-value renderer micro-files
  Completed by merging input, clipboard, window-flag, and window-metrics wrappers into stronger owners.

### Phase 4 Verification and Drift Control

- [x] `FL-R-01` Re-rank remaining hotspots after the major cleanup
  Remaining heavy files are now terminal-core owned, so this lane is mostly exhausted.
- [ ] `FL-V-01` Validate build and import checks after each structural slice
- [ ] `FL-V-02` Update owning architecture docs after each completed slice
