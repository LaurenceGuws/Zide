# Non-Terminal Frame Family Plan

Purpose: define the first gate-5 Android-unblock cut under `RB-B3.c` /
`AR-B1`.

This plan is intentionally narrow. It does not redesign the whole frame
system. It does not create a generic multi-family present framework. It does
not open Android backend implementation in `src/ui/renderer/`.

It defines one small, reviewable cut.

## Branch Goal

Branch: `renderer/ar-b1-nonterminal-frame-family`

Goal:

- make the first non-terminal composition family first-class in shared
  frame/present bookkeeping
- remove the current "terminal gets product-level submission feedback,
  everything else gets trace-only counters" asymmetry
- do that with one narrow adopter so Android renderer adoption has one less
  terminal-only assumption to special-case later

## Why This Exists

Current code truth:

- `FrameSubmission` is still terminal-centric
- `renderer_frame_host.finishFrameSubmission(...)` still computes product-level
  family feedback only from terminal presentation state
- non-terminal families such as chrome band, sample section, and editor
  row-band are still represented mainly as trace counters and debug mismatch
  warnings

That is acceptable for current desktop behavior.
It is not acceptable as the shared contract we want Android to inherit.

If Android renderer adoption started from this shape, it would still inherit:

- a product-level frame result surface that knows about terminal and little
  else
- non-terminal ordering families that are observable but not first-class

So the next honest cut is to make one non-terminal family first-class.

## First Adopter Decision

First adopter: `chrome_band`

Why `chrome_band` first:

- it already has one explicit renderer-host seam:
  `src/ui/renderer/renderer_chrome_band_host.zig`
- it is narrower and less semantically dense than editor row-band
- it matters to Android product quality because top-level bar/chrome surfaces
  are part of the visible terminal shell story
- it lets us fix the frame/present bookkeeping asymmetry without opening
  editor retained/presentable design prematurely

Why not `editor_row_band` first:

- it is more tightly coupled to editor draw-list flush and row segmentation
- it is still a legitimate later adopter, but it is not the cheapest first
  contract cut

Why not `sample_section` first:

- it is weaker Android leverage than chrome band

## Required Outcome

After `RB-B3.c`, the shared frame/present surface must no longer be
terminal-only in product meaning.

Minimal required shape:

- one shared family-level frame summary surface exists
- that surface can report at least:
  - terminal family touched/presented
  - chrome-band family touched/presented
- shared frame finalization and present feedback consume that family summary
  without inferring non-terminal families from ad-hoc trace counters

This plan does not require editor/sample adoption in the same cut.

## Scope

In scope:

- define one small shared family summary surface for frame/present bookkeeping
- route terminal and chrome-band family reporting through it
- keep current terminal generation reporting honest if it still exists
- update present logging/feedback to use that surface
- keep behavior neutral outside the new reporting/ownership truth

Primary code pressure:

- `src/ui/renderer/present_trace_runtime.zig`
- `src/ui/renderer/renderer_frame_host.zig`
- `src/app/present_feedback_runtime.zig`
- `src/ui/renderer/renderer_chrome_band_host.zig`

Likely supporting pressure:

- `src/ui/renderer/renderer_text_phase_group_host.zig`
- `src/app/scene_assembly_runtime.zig`

## Non-Goals

- no Android backend in `src/ui/renderer/`
- no presentable redesign
- no editor-row-band adoption in this cut
- no sample-section adoption in this cut
- no broader frame-ordering rewrite
- no schema growth for every future family "just in case"

## Acceptance Criteria

`RB-B3.c` / `AR-B1` is met when:

- one shared family summary surface exists
- `FrameSubmission` and/or the owning shared frame result surface is no longer
  terminal-only in product meaning
- `chrome_band` is the first non-terminal adopter through that surface
- terminal presentation feedback still works correctly
- current behavior remains neutral outside the new family reporting boundary
- queue/docs clearly state what later adopters remain:
  - `editor_row_band`
  - `sample_section`

## Stop Marker

Stop this branch when:

- terminal and `chrome_band` both report through one shared family summary
  surface
- frame/present feedback no longer needs trace-only inference to know whether
  chrome-band work participated in the submitted frame
- docs/queue reflect the new contract truth
- build/test stay green

Do not continue from there into editor/sample adoption on the same branch.

## Expected Review Questions

The implementation review for this branch should answer exactly:

1. What shared family summary surface was introduced?
2. Why was `chrome_band` the right first adopter?
3. What terminal-specific product meaning still remains after this cut?
4. What later adopters are explicitly left for follow-up?
