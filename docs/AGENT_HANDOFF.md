## Handoff (High-Level)

### Current Focus
- Primary: investigate and fix terminal rendering stutter/frozen-rain artifacts observed on 240Hz monitors (not reproducible on 60Hz), with `ascii-rain-git` as the baseline reproducer.
  - investigation doc: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
  - tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml` (Phase 5 verification follow-up)

### Recent Changes (High-Level)
- Captured a fresh differential analysis (March 8, 2026) against `reference_repos/terminals/kitty` focused on high-refresh behavior.
- Consolidated findings into a dedicated architecture review doc and marked prior generic focus as stale.
- Confirmed the current likely fault domain is Zide redraw scheduling / partial texture update behavior under high-refresh incremental updates, not a simple PTY throughput ceiling.

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).

### Where to Look
- Primary investigation notes and analysis: `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
- Current terminal UI perf tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Terminal damage/dirty background: `app_architecture/terminal/DAMAGE_TRACKING.md`
- Doc workflow policy: `docs/WORKFLOW.md`

### Known Risk (High-Level)
- High-refresh output can expose redraw starvation or partial-damage correctness gaps that do not appear at 60Hz.
- Existing viewport texture-shift optimization remains a high-risk surface for scroll-heavy TUIs if dirty metadata and redraw cadence diverge.
