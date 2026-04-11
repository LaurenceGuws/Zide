# Band Composition Phase Plan

Purpose: define the next honest renderer gate-5 blocker after
`RB-B3.e` presentable lifecycle parity has been narrowed enough that it is no
longer the strongest shared contract pressure.

This plan is intentionally narrow.

It does not reopen generic presentable cleanup.
It does not start Android GLES backend code.
It does not widen into repo-wide UI restyling or arbitrary shell cleanup.

## Why This Exists

Current code and authority now agree on the stronger remaining renderer
pressure:

- terminal presentable lifecycle is no longer the vaguest blocker
- Metal now satisfies the shared terminal refresh seam structurally and routes
  through the active refresh path
- the stronger remaining shared contract pressure is that fills and their
  dependent text/icon work still do not share one backend-neutral phase
  boundary

That means a future Android renderer would still inherit one uneven ordering
story for ordinary UI/editor/sample composition even if terminal presentable
lifecycle is materially cleaner now.

## Goal

Goal:

- define and land the next narrow band-composition seam where one ordering unit
  owns both fill/background work and its dependent text/icon/outline work
- remove a concrete example of "fill path plus unrelated immediate text path"
  from shared renderer truth

## Required Outcome

After this cut:

- one explicit band/composition seam owns local ordering for both fills and
  dependent text/icon work
- shared code no longer treats that family as generic fills plus unrelated
  immediate text
- the next remaining blocker after this cut is clearer than "phase boundary
  later"

## Initial Scope

Start with shell/UI chrome band composition.

Primary code pressure:

- `src/ui/renderer/renderer_chrome_band_host.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/text_runtime.zig`
- any narrow host/runtime seam needed to record and replay one band-local
  ordering unit without widening the design prematurely

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `docs/todo/ui/renderer.md`
- `docs/todo/android/implementation.md`

## Non-Goals

- no repo-wide generic text phase rewrite in one cut
- no editor-wide band adoption in the same step unless the chrome cut proves
  insufficient
- no Android renderer backend bootstrap
- no fake closure language that claims text/surface phase pressure is solved
  globally after one family adoption

## Acceptance Criteria

This ticket is met when:

- one real band/composition family owns fill plus dependent text/icon ordering
  under one backend-neutral seam
- shared code no longer expresses that family as one fill path plus one
  unrelated immediate text path
- queue and handoff docs can name the next blocker after this cut without
  ambiguity

## Stop Marker

Stop when:

- one narrow band/composition seam is landed and validated
- docs say exactly what family or pressure remains next
- no speculative expansion is added just to make the seam feel more general
