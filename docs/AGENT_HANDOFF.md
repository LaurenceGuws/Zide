## Handoff (High-Level)

### Current Focus
- Primary: terminal architecture cleanup after the rain/render investigation stabilized the worst redraw faults.
  - detailed review + recent fix history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
  - terminal architecture plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - damage/dirty notes: `app_architecture/terminal/DAMAGE_TRACKING.md`
  - UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`

### Recent Changes (High-Level)
- The high-refresh rain investigation removed most renderer-side force-full and stale invalidation escape hatches.
- Full-screen `ascii-rain` is now close to stable, so the stronger remaining work is structural rather than incident-driven.
- Current high-risk architectural seams are:
  - `TerminalSession` is still a large multi-domain owner (PTY/parser/screens/history/render publication/UI-facing APIs).
  - redraw lifecycle ownership is still split between `view_cache`, `terminal_widget_draw`, and frame runtime helpers.
  - scheduler/poll state is still spread across app runtime helpers and `TerminalWorkspace`, even after moving the obvious file-global pacing state out of the generic idle hook.
  - input-mode snapshot publication is manual and duplicated across protocol paths.
  - widget input/draw still contain backend-policy behavior rather than being thin presentation/orchestration layers.

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).

### Where to Look
- Primary architecture review + recent cleanup history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
- Terminal architecture plan + current hotspot list: `app_architecture/terminal/MODULARIZATION_PLAN.md`
- Terminal damage/dirty background + redraw/publication hotspot list: `app_architecture/terminal/DAMAGE_TRACKING.md`
- Current UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Doc workflow policy: `docs/WORKFLOW.md`

### Known Risk (High-Level)
- A broad refactor done in the wrong order will re-entangle correctness with redraw/scheduler changes and make regressions hard to localize.
- The main remaining risk is boundary drift: session/runtime/widget/protocol code still share responsibilities that should be isolated.
- Kitty graphics, sync/presentation ownership, and input snapshot publication remain sensitive correctness surfaces.
