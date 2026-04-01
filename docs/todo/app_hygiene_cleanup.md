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

## Build Maturity Direction

This lane is not only about deleting old seams. It is also about maturing the
build surface so it reads like a serious product system.

Reference pressure from Ghostty, Bun, TigerBeetle, and Neovim suggests the
next bar is:

- top-level `build.zig` as composition, not implementation sludge
- build options as explicit product policy, not incidental flags
- named steps as a stable operator surface
- reusable build-side modules for shared artifact/report/tooling patterns
- target/platform constraints made deliberate and inspectable
- room for codegen, packaging, docs, reports, and test lanes without turning
  the root graph into a dump

The practical rule for upcoming work:

- keep deleting stale seams
- but prefer replacements that make the build surface stronger, more legible,
  and more reference-grade than it was before

Progress note, 2026-04-02:

- the build system now exposes `zig build report-build-surface`
- this gives the repo an explicit operator-facing map of the build step
  taxonomy instead of expecting contributors to infer it from scattered
  planner modules
- the build system now also exposes `zig build report-build-policy`
- this gives operators a direct summary of supported `-D...` knobs and current
  hard constraints instead of forcing that knowledge to live only in source
- the operator-facing step taxonomy now lives in `build_system/step_catalog.zig`
  instead of only as a hand-maintained report string block
- this reduces drift risk between the real build surface and the reported build
  surface
- the build policy surface now lives in `build_system/policy_catalog.zig`
  instead of only as a hand-maintained report body
- this gives the build system shared data for supported options, hard
  constraints, and operator intent
- build profile metadata now lives in `build_system/profile_catalog.zig`
  instead of only in `report-build-profiles`
- the build system now exposes `zig build report-build-dependencies` to explain
  dependency intent per profile instead of leaving that matrix implicit
- renderer/backend and platform capability assumptions now live in
  `build_system/platform_capabilities.zig`
- the build system now exposes `zig build report-build-platform` so target
  graphics/ffi assumptions are inspectable instead of scattered

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
- extended FFI/test-harness/check/manual-smoke planning now lives in
  `build_system/ide_extended_artifacts.zig`
- `build_system/ide_graph.zig` is now further reduced to top-level composition
  of build-side planners instead of directly owning every extended artifact
  band itself
- bootstrap option parsing, dependency resolution, and build-report
  registration now live under `build_system/bootstrap_setup.zig`
- `build_system/bootstrap_graph.zig` is narrower and reads more as bootstrap
  composition than as a single mixed initializer
- `build_system/step_reports.zig` now routes all build report/check executables
  through shared report-tool helpers instead of repeating near-identical
  compile/run wiring per report
- this keeps step names and behavior intact while removing another build-side
  duplication slab from the justified non-`src` surface
- compile-step linker setup now routes through
  `build_system/compile_utils.zig` instead of being redefined as no-op stubs in
  multiple build modules
- `build_system/step_utils.zig`, `build_system/step_reports.zig`,
  `build_system/target_factory.zig`, and `build_system/dependency_resolver.zig`
  now share one build-owned compile utility seam instead of carrying repeated
  local linker boilerplate
- runtime app executable construction and SDL/libc test artifact construction
  no longer share one broad build factory file
- `build_system/app_target_factory.zig` now owns runtime app entrypoint
  creation, while `build_system/test_target_factory.zig` owns SDL/libc test
  artifact construction
- Lua metadata tool wiring now lives under `build_system/tooling_graph.zig`
  instead of being inlined directly in `build_system/build_entry.zig`
- `build_system/build_entry.zig` is now closer to a pure top-level build
  composition entrypoint

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
- `src/app/reload_config_runtime.zig` now centralizes logger config, theme
  application, font reload handling, terminal cursor resolution, and shell-icon
  reload handling in named helpers
- this makes config reload read more like staged policy application and less
  like a long mutation script
- duplicated config/runtime policy shared by init and reload now lives in
  `src/app/config_runtime_common.zig`
- this removes parallel copies of terminal path resolution, logger setup, and
  terminal cursor-style resolution from the two main config entrypoints
- duplicated tab-bar-width and UI-scale-for-state policy now lives under
  `src/app/ui_layout_runtime.zig`
- this removes another repeated app-shell seam from init, post-preinput,
  pre-input shortcut, and render-idle hook paths
- `src/app/new_terminal_runtime.zig` now separates initial grid calculation,
  workspace launch, single-session launch, and shared post-start terminal sync
- this makes terminal startup read more like explicit app policy phases and
  less like one large branch-heavy launch script
- repo-root test wrapper Zig files were removed and relocated under `tests/`
  with build-graph references updated accordingly
- this tightens the repo rule that non-`src` Zig must clearly justify itself as
  build/test/tooling surface instead of leaking ad hoc entrypoints into root
- Windows packaging identity Zig data was moved from `tools/packaging/windows/`
  into `build_system/` because it is build-only contract data, not a tooling
  entrypoint
- this continues the rule that non-`src` Zig files must defend their location
  by ownership, not habit
- the standalone Zig redraw fixture source was moved from `fixtures/` into
  `tests/fixtures/` because it is test authority data, not a generic repo
  fixture or product surface
- this keeps non-`src` Zig closer to the ownership boundary that actually
  justifies it
- build-internal Zig report/check entrypoints were moved from
  `tools/build_tools/` into `build_system/`
- this keeps `tools/` for genuine tooling surfaces and `build_system/` for
  build-owned Zig, reducing another non-`src` location leak
- the Zig manual GUI smoke harness was moved from `tools/build_tools/smokes/`
  into `tests/manual/` because it is test authority, not a general tool
- after this cut, the remaining Zig file in `tools/` is the actual standalone
  metadata generator, which cleanly defends its location

## Investigation Follow-up

Next investigation pass should scrutinize these findings against:

- official dependency documentation
- the populated `dev_references` corpus in the main `zide` clone
- reference build/platform/repo-boundary patterns from strongest peers

That second pass should either strengthen or overturn the current judgments
before major cuts begin.
