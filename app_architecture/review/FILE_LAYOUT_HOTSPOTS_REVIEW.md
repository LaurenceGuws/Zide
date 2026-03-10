# File / Folder Layout Hotspots Review

Date: 2026-03-10

Scope: repository structure smell review with focus on:
- large general folders that should become focused subdirectories
- large files that should be split into smaller/focused modules
- over-split artifact files that should be collapsed where the split no longer carries its weight

This review is about ownership clarity and navigability, not style preference alone. The standard is: make the codebase easier to reason about without introducing abstraction churn or moving performance-critical logic into fake layers.

## Method

Evidence gathered from the current tree:
- `tree ./src -L 3`
- `scc ./src --by-file --wide`
- file-count and line-count passes over `src/app`, `src/terminal`, `src/ui`, `src/editor`, and `src/config`

Reference comparison:
- `reference_repos/terminals/ghostty`
- `reference_repos/terminals/kitty`
- `reference_repos/terminals/alacritty`

## Executive Read

The user concern is valid. The codebase is no longer globally messy, but it is structurally uneven.

What is already in good shape:
- `src/terminal` now follows a real subsystem layout: `core`, `model`, `parser`, `protocol`, `input`, `kitty`, `io`, `ffi`.
- `src/ui/widgets` is materially healthier after the recent terminal widget split.
- `src/terminal/kitty` is now shaped like a real backend subsystem instead of one blob.

What is still structurally weak:
- `src/app` is the main dumping ground. It has too many flat runtime/frame/action files with mixed concerns and weak namespace boundaries.
- several very large files still act as mini-subsystems on their own
- some modularization artifacts are now too granular and should be recombined where they only add navigation cost

The highest-value cleanup is not "make everything deeply nested." It is:
1. split `src/app` into focused runtime domains
2. split the remaining true god-files
3. collapse micro-files that only exist as extraction residue

## Inventory Snapshot

Top-level `src/` pressure by file count:
- `src/app`: 148 files
- `src/terminal`: 78 files
- `src/ui`: 64 files
- `src/editor`: 21 files

Largest code hotspots by file size:
- `src/editor/editor.zig`: 2735 LOC
- `src/editor/syntax.zig`: 2555 LOC
- `src/ui/widgets/editor_widget_draw.zig`: 2219 LOC
- `src/ui/widgets/terminal_widget_draw.zig`: 2031 LOC
- `src/terminal/core/terminal_session.zig`: 1987 LOC
- `src/ui/renderer.zig`: large top-level renderer owner
- `src/ui/terminal_font.zig`: very large font/rendering owner
- `src/terminal/protocol/csi.zig`: 1838 LOC
- `src/config/lua_config_ziglua_parse.zig`: 1444 LOC
- `src/terminal/model/screen/screen.zig`: 1428 LOC

Important over-split clusters:
- `src/terminal/core/session_*.zig`:
  - `session_input.zig`: 342 LOC
  - `session_protocol.zig`: 302 LOC
  - others mostly 65-127 LOC
- `src/ui/renderer/*.zig`: many files are under 30-40 LOC
- `src/app`: many tiny runtime/frame wrappers next to a few medium-sized orchestrators

## Reference Repo Cross-Check

### Ghostty

Ghostty is the strongest structural reference for this review.

Its `src/` is domain-organized:
- `terminal` 82 files
- `apprt` 51
- `font` 47
- `renderer` 34
- `os` 33
- `cli` 23
- `config` 18
- `input` 16

Takeaway:
- Ghostty prefers focused subsystem directories over one giant mixed folder.
- Large codebases can stay low-level and still expose strong ownership boundaries.

### Kitty

Kitty keeps most code inside one main folder, with a few focused subdirectories:
- `rc` 41 files
- `layout` 8
- `options` 7
- `launcher` 7
- `fonts` 7

Takeaway:
- the user's observation is correct: kitty is much flatter
- but kitty still groups true subsystems instead of letting everything become a random drop zone
- "flat" is acceptable only if file naming and subsystem boundaries remain extremely strong

### Alacritty

`alacritty_terminal` is compact and library-shaped:
- `tty` 6
- `grid` 5
- `term` 4

Takeaway:
- small focused libraries can stay shallow and clean
- that pattern does not directly justify a large IDE app keeping one huge `src/app` flat

## Hotspot Ranking

### Tier 1: Immediate structural hotspots

#### `src/app`

Why it is a smell:
- too many unrelated runtime/frame/action files in one flat namespace
- names encode behavior indirectly (`*_runtime`, `*_frame`, `*_hooks_runtime`) instead of communicating ownership
- hard to discover the actual app lifecycle, terminal runtime loop, close-confirm flow, tab flow, and editor flow

Why this is worse than the current terminal layout:
- `src/terminal` already has clear ownership buckets
- `src/app` still looks like extraction aftermath rather than stable architecture

Recommended direction:
- split by ownership domain, not by suffix
- likely buckets:
  - `src/app/runtime/`
  - `src/app/frame/`
  - `src/app/terminal/`
  - `src/app/editor/`
  - `src/app/search/`
  - `src/app/tabs/`
  - `src/app/config/`
  - keep `src/app/modes/` as-is

Important caution:
- do not do a blind mass move
- first define the stable domain map and move one coherent slice at a time

#### `src/editor/editor.zig`

Why it is a smell:
- too large to serve as one cohesive owner
- likely mixes editing engine behavior, command handling, buffer mutation orchestration, and view-facing concerns

Recommended direction:
- keep `editor.zig` as facade/orchestrator only
- split core editing domains into a focused subdir such as:
  - `src/editor/core/`
  - or `src/editor/state/`, `src/editor/edit/`, `src/editor/history/`, `src/editor/view/`

#### `src/editor/syntax.zig`

Why it is a smell:
- large enough to likely mix registry, parse/update orchestration, highlight state, and query helpers
- this kind of file becomes fragile because every syntax-related change hits one giant owner

Recommended direction:
- split into `src/editor/syntax/`
- likely separate registry, parse pipeline, highlight/range state, and language-specific helpers

### Tier 2: High-value large-file cleanup

#### `src/terminal/core/terminal_session.zig`

Current state:
- much improved, but still large
- many recent splits moved helpers out without yet reducing the root object enough

Judgment:
- not the first layout target anymore
- still a real large-file hotspot

Recommended direction:
- avoid more arbitrary extraction shards
- next pass should be ownership-driven:
  - keep `terminal_session.zig` as root owner + API surface
  - collapse tiny helper files where the split is too fine-grained
  - move only true sub-owners to dedicated subdirectories if needed

#### `src/ui/widgets/editor_widget_draw.zig`

Why it is a smell:
- 2200+ LOC is too large for one draw module unless it is a very tight rendering pipeline
- likely mixes multiple overlay, gutter, text, cursor, selection, and scroll draw paths

Recommended direction:
- split by draw ownership, not primitive type
- likely candidates:
  - text/layout draw
  - gutter/minimap/chrome draw
  - cursor/selection overlays
  - scrollbar and decorations

#### `src/ui/widgets/terminal_widget_draw.zig`

Why it is still a smell:
- the widget input side is now acceptably factored
- draw is still monolithic compared with the new widget structure

Recommended direction:
- mirror the input cleanup
- split terminal draw into a folder or focused helpers:
  - grid/text draw
  - overlay/cursor/selection draw
  - scrollbar/chrome draw
  - kitty upload/render path only if still meaningfully separate

#### `src/ui/renderer.zig`

Why it is a smell:
- top-level owner is large while there is already a `src/ui/renderer/` directory
- this suggests a facade that still owns too much orchestration directly

Recommended direction:
- either reduce `renderer.zig` to a real facade
- or move its remaining large subsystems into `src/ui/renderer/` and keep the root file thin

#### `src/ui/terminal_font.zig`

Why it is a smell:
- very large specialized file at top-level `src/ui/`
- likely bundles shaping/cache/font fallback/policy concerns

Recommended direction:
- treat font rendering as its own subsystem
- likely `src/ui/font/` or `src/ui/text/` depending on actual ownership boundaries

#### `src/config/lua_config_ziglua_parse.zig`

Why it is a smell:
- parser/decoder-heavy file is too large and likely mixes token decode, option validation, and target-specific config mapping

Recommended direction:
- split config parsing by concern:
  - parse helpers
  - shared value coercion/validation
  - domain-specific config application

### Tier 3: Folder-level cleanup candidates

#### `src/ui/renderer/`

Judgment:
- this folder is not a dumping ground
- it is a mixed bag with one different smell: too many tiny files

Examples:
- `input_queue.zig` 9 LOC
- `key_queue.zig` 11 LOC
- `mouse_wheel.zig` 11 LOC
- `window_flags.zig` 11 LOC
- several files in the 20-30 LOC range

Recommended direction:
- collapse obvious micro-artifacts into stronger local owners
- keep the bigger modules (`terminal_glyphs`, `gl_backend`, `draw_ops`, `font_manager`) separate
- do not split this folder further before collapsing the low-signal fragments

#### `src/terminal/core/session_*.zig`

Judgment:
- this is the clearest over-split artifact zone created by the recent cleanup
- the split was useful for reducing the god object, but some files are now too small to justify separate navigation cost

Recommended direction:
- do not revert to one huge file
- do collapse some adjacent files into fewer coherent owners

Strong candidates:
- `session_queries.zig` + `session_content.zig` + `session_publication.zig`
- possibly `session_interaction.zig` + `session_clipboard.zig`

Keep separate:
- `session_protocol.zig`
- `session_input.zig`
- `session_rendering.zig`
- `session_runtime.zig`

#### `src/config/`

Judgment:
- not a folder-count problem
- more a single-file concentration problem

Recommended direction:
- likely becomes cleaner as a focused parser subdir rather than more root-level config files

### Tier 4: Probably fine, do not churn yet

#### `src/terminal/kitty/`

Judgment:
- recently split for good reasons
- structure now reflects real ownership boundaries
- do not collapse it just because file count increased

#### `src/terminal/protocol/`

Judgment:
- still has some large files, especially `csi.zig`
- but the folder model itself is sensible

#### `src/ui/widgets/`

Judgment:
- much healthier than before
- remaining problem is large draw files, not bad folder shape

## Design Principles For The Cleanup

These principles should drive the todo:

1. Split by ownership and lifecycle, not by suffix or "class type."
2. Prefer shallow-but-meaningful directories over a deep tree.
3. Large files are acceptable only when they are truly one cohesive subsystem.
4. Collapse micro-files that do not carry independent ownership.
5. Do not move files just to imitate another repo.
6. Prefer Ghostty-style subsystem grouping over Kitty-style flatness for this codebase.
7. Use Kitty as a behavior/performance reference, not as a file-layout target.

## Proposed Cleanup Order

1. `src/app` folder review and domain map
2. `src/editor/editor.zig` + `src/editor/syntax.zig` split plan
3. `src/ui/widgets/terminal_widget_draw.zig` and `src/ui/widgets/editor_widget_draw.zig`
4. `src/ui/renderer.zig` and `src/ui/terminal_font.zig`
5. collapse low-value micro-files in `src/terminal/core/session_*` and `src/ui/renderer/`
6. `src/config/lua_config_ziglua_parse.zig`

## Bottom Line

This repo is not "normally messy for low-level code." It is partially cleaned and partially still in extraction aftermath.

That is fixable.

The strongest structure to emulate from the reference repos is:
- Ghostty's subsystem grouping
- Alacritty's compact library boundaries

The pattern to avoid is:
- Kitty-style flatness without Kitty's long-established internal naming discipline

For Zide, the right move is not maximal splitting or maximal flattening. It is:
- focused top-level domains
- thinner facade files
- fewer giant owners
- fewer tiny artifact files
