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

## Current Checkpoint (2026-04-11)

- the first narrow chrome-band slice is now in:
  - `renderer_chrome_band_host.Band` can now queue/replay sized text ops
  - band text ops now copy queued text so stack-built/truncated labels are safe
    to replay at `Band.flush()`
  - `side_nav.zig` badge counts no longer bypass the band seam through
    immediate `shell.drawTextSized(...)`
  - that means the side-nav family now keeps background fills, icon text, and
    badge text inside one chrome-band ordering unit
- the second narrow chrome-band slice is now in:
  - `common.zig` exposes pure text truncation separate from immediate drawing
  - `status_bar.zig` routes mode chip text, active field text, selection/caret
    rects, error text, and file-path text through the chrome-band seam
  - tooltip drawing remains outside this seam because it is an overlay, not
    local status-bar composition
- the third narrow chrome-band slice is now in:
  - `shared_top_bar.zig` menu shadow now routes through the menu band instead
    of a direct surface rect next to band-owned menu fill/text
  - `tab_bar.zig` title truncation now separates truncation from drawing and
    queues tab title text through the chrome-band seam
  - tab-bar band text now flushes before `endClip()` so the band replay remains
    inside the tab strip clip boundary
- the fourth narrow chrome-band slice is now in:
  - integrated terminal tab-bar background now routes through the chrome-band
    seam instead of a direct surface rect next to tab text
  - shared window caption buttons now draw their backgrounds and glyph strokes
    through the chrome-band seam
- this does not claim shell/UI chrome is solved globally
- the next likely pressure inside this ticket is the terminal widget chrome
  boundary: any remaining shell/UI chrome fill plus dependent text/icon path
  that still bypasses `renderer_chrome_band_host.Band`
