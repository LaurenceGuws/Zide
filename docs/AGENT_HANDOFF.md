## Handoff (High-Level)

### Current Focus
- Primary: terminal architecture cleanup after the rain/render investigation stabilized the worst redraw faults.
  - detailed review + recent fix history: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
  - terminal architecture plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - damage/dirty notes: `app_architecture/terminal/DAMAGE_TRACKING.md`
  - UI/backend seam tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Active execution order now lives in `app_architecture/terminal/MODULARIZATION_PLAN.md` under `Strict Cleanup Queue (2026-03-09)`.
- Current top-of-queue focus: `TerminalSession` surface reduction, then workspace/session boundary tightening, then runtime scheduling ownership cleanup.

### Recent Changes (High-Level)
- The high-refresh rain investigation removed most renderer-side force-full and stale invalidation escape hatches.
- Full-screen `ascii-rain` is now close to stable, so the stronger remaining work is structural rather than incident-driven.
- `TerminalSession` surface reduction is active: borrowed title/cwd/scrollback/selection seams are being cut back, terminal text export now lives in backend code instead of the widget, and FFI/workspace/open-path callers now use backend-owned metadata/export contracts instead of separate raw getter calls or split title/cwd query helpers.
- Current high-risk architectural seams are:
  - `TerminalSession` is still a large multi-domain owner (PTY/parser/screens/history/render publication/UI-facing APIs).
  - terminal-originated PTY writes and the main session mutation/publication locking cleanup are now in better shape, so the next structural hotspot is the oversized `TerminalSession` surface and the borrowed app/UI query seams hanging off it.
  - redraw lifecycle ownership is significantly cleaner: published cache capture and post-draw completion are now behind backend APIs, although `view_cache`, widget wrapper code, and frame runtime still participate in the presentation pipeline.
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
