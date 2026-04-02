# Wayland Present Implementation Plan

## Purpose

Turn the present-path redesign decision from
[WAYLAND_PRESENT_TECHNICAL_WRITEUP.md](../../../app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md)
into an execution plan with:

- explicit phase boundaries
- validation gates
- rollback boundaries
- clear ownership rules

This plan is the implementation authority for the renderer-present redesign on
`main`.

Status note, 2026-03-14:

- The initial native present-path redesign is effectively landed.
- This doc remains the architectural authority for the rewritten path, but it
  is no longer the primary day-to-day invention queue.
- Active work has shifted to post-rewrite bug hunting, compatibility hardening,
  and quality validation on top of this design.
- `rain` remains explicitly out of the active validation matrix until future
  special-character / visual-polish work.

Status note, 2026-03-30:

- The scene-target path is still the live authority on `main`, but rendering-correctness cleanup is active again because the old `ascii-rain` investigation exposed incomplete migration seams that still matter on the native host.
- Accepted recent fixes on top of the landed path:
  - canonical per-frame terminal cell geometry is now the authority for terminal-space consumers under fractional scale
  - duplicate focused block-cursor glyph drawing is removed
  - focused `.bar` cursor height now uses logical cell geometry and visually matches row text at both `render_scale=1.00` and `render_scale=1.65`
- Current open bug in this queue:
  - some idle frames clear and submit the authoritative scene target without blitting the retained terminal texture (`terminal_texture_draws=0`)
  - input restores the foreground because a real redraw reintroduces the terminal blit
  - this is currently treated as an incomplete migration bug, not a text/glyph bug
- Current `ascii-rain` framing correction:
  - the observed repro boundary is now known: `ascii-rain` itself switches into a denser/faster mode at `COLS >= 100`
  - that workload change is what exposes the remaining renderer bug in Zide
  - the renderer-side root cause for the live rain failure is still unknown
  - do not treat `99 -> 100` columns as proof of an arbitrary renderer threshold by itself

Status note, 2026-04-02:

- War 2 present-invariant hardening is now active on `main`.
- Landed correctness slices:
  - terminal scene submission now records terminal-surface blit proof and
    generation
  - publication retirement now requires renderer-proven submitted-scene truth
  - weak widget-local feedback fields no longer act as retirement authority
- This changes the live bug read:
  - if the terminal still disappears on an idle frame, that is now much more
    clearly a real scene-composition omission bug
  - it is no longer explainable as publication retirement trusting weak widget
    feedback

Authority note:

- This file is the current architectural authority for the landed scene-owned
  present path.
- Historical debug evidence and reference digging belong in
  `docs/research/terminal/wayland_present/` and relevant review
  docs, not in this plan once they stop changing the ownership model.
- Landed rollout notes now live in
  [WAYLAND_PRESENT_ROLLOUT_2026-03.md](../../review/archive/terminal/WAYLAND_PRESENT_ROLLOUT_2026-03.md),
  not inline in this plan.

Shared redraw/publication/present semantic authority lives in:

- `app_architecture/terminal/rendering/RENDER_PUBLICATION_CONTRACT.md`

## Design Summary

The chosen direction is a hybrid renderer architecture:

- keep narrow retained widget-local targets where they already pay off
- add a renderer-owned authoritative scene target
- treat the default framebuffer as a one-frame present sink only

What does **not** change in this plan:

- terminal core still owns publication truth
- widgets still own content consumption and local upload planning
- Wayland/EGL investigation logs stay issue-scoped, not permanently verbose

What **does** change:

- renderer becomes the owner of final scene truth before present
- presentation acknowledgement is defined against renderer-owned scene
  submission, not implicit default-framebuffer behavior
- default-framebuffer composition stops being an architectural dependency

## Current Cleanup Focus

The highest-value remaining correctness item in this queue is:

- retained terminal content must still be presented on any frame that clears and submits the authoritative scene target

The current native bug signature is:

- idle frame
- scene target cleared
- swap succeeds
- terminal texture blit omitted
- foreground appears lost until input triggers a redraw

That bug should be treated as a migration-completeness failure in final scene composition ownership, not as a terminal text-quality issue.

The archived `ascii-rain` lane should now be read with one constraint:

- `ascii-rain` is still useful as a stressor, but any comparison across widths must account for its own workload-mode switch at `COLS >= 100`
- when the width changes across that boundary, we learn what workload breaks Zide, not yet why it breaks Zide

Investigation tooling note:

- the current rain lane now has a useful `Scroll Lock` capture trigger for narrow console-only frame markers and short burst traces
- keep that tool for the current bug, but add a future follow-up to generalize it into a reusable investigation capture utility rather than leaving it terminal/rain-specific forever

## Constraints

1. No compatibility sludge.
   If a present path is known-bad and the replacement is ready, remove it
   rather than keeping two long-lived ownership models.

2. No behavior changes during extraction-only phases.
   Early slices should establish boundaries and observability first.

3. Validation must remain local and replay-backed where possible.

4. Partial widget-local damage remains a performance goal.
   The redesign is not permission to redraw the world every frame.

5. Resize, drawable-size changes, and display/scale hops are hard invalidation
   boundaries for renderer-owned scene state.

## Target Ownership Model

### Terminal core

Owns:

- publication generations
- render-cache truth
- damage / dirty semantics

Does not own:

- scene composition
- present timing
- default-framebuffer semantics

### Widget layer

Owns:

- local retained targets such as terminal/editor textures
- upload planning from published snapshots into widget-local targets
- local dirty coalescing

Does not own:

- final frame truth
- swap semantics
- scene present acknowledgement

### Renderer

Owns:

- authoritative scene target
- final frame graph
- scene invalidation policy
- present submission
- presentation diagnostics

Does not infer correctness from:

- preserved default-framebuffer contents
- post-swap default-buffer reuse

## Phased Execution Plan

### Phase 0: Lock the Contract and Tooling

Goal:

- make the new path executable on paper before touching live composition logic

Changes:

- add a small renderer-present contract section to the main renderer docs if
  needed
- keep startup SDL/EGL contract logging
- keep suspicion-driven present probes available but disabled by default
- ensure `.zide.lua` remains on a quiet baseline

Validation gate:

- `zig build test --summary all`
- `zig build -Dmode=terminal -Doptimize=ReleaseFast`
- startup still logs the SDL/EGL contract when those tags are enabled

Rollback boundary:

- doc + logging only

### Phase 1: Introduce Scene-Target Ownership Without Changing Frame Semantics

Goal:

- add a renderer-owned scene target abstraction without making it authoritative
  yet

Changes:

- introduce a dedicated renderer scene-target object/lifecycle
- define resize/recreate rules from drawable pixel size
- define explicit invalidation reasons:
  - drawable resize
  - display hop
  - scale change
  - target recreation failure
- keep current direct-default composition behavior as the active path during
  this phase

Key rule:

- this is a boundary-establishing phase only; no correctness claims yet

Validation gate:

- builds/tests pass
- no visual regression in normal startup and resize behavior
- scene target can be created/destroyed/recreated without affecting the current
  present path

Rollback boundary:

- renderer-local, no widget/publication ownership changes

### Phase 2: Route Final UI Composition Into the Scene Target

Goal:

- make scene composition real while preserving existing widget-local retained
  targets

Changes:

- draw the full frame into the renderer-owned scene target
- keep terminal/editor retained textures unchanged as inputs to scene
  composition
- define one final scene-to-default present draw immediately before swap
- remove any reliance on default framebuffer as retained intermediate truth

Key rule:

- widget-local targets remain narrow and incremental
- the scene target is the authoritative frame image

Validation gate:

- normal UI draws correctly
- resize / display migration invalidates and rebuilds scene state cleanly
- old `wiki_life` fix remains intact
- raw Wayland repro no longer depends on direct-default composition to be
  correct

Rollback boundary:

- renderer composition path only; terminal-core publication untouched

### Phase 3: Rebind Present Acknowledgement to Renderer Scene Truth

Goal:

- stop letting presentation retirement depend on ambiguous default-framebuffer
  semantics

Changes:

- define present acknowledgement against renderer-owned scene submission
- make the renderer the authority for "scene image N was submitted"
- keep widget-local upload completion separate from present acknowledgement

Key rule:

- widget texture state is an input to the scene, not the definition of present
  truth

Validation gate:

- no generation regressions on presentation ack
- stale/out-of-order ack remains optimization-only
- no reintroduction of the `wiki_life` publication seam

Rollback boundary:

- scene/present ownership only

### Phase 4: Remove the Legacy Direct-Default Main Path

Goal:

- cut the old ownership model once the new path is validated

Changes:

- remove the old direct-default main composition path
- keep only targeted debug/probe surfaces that still help validate present
  behavior
- simplify renderer logic around swap/present assumptions

Validation gate:

- builds/tests pass
- Wayland startup and resize behavior remain correct
- old `nvim` ghost lane is materially improved or eliminated on the new path

Rollback boundary:

- this is the first irreversible architectural cut; do not take it until the
  scene path is already the authoritative live path

## Validation Matrix

Every phase should be checked against:

1. Build/test baseline
   - `zig build test --summary all`
   - `zig build -Dmode=terminal -Doptimize=ReleaseFast`

2. Static startup contract
   - drawable/window metrics on startup and resize

3. Repro lanes
   - `wiki_life` in `nvim` terminal buffer must stay fixed
   - old `nvim` text-buffer cursorline scrolling ghost must be rechecked

4. Structural events
   - resize
   - display hop
   - scale change
   - maximize / restore

## Sequencing Risks

### Risk 1: Turning the scene target into a full-redraw tax

Mitigation:

- keep widget-local retained targets intact
- do not move terminal/editor upload ownership into the renderer

### Risk 2: Mixing scene truth and widget upload truth again

Mitigation:

- define present acknowledgement only after the renderer-owned scene boundary is
  explicit

### Risk 3: Repeating the broken whole-frame offscreen experiment

Mitigation:

- do not revive ad hoc env-gated whole-frame composition
- build the new path as the intended renderer architecture, not as a sidecar
  fallback

### Risk 4: Resize/display invalidation bugs

Mitigation:

- treat drawable-size/display/scale changes as unconditional scene invalidation
  boundaries from the start

## Historical Rollout Notes

Phase-by-phase landed-shape notes and the first implementation slice now live
in
[WAYLAND_PRESENT_ROLLOUT_2026-03.md](../../review/archive/terminal/WAYLAND_PRESENT_ROLLOUT_2026-03.md).

## Exit Criteria

This plan is complete when:

- the renderer-owned scene target is the authoritative frame image
- the default framebuffer is only a one-frame present sink
- widget-local retained targets still preserve narrow partial-update value
- the old Wayland present seam no longer defines correctness
