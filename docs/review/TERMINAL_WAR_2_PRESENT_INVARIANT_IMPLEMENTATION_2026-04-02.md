# Terminal War 2 Present Invariant Implementation 2026-04-02

## Purpose

Turn the War 2 opening decision into an implementation-grade contract for the
first code cuts.

This document defines:

- the exact native terminal present acknowledgement invariant
- the current failure path through live code
- the boundary responsibilities that must change
- the first concrete implementation slices

It is not a generic present brainstorm.
It is the authority for the first War 2 correctness campaign.

## Required Invariant

Native terminal presentation may only be acknowledged for generation `G` when
all of the following are true:

1. frame submission succeeded
2. the submitted renderer-owned scene was the scene actually presented
3. if that scene frame cleared the authoritative scene target, the visible
   terminal retained surface was re-blitted into that scene before submit
4. that re-blitted retained surface represented generation `G`

Short version:

- acknowledge only submitted scene truth
- never acknowledge widget-local upload truth by itself

## Current Invalid Invariant

Today the retirement gate is weaker:

- `submission.succeeded`
- and `feedback.texture_updated || presented.dirty == .none`

That is not enough.

It proves only:

- local widget upload may have happened
- or the captured cache happened to be clean

It does **not** prove:

- the authoritative scene submitted this frame actually contained the terminal
  surface for that generation

## Current Failure Path

### 1. Scene is always cleared at frame start

In [scene_frame_runtime.zig](/home/home/personal/zide/src/ui/renderer/scene_frame_runtime.zig):

- `beginFrame(...)` clears the active scene target every frame
- `submitFrame(...)` always submits that scene target

That means any frame that presents after `beginFrame(...)` must have rebuilt
every still-visible retained surface before submit.

### 2. Terminal widget may skip texture update

In [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig):

- the retained terminal texture is updated only when the chosen update plan
  says full or partial work is required
- if no texture update occurs, `updated` remains false
- the widget can still:
  - clear the viewport background
  - draw overlays
  - re-use existing retained terminal texture state if
    `self.terminal_texture_ready`

### 3. Widget feedback is too weak

Still in [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig):

- `outcome.texture_updated` is only set when:
  - `updated`
  - or `cache.dirty == .none`

So a frame can carry a clean cache and return feedback that is acceptable to
retirement logic without proving that the current submitted scene re-blitted the
terminal surface after the scene clear.

### 4. Present completion trusts widget feedback

In [present_feedback_runtime.zig](/home/home/personal/zide/src/app/present_feedback_runtime.zig):

- present completion resolves the active widget
- flushes pending widget feedback after `endFrame`
- passes that feedback to terminal publication retirement

This is correct ownership for present completion, but the signal it consumes is
still too weak.

### 5. Publication retirement accepts the weak signal

In [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig):

- `completeSubmittedPresentationFeedback(...)` returns early only on failed
  submission
- otherwise `completePresentationFeedback(...)` retires when:
  - `feedback.texture_updated`
  - or `presented.dirty == .none`

This is the exact gate that War 2 must replace.

## Stronger Required Boundary

The retirement question must move from:

- "did the widget do enough local work?"

to:

- "did the submitted scene definitely include the authoritative terminal
  retained surface for the acknowledged generation?"

That means the proof source must be renderer/scene-aware, not only
widget-local.

## Required Responsibility Split

### Terminal widget draw

Should own:

- local retained-surface update planning
- whether terminal texture content was uploaded this frame
- the generation represented by the retained terminal texture after draw

Should not be the final authority on:

- whether the submitted scene actually contained that surface after a scene
  clear

### Renderer / scene frame

Should own:

- whether the frame cleared the authoritative scene target
- whether the terminal retained surface was blitted into the scene this frame
- whether the submitted scene therefore satisfies terminal-present completeness

### Present feedback runtime

Should own:

- consuming renderer-proven scene submission truth
- feeding that stronger truth to terminal presentation retirement

### Terminal publication

Should own:

- retirement policy once the stronger proof arrives

Should not infer scene completeness from:

- widget texture updates alone
- cache cleanliness alone

## First Implementation Slices

### Slice 1: define a stronger terminal-present feedback payload

Add a stronger explicit signal shaped around scene submission, for example:

- submitted terminal generation
- terminal surface generation drawn into scene
- whether terminal surface was re-blitted this frame
- whether the frame cleared scene truth before submission

This should be downstream-facing data, not a widget convenience bool.

Status:

- first payload step is now in:
  `PresentationFeedback` carries explicit retained-surface fields
  - `retained_surface_blitted`
  - `retained_surface_generation`
- widget draw now populates those fields when it actually reuses/blits the
  retained terminal surface
- retirement behavior is intentionally unchanged in this slice

### Slice 2: make scene composition record terminal-surface submission truth

The renderer/present path must explicitly record:

- scene cleared this frame
- terminal retained surface blitted this frame
- generation represented by that blit

Without that, acknowledgement cannot be made reference-grade.

Status:

- first scene-proof step is now in:
  - `retained_targets_runtime.drawTerminalSurface(...)` reports terminal-surface
    blits to `scene_frame_runtime`
  - `PresentTrace` and `FrameSubmission` now carry:
    - terminal-surface blit count
    - terminal-surface generation
- this is still signal-shape only; retirement behavior remains unchanged until
  the next slice

### Slice 3: change publication retirement to require the stronger proof

Replace:

- `feedback.texture_updated || presented.dirty == .none`

with a scene-completeness gate derived from the new submission truth.

### Slice 4: keep old widget-local feedback fields only if still useful locally

If `texture_updated` still helps widget-local heuristics or diagnostics, keep
it as local detail.

But it must stop acting as terminal-present retirement authority.

## Concrete Hotspots For Slice 1

1. [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
2. [scene_frame_runtime.zig](/home/home/personal/zide/src/ui/renderer/scene_frame_runtime.zig)
3. [present_feedback_runtime.zig](/home/home/personal/zide/src/app/present_feedback_runtime.zig)
4. [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)

## Non-Goals For The First Slice

- no broad host-boundary redesign yet
- no publication helper cleanup by momentum
- no generalized renderer/publication redesign beyond the exact invariant
  required here

## Bottom Line

The first War 2 code cut should not ask:

- "did terminal widget update its texture?"

It should ask:

- "did the submitted scene definitely contain the authoritative terminal
  retained surface for the generation we are about to retire?"
