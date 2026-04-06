# Metal Backend Implementation

Purpose: make the live Metal lane readable as a reference implementation of the
shared renderer backend contract, not as scattered bring-up history.

This doc is the implementation authority for:

- current Metal backend structure
- current ownership truth
- frame/draw/text/present behavior on the Metal lane
- contributor workflow and debugging guidance for Metal work

This is not the macOS host-contract doc. That remains:

- `app_architecture/platform/macos/RENDER_BACKEND.md`
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

## Why This Doc Exists

Metal is currently paused for live validation, but it is still a required
reference implementation for the renderer backend campaign.

If the Metal lane is under-documented, the repo quietly drifts back toward:

- GL-shaped shared assumptions
- "Vulkan later" fiction without backend closure
- backend contract work that only proves Linux GL convenience

This doc exists to stop that drift.

## Role In The Backend Campaign

Metal currently serves three roles:

1. prove that a non-GL backend can satisfy the renderer at all
2. pressure the shared contract so `Renderer` does not become a disguised GL
   implementation center
3. keep future Vulkan/mobile pressure honest by forcing explicit frame and
   drawable ownership

The standard is not "keep Metal limping forward."

The standard is:

- make Metal understandable as one implementation of the shared contract

## Current Code Map

Primary backend centers:

- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer/metal_runtime_state.zig`
- `src/ui/renderer/metal_frame_runtime.zig`

Primary host centers:

- `src/platform/macos_host.zig`
- `src/platform/macos_metal_host.zig`

Shared-contract pressure points:

- `src/ui/renderer.zig`
- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer/capability_contract.zig`
- `src/ui/renderer/presentable_contract.zig`
- `src/ui/renderer/surface_draw.zig`

Shared widget/runtime areas where Metal behavior matters:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_draw_grid.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
- `src/ui/renderer/text_runtime.zig`

## Backend Object Model

The live Metal lane has four real ownership centers:

1. host attachment
   - Cocoa/SDL bridge
   - Metal view/layer attachment
   - drawable size truth

2. backend runtime
   - device
   - command queue
   - backend context
   - frame slot
   - queued surface draws
   - preview/diagnostic state

3. frame lifecycle
   - frame begin
   - drawable/target acquisition
   - work encoding
   - present registration
   - transient release

4. draw/present/text work
   - `SurfaceDraw` replay
   - atlas/image work
   - terminal text/sampled text
   - presentables/snapshots

Important current truth:

- some backend-native state still lives under the shared renderer host
- that is transitional, not a license to widen the pattern

## Current Frame Story

Metal is currently the clearest example of an explicit frame backend.

Current behavior:

- work is accumulated and submitted at frame end
- drawables are acquired late
- present is part of command-buffer submission
- transient frame state is intentionally short-lived

This is useful pressure on the shared contract.

It is also one of the remaining contract contradictions, because OpenGL still
does not satisfy the same submission story with the same internal shape.

When touching frame code, prefer:

- making shared frame ownership more honest

Do not prefer:

- making Metal more GL-like to avoid contract work

## Current Draw Story

Metal currently realizes draw intent through:

1. queued `SurfaceDraw` replay
2. terminal/sampled text submission
3. presentable/snapshot drawing

Shared-code rule:

- product code should express draw intent once
- backend-specific queueing/replay is an implementation detail

If Metal requires a second public shared route for the same semantic draw
operation, assume the contract is wrong first.

## Current Text And Atlas Story

Metal text is one of the most informative backend lanes because it exposed
several renderer contract weaknesses early.

Current truths:

- planned text mode can be `metal_texture_atlas`
- sampled text and terminal cell runs exist as real backend work
- some fallback machinery still exists because the shared contract is not yet
  fully collapsed

Contributor rule:

- do not add another shared public route just because Metal text is harder
- hide backend-specific mechanics behind the same public contract or delete the
  duplicate seam if it is no longer needed

## Current Presentable Story

Metal is a real participant in the shared presentable vocabulary.

But current truth is still uneven:

- the shared presentable contract exists
- Metal snapshot/direct presentable behavior is real
- richer retained-presentable behavior is still historically more GL-shaped

So presentable naming is better than it used to be, but presentable ownership
is not finished.

Judge presentable work by one question:

- does this reduce GL-shaped assumptions in shared code

## Contributor Workflow

When reopening Metal work, read these first:

1. `docs/AGENT_HANDOFF.md`
2. `docs/todo/ui/renderer.md`
3. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
4. `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
5. `app_architecture/platform/macos/RENDER_BACKEND.md`
6. this file

Then work in this order:

1. identify the shared contract seam involved
2. classify the problem as:
   - host/lifecycle truth
   - honest backend implementation work
   - shared renderer contract weakness
3. only then patch code

### Do

- keep Metal mechanics behind `metal_backend.zig` or backend-owned helpers
- use Metal as pressure against GL-shaped shared assumptions
- update current-state docs when a Metal contradiction teaches something real
- delete duplicate shared paths when they stop being necessary

### Do Not

- add new Metal-only shared renderer methods casually
- widen renderer-root backend state because it is "convenient for now"
- preserve duplicate shared routes purely as safety blankets
- let paused live validation become an excuse for stale docs

## Debugging Guidance

Classify Metal bugs before patching:

1. host bug
   - view/layer setup
   - drawable size / scale
   - activation / replacement

2. backend frame bug
   - frame acquisition
   - queued replay
   - present timing

3. shared contract bug
   - duplicate draw routes
   - GL-shaped presentable assumption
   - backend-handle leakage

4. text/atlas bug
   - atlas readiness
   - sampled text fallback
   - terminal cell run behavior

Do not default to "Metal needs another special case."

## Current Metal-Specific Risks

The Metal lane still provides useful pressure because these are not fully
solved:

1. frame submission semantics remain more explicit than GL
2. presentable ownership is still not fully backend-neutral
3. backend runtime storage is still too visible under `Renderer`
4. text/fallback behavior still carries contract scrutiny value

These are reasons to keep the docs rich, not reasons to avoid them.

## What Counts As Good Metal Progress

Good progress:

- Metal becomes easier to reason about without adding Metal-shaped shared APIs
- one more duplicated shared route disappears
- one more renderer-root-owned backend detail moves behind a backend seam
- current-state docs become more honest

Bad progress:

- another Metal-only helper appears on `Renderer`
- another shared path branches on Metal because the contract stayed weak
- a local Metal fix lands without updating the doc authority it disproved

## Why This Matters Beyond macOS

Metal is not just a platform lane.

It is the current proof that:

- explicit frame/drawable ownership matters
- a non-GL backend can satisfy the renderer
- future Vulkan/mobile pressure is not imaginary

If this backend becomes under-documented, the repo will drift back toward
desktop-GL authority without saying so.
