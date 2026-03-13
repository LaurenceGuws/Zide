# Wayland Present Implementation Plan

## Purpose

Turn the present-path redesign decision from
[WAYLAND_PRESENT_TECHNICAL_WRITEUP.md](/home/home/personal/zide/app_architecture/terminal/WAYLAND_PRESENT_TECHNICAL_WRITEUP.md)
into an execution plan with:

- explicit phase boundaries
- validation gates
- rollback boundaries
- clear ownership rules

This plan is the implementation authority for the renderer-present redesign on
`main`.

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

Current status:

- first slice landed in `src/ui/renderer.zig`
- renderer now owns explicit scene-target state plus contract snapshotting for:
  - logical size
  - drawable size
  - display index
  - render scale
- those boundaries now invalidate/destroy stale scene-target state without
  changing the active direct-default composition path yet

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
   - SDL GL realized attrs
   - SDL EGL contract
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

## First Implementation Slice

The first code slice should be:

- introduce renderer-owned scene-target lifecycle and invalidation bookkeeping
- do not change the active main composition path yet
- keep the slice renderer-local and behavior-neutral

That gives the next phase a clean place to land without mixing design work with
present-path semantics in the same patch.

## Exit Criteria

This plan is complete when:

- the renderer-owned scene target is the authoritative frame image
- the default framebuffer is only a one-frame present sink
- widget-local retained targets still preserve narrow partial-update value
- the old Wayland present seam no longer defines correctness
