# Agent Handover (High-Level Editor Context)

Date: 2026-03-08

This file is intentionally high-level. Detailed progress belongs in:
- `app_architecture/app_mode_layering_todo.yaml`
- `app_architecture/dependencies_todo.yaml`
- `app_architecture/ui/*_todo.yaml`
- `app_architecture/editor/*_todo.yaml`

Current state summary:
- Active focus is singular: 240Hz terminal stutter/frozen-rain investigation using `ascii-rain-git` as reproducer.
- Fresh comparative findings against Kitty are documented in `app_architecture/review/TERMINAL_240HZ_RAIN_INVESTIGATION.md`.
- Previous broad extraction/perf focus is stale for this handoff window.

Editor context:
- Keep changes tightly scoped to terminal redraw/poll/damage behavior while this investigation is active.
- Keep logs scoped and intentional in `./.zide.lua` during investigations.

If this file conflicts with task todos or architecture docs, treat this file as stale and update it.
