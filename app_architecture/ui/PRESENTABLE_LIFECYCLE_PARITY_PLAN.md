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
