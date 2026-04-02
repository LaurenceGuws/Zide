# Terminal War 2 Present Invariant Review 2026-04-02

## Purpose

Choose the War 2 opening target and define the exact present-boundary
correctness question that should drive it.

This review resolves the initial War 2 fork between:

- structural recentering around one engine-owned host-state boundary
- present/render correctness discipline around submitted terminal truth

## Decision

War 2 should open on the present invariant.

The structural host-boundary question is still real, but it should wait.

## Why This Wins

The present boundary is the stronger next war because it is not just an
architectural taste gap.

It is a live correctness hole that still exists even after War 1:

- the renderer can clear and submit the authoritative scene target
- retained terminal content can fail to re-blit
- terminal presentation can still be acknowledged and retired on weaker
  widget-local signals

That means the current downstream truth is still too soft.

Building a stronger engine-owned host-state boundary on top of that would risk
hardening the wrong invariant.

## Core Invariant

The native terminal present contract should be:

- once the renderer-owned scene target is cleared for a frame, every retained
  terminal surface that remains part of visible scene truth must be re-blitted
  before submit

And terminal presentation acknowledgement should mean:

- the submitted scene definitely contained the authoritative terminal retained
  surface for the acknowledged publication generation

Not merely:

- widget texture was updated
- or cached terminal state happened to be marked clean

## Current Failure Shape

Live failure path from current code/doc authority:

1. frame begins and authoritative scene target is cleared
2. terminal widget draw path may skip texture update and rely on retained local
   state
3. frame submits successfully
4. present completion retires terminal presentation on weaker widget-staged
   feedback than true scene-submission proof

This matches the known native bug signature already documented in:

- `docs/todo/terminal/wayland_present.md`
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`

## Strongest Hotspots

### 1. `src/ui/widgets/terminal_widget_draw.zig`

This is the critical hotspot for the retained-terminal-surface truth gap.

Why:

- it can decide not to upload/update texture content
- it can still draw from retained state
- the rest of the system currently treats the resulting feedback as close
  enough to presentation truth

This is where the current local truth is strongest but still insufficient.

### 2. `src/terminal/core/publication/terminal_publication.zig`

Current issue:

- `completePresentationFeedback(...)`
- `completeSubmittedPresentationFeedback(...)`

retire terminal presentation based on:

- `texture_updated`
- or `dirty == .none`

That is weaker than:

- scene submission definitely contained the authoritative terminal surface

### 3. `src/app/present_feedback_runtime.zig`

This is the host-side acknowledgement boundary.

It now owns present completion, which is the right owner.
But it still consumes widget-staged feedback rather than a renderer-proven
scene completeness signal.

## Why The Structural Boundary Should Wait

The engine-owned host-boundary question remains valid:

- host-visible truth is still spread across publication, workspace/workspace
  host, session runtime, and widget handoff

But right now the stronger risk is that present acknowledgement is still too
weak for the renderer-owned scene contract we already claim.

So War 2 should first make submitted terminal truth airtight.

Then the next structural war can build on a correct downstream invariant.

## Required Review Question

What exact signal should gate terminal present acknowledgement in native mode?

Candidate answers:

1. current weak answer:
   - published generation was uploaded
   - or local cache was clean

2. required stronger answer:
   - the submitted scene definitely re-blitted the authoritative terminal
     retained surface after any scene clear

War 2 should begin by defining that gate precisely.

## Required Next Deliverable

Create the implementation review/spec that defines:

- the exact native present invariant
- the current failure path through widget draw, renderer scene submit, and
  presentation retirement
- the new required ack gate
- the renderer/widget/publication responsibilities implied by that gate

## Bottom Line

War 2 should open on present/render correctness discipline.

The structural host-boundary war should wait until the submitted-scene truth
is strong enough to deserve being treated as the foundation.
