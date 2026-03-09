## Handoff (High-Level)

### Current Focus
- Primary: terminal architecture cleanup after the rain/render investigation stabilized the worst redraw faults.
  - detailed review + recent fix history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
  - terminal architecture plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - damage/dirty notes: `app_architecture/terminal/DAMAGE_TRACKING.md`
  - UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Active execution order now lives in `app_architecture/terminal/MODULARIZATION_PLAN.md` under `Strict Cleanup Queue (2026-03-09)`.
- Current top-of-queue focus: presentation/publication ownership cleanup, then PTY write contract unification, then session state/publication locking cleanup.

### Recent Changes (High-Level)
- The high-refresh rain investigation removed most renderer-side force-full and stale invalidation escape hatches.
- Full-screen `ascii-rain` is now close to stable, so the stronger remaining work is structural rather than incident-driven.
- Current high-risk architectural seams are:
  - `TerminalSession` is still a large multi-domain owner (PTY/parser/screens/history/render publication/UI-facing APIs).
  - redraw lifecycle ownership is still split between `view_cache`, `terminal_widget_draw`, and frame runtime helpers, although presented-generation ack and dirty-retirement policy are now behind a single backend API instead of widget-local sequencing.
  - scheduler/poll state is still split across app runtime helpers and `TerminalWorkspace`, but concrete workspace poll budgets now live behind the workspace contract instead of the app hook.
  - input-mode snapshot publication is still manual and duplicated in places, although the common CSI mode toggles now flow through explicit setters instead of open-coded field flips.
  - widget input/draw still contain backend-policy behavior rather than being thin presentation/orchestration layers.

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).
- `main` is the default branch. Feature branches are for larger isolated cuts only, and the agent owns creating, merging, and deleting them.
- Do not keep dead seams or compatibility wrappers just to avoid a hard cut when the old surface is holding the terminal back.

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
