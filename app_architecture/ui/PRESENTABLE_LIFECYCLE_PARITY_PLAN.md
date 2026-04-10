# Presentable Lifecycle Parity Plan

Purpose: define the next honest gate-5 renderer cut after `RB-B3.d` so Android
renderer adoption advances against one explicit contradiction instead of vague
"more parity later" pressure.

This plan is intentionally narrow.

It does not start Android GLES backend code.
It does not reopen Metal live validation as a side lane.
It does not widen into general backend-runtime storage cleanup.

## Why This Exists

Current contract and audit truth now agree on the next strongest blocker:

- shared widget/runtime no longer branches on
  `usesDirectTerminalPresentation(...)`
- `RB-B3.d` is complete
- gate #5 is still not met because presentable lifecycle is still uneven
  between the two reference backends:
  - OpenGL models terminal presentation as a retained update-target lifecycle
  - Metal models terminal presentation as snapshot creation plus composition
    replay

That means a future Android backend would still inherit one uneven presentable
story instead of one neutral lifecycle contract.

## Branch Goal

Goal:

- make the shared terminal presentable contract more lifecycle-neutral so
  OpenGL and Metal read more like two implementations of one presentable model
- reduce the degree to which OpenGL retained-target semantics remain the de
  facto reference shape

## Required Outcome

After this cut:

- the shared presentable host and contract expose one clearer backend-neutral
  lifecycle story for terminal presentables
- shared code no longer reads like it is asking for "GL retained update if
  possible, otherwise Metal fallback"
- backend differences remain implementation mechanics behind the seam, not
  product-level lifecycle branching

## Scope

Primary code pressure:

- `src/ui/renderer/renderer_presentable_host.zig`
- `src/ui/renderer/presentable_contract.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md`
- `docs/todo/ui/renderer.md`
- `docs/todo/android/implementation.md`

## Non-Goals

- no new Android renderer backend implementation
- no general frame-lifecycle rewrite
- no renderer-root runtime-bundle redesign in the same cut
- no fake parity language that overclaims Metal maturity without code truth

## Acceptance Criteria

This ticket is met when:

- the next shared presentable lifecycle seam is described explicitly in code
  and docs
- shared terminal presentation code no longer treats retained update-cycle
  availability as the main contract shape
- OpenGL and Metal both satisfy the same presentable lifecycle vocabulary
  through backend-owned mechanics
- queue and handoff docs can name this cut as the current Android renderer
  blocker without ambiguity

## Stop Marker

Stop when:

- the presentable lifecycle contradiction is narrower and explicitly recorded
- validation is green
- docs state what blocker remains after this cut instead of falling back to
  generic "presentable parity later"

## Current Checkpoint (2026-04-11)

- the first code-facing cut is in:
  - the shared seam no longer speaks in backend-shaped "retained update"
    language
  - backend dispatch and presentable host now route through
    `refreshTerminalPresentable(...)`
  - the shared result surface now uses lifecycle-neutral refresh outcomes:
    - `.refreshed`
    - `.target_unavailable`
    - `.unsupported`
- widget/runtime behavior is intentionally unchanged in this cut
- the second code-facing cut is also in:
  - active widget/runtime functions and result types no longer use retained-path
    naming for the shared terminal-presentable refresh flow
  - the active shared path now reads in refresh/presentable language end-to-end
- this narrows the contradiction from "shared code asks for a retained update
  cycle" to the more honest remaining problem:
  OpenGL and Metal still satisfy that refresh seam through uneven underlying
  mechanics
- the third code-facing cut is now in too:
  - shared terminal widget runtime no longer owns the direct-surface versus
    retained-surface execution branch
  - fast reuse remains widget-owned, but the present-path execution decision
    now terminates in `renderer_presentable_host.zig`
  - this removes another product-significant backend split from shared widget
    code without overclaiming lifecycle parity
- the fourth code-facing cut is now in too:
  - the parallel `TerminalPresentPath` classifier has been removed from the
    active presentable dispatch/host surface
  - presentable-host decisions now resolve from declared
    `TerminalPresentationMode` capability truth instead of a duplicate path
    enum
- the fifth code-facing cut is now in too:
  - shared code no longer asks whether terminal presentation supports
    specifically "direct partial update"
  - the remaining shared capability question is now phrased more neutrally as
    incremental presentable update support
- the sixth code-facing cut is now in too:
  - presentable-host helpers no longer mix backend capability truth with
    widget policy inputs like sync-update state
  - widget/runtime now owns its own sync-update reuse policy while the host
    answers only backend requirement/support questions
- the seventh code-facing cut is now in too:
  - Metal no longer answers terminal presentable refresh as structurally
    unsupported
  - it now replays the queued terminal surface-update body into the existing
    snapshot presentable texture on the current Metal command buffer
  - this is a structural lifecycle-parity improvement, not a claim that live
    Metal verification is complete again
- the eighth code-facing cut is now in too:
  - active terminal present dispatch no longer reserves the refresh flow only
    for retained-surface backends
  - refresh-capable backends now use the shared refresh execution path, so
    Metal participates in the active presentable refresh lane instead of only
    satisfying it as a dormant backend capability
