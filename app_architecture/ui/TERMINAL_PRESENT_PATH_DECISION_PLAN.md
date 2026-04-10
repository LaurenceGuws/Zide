# Terminal Present Path Decision Plan

Purpose: define the next renderer cut after `AR-B1` / `RB-B3.c` so Android
renderer adoption keeps moving against one explicit blocker instead of vague
"more gate 5" pressure.

This plan is intentionally narrow.

It does not redesign terminal present execution.
It does not reopen Metal live verification.
It does not add a new backend.

## Why This Exists

Current code truth after the frame-family work:

- shared frame submission is no longer terminal-only in product meaning
- terminal retirement feedback now consumes `family_summary.terminal` directly
- non-terminal adopters (`chrome_band`, `editor_row_band`, `sample_section`)
  now report through one shared family summary surface

But terminal widget presentation runtime still contains direct path checks like:

- `usesDirectTerminalPresentation(...)` in recent-input force-full policy
- direct snapshot reuse gating in fast-present reuse
- direct partial-update entry gating before snapshot update

That means shared widget/runtime code is still deciding product behavior from
backend presentation path shape in a few surviving places.

Android should not inherit that shape.

## Branch Goal

Goal:

- remove the remaining product-significant
  `usesDirectTerminalPresentation(...)` decisions from
  `terminal_widget_presentation_runtime.zig`
- make those decisions terminate behind the shared terminal present contract or
  renderer presentable host instead

## Required Outcome

After this cut:

- shared widget/runtime code no longer branches on direct-vs-retained terminal
  presentation mode for:
  - recent-input force-full behavior
  - fast-present reuse gating
  - direct partial-update entry gating
- shared code still computes product intent
- backend/presentable host code decides whether the current backend can satisfy
  that intent through reuse, partial update, full update, or not at all

## Scope

Primary code pressure:

- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/renderer/renderer_presentable_host.zig`
- `src/ui/renderer/presentable_contract.zig`

Likely supporting pressure:

- `app_architecture/ui/TERMINAL_PRESENT_TRANSACTION_PLAN.md`
- `docs/todo/ui/renderer.md`
- `docs/todo/android/implementation.md`

## Non-Goals

- no terminal-present execution rewrite
- no new plan/result schema growth unless current fields cannot carry the truth
- no Metal validation lane reopen
- no Android backend code in `src/ui/renderer/`

## Acceptance Criteria

This ticket is met when:

- `terminal_widget_presentation_runtime.zig` no longer calls
  `usesDirectTerminalPresentation(...)`
- the same product behavior remains on GL
- shared planning stays product-owned
- backend/presentable host owns path-satisfaction decisions
- docs clearly state what still remains after this cut

## Stop Marker

Stop when:

- the surviving direct-vs-retained mode checks are gone from widget runtime
- validation is green
- docs/queue explicitly name the next blocker instead of leaving gate 5 vague

## Current Checkpoint (2026-04-09)

- `terminal_widget_presentation_runtime.zig` no longer calls
  `usesDirectTerminalPresentation(...)`
- recent-input force-full policy now routes through
  `renderer_presentable_host.terminalAllowsRecentInputForceFullPresentation(...)`
- fast-present reuse gating now routes through
  `renderer_presentable_host.terminalAllowsFastPresentReuse(...)`
- incremental presentable-update entry now routes through
  `renderer_presentable_host.terminalSupportsIncrementalPresentableUpdate(...)`
- the old `usesDirectTerminalPresentation(...)` helper is now deleted
- this is intentionally only a path-decision ownership cut:
  widget/runtime behavior is unchanged, and execution still terminates through
  the existing terminal present transaction seams
