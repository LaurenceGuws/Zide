# App Hygiene Cleanup

## Scope

Drive an app-level architecture cleanup campaign focused on dependency
boundaries, build-graph scope, platform/helper residue, and app-shell
coordination seams.

This is not the terminal-core campaign. It is the parallel app/platform/build
lane that should make the host shell, build surfaces, and dependency contracts
look deliberate rather than transitional.

## Goal

Make Zide's app-level architecture read as:

- dependency-disciplined
- reference-grade
- SDL3-native instead of workaround-shaped
- explicit about repo boundaries
- free of stale helper seams that survive only from migration history

## Current Findings

High-confidence hotspots from the initial branch investigation:

1. `src/platform/compositor.zig`
   - deleted on 2026-04-01
   - it was pre-SDL3 scaling-workaround residue
   - `getWaylandScale()` was unused
   - compositor detection was unused
   - the only live use was the no-op Wayland branch in
     `src/platform/mouse_state.zig`

2. `build_system/ide_graph.zig`
   - mixes build planning with operator workflow glue
   - currently carries tests, gates, reports, packaging, Windows shell
     extension work, and `grammar-update` proxying
   - likely too broad to be the right build-graph center
   - 2026-04-01 progress: workflow glue for Windows shell extension, mode
     gates/bundles, and `grammar-update` moved under
     `build_system/ide_workflow.zig`

3. `src/editor/tree_sitter_assets.zig`
   - the `zide-tree-sitter` extraction was directionally correct
   - the consumer contract is still not fully clean
   - sibling-repo path probing remains in live code

4. App orchestration centers
   - `src/app/init_runtime.zig`
   - `src/app/update_frame_hooks_runtime.zig`
   - `src/app/post_preinput_hooks_runtime.zig`
   - `src/app/terminal/terminal_frame_pacing_runtime.zig`
   - current modularization may still hide app-level coordination gravity

5. Build/link fallback residue
   - `build_system/target_config.zig` still needs scrutiny for over-broad
     responsibility
   - hardcoded FreeType/HarfBuzz include fallback baggage was removed on
     2026-04-01 in favor of explicit dependency-policy enforcement

## Broad Judgment

The current app-level problem is not that dependency policy is weak.
The dependency model itself is mostly stronger now:

- Zig package-managed app/library stack
- explicit target dependency policy
- justified external reusable boundaries for `zlua-portable`
- justified producer/tooling split for `zide-tree-sitter`

The drag is elsewhere:

- overgrown build-graph responsibility
- unfinished repo-boundary cleanup on the consumer side
- app runtime hook/callback sprawl
- SDL3-era migration residue still sitting in `src/platform/`

## Repo Boundary Rule

Only split code or assets into a dedicated repo when all of the following are
true:

- reusable outside Zide
- stable consumer contract exists
- independent release cadence is useful
- ownership becomes clearer instead of merely smaller
- product/runtime semantics stay in `zide`

Current judgment:

- `zlua-portable`: justified
- `zide-tree-sitter`: justified, but consumer contract cleanup still required
- more app/platform/build repo splits: not justified by default

## Initial Milestones

### AH-01 SDL3 Residue Purge

Focus:

- audit `src/platform/` for helper seams that no longer make sense after SDL3
- delete or drastically reduce `src/platform/compositor.zig`
- identify any other app/platform behavior still shaped around old backend
  assumptions

Done when:

- compositor-specific fallback helpers are removed or reduced to only live
  platform truth
- platform helpers read as current SDL/platform integration, not migration
  leftovers

Progress note, 2026-04-01:

- `src/platform/compositor.zig` is deleted
- `src/platform/mouse_state.zig` no longer carries the dead Wayland
  compositor check
- `src/ui/renderer.zig` no longer imports compositor-only type residue

### AH-02 Tree-sitter Consumer Contract Hardening

Focus:

- remove sibling-repo layout assumptions from live `zide` consumer code
- keep `zide-tree-sitter` as the producer/tooling repo
- make `zide` consume a stable asset contract rather than path heuristics

Done when:

- `src/editor/tree_sitter_assets.zig` no longer probes sibling-repo paths as a
  normal consumer behavior
- build/runtime flows point to explicit asset roots or installed artifacts
- local co-development remains possible without leaking repo-layout knowledge
  through the app

Progress note, 2026-04-01:

- runtime consumer path probing for `../zide-tree-sitter/assets` is removed
  from `src/editor/tree_sitter_assets.zig`
- live asset lookup now prefers explicit asset roots, installed user assets,
  and bundled repo assets only
- maintainer-side `zig build grammar-update` proxy now routes through
  `tools/editor/tree_sitter/grammar_update_proxy.sh` instead of embedding
  sibling-repo choreography inline in `build_system/ide_graph.zig`

### AH-03 Build Graph Scope Control

Focus:

- separate true build/dependency policy from repo workflow glue
- audit `build_system/ide_graph.zig`, `build_system/bootstrap_graph.zig`, and
  `build_system/target_config.zig`
- keep the Zig build graph strong, but stop using it as a dumping ground for
  every maintainer workflow

Done when:

- build policy remains explicit and enforceable
- workflow/report/task-runner concerns are either narrowed or moved behind
  clearer tooling boundaries
- build graph ownership feels deliberate instead of accumulated

Progress note, 2026-04-01:

- workflow-heavy steps for Windows shell extension build, mode gate/bundle
  orchestration, and grammar-update proxying now live in
  `build_system/ide_workflow.zig`
- `build_system/ide_graph.zig` is narrower and reads more as artifact/test
  planning than repo-operations choreography

### AH-04 App Orchestration Honesty

Focus:

- inspect the `*_hooks_runtime.zig` / `*_frame_runtime.zig` lattice
- determine which files are real policy seams versus app-level wrapper theater
- shrink or regroup broad callback matrices where the composition model is no
  longer honest

Done when:

- the app shell has fewer fake centers
- runtime composition reads as intentional policy ownership, not callback
  forwarding scaffolding

Progress note, 2026-04-01:

- `src/app/post_preinput_hooks_runtime.zig` now centralizes repeated UI-scale
  and window-chrome policy in local helpers instead of duplicating the same
  closure-level logic across multiple hook sites
- this is an extraction-only narrowing step: behavior is unchanged, but the
  post-preinput frame path now reads more as orchestration and less as inline
  policy sprawl
- `src/app/update_frame_hooks_runtime.zig` now moves the largest interactive
  frame callback bodies into named local helpers for tab-drag and active-view
  dispatch
- this keeps the hook contract intact while reducing closure-wall density in
  the main app update path
- the update prelude side of the same file now lifts font-sample handling,
  widget input sync, reload-notice ticking, focus routing, and input snapshot
  bookkeeping into named helpers
- that keeps the prelude callback contract intact while making the front half
  of the app update path read like explicit policy steps instead of inline
  callback shards
- `src/app/pre_input_shortcut_hooks_runtime.zig` now centralizes reload-config,
  reload-notice, terminal-close-confirm, layout, redraw, and metric side
  effects in named helpers instead of repeating them inside hook structs
- this keeps shortcut behavior fixed while reducing another dense callback
  policy cluster in the app update lane
- `src/app/init_runtime.zig` now centralizes logger config, terminal cursor
  style resolution, and initial tab-bar/ui-scale application in named helpers
- this makes bootstrapping read more like explicit initialization phases and
  less like one long inline setup slab
- the same init path now also separates startup perf/env capture, terminal
  bootstrap resource resolution, and mode-adapter creation from the main state
  literal
- this reduces the amount of policy and allocation choreography mixed directly
  into `initWithMode`
- `src/app/frame_render_idle_hooks_runtime.zig` now centralizes render-idle
  layout, tab-bar-width, modal-state, and draw dispatch policy in named
  helpers instead of inline hook bodies
- this keeps render behavior unchanged while making the idle/render glue read
  more like orchestration than callback plumbing
- `src/app/draw_frame_runtime.zig` now splits the draw pipeline into named
  phases for main-surface draw, pending editor-highlight redraw, live-smoke
  capture arming, and completed-present handling
- this makes the draw path easier to reason about without changing frame
  behavior or present-side effects
- `src/app/frame_render_idle_runtime.zig` now separates redraw handling, idle
  handling, and shared latency/perf logging into named helpers
- this makes the frame pacing loop read as explicit control-flow phases instead
  of one long mixed redraw/idle slab

## Investigation Follow-up

Next investigation pass should scrutinize these findings against:

- official dependency documentation
- the populated `dev_references` corpus in the main `zide` clone
- reference build/platform/repo-boundary patterns from strongest peers

That second pass should either strengthen or overturn the current judgments
before major cuts begin.
