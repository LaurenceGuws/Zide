# Agent Handover (High-Level Editor Context)

Date: 2026-02-08

This file is intentionally high-level. Detailed progress and research live in:
- `app_architecture/ui/renderer_todo.yaml`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `app_architecture/ui/ui_widget_modularization_todo.yaml`
See `docs/INDEX.md` for the full doc map.

High-level state:
- UI widget modularization is the current focus: split large UI widgets into small UI-only modules while preserving behavior.
  - Plan/todo: `app_architecture/ui/ui_widget_modularization_todo.yaml`
  - Primary target: `src/ui/widgets/terminal_widget.zig` (currently ~2k LOC)
- Terminal backend modularization is largely complete, but terminal changes should still keep the replay harness green.
  - Terminal plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - Run: `zig build test-terminal-replay -- --all`
- SDL3 + OpenGL is the Linux baseline; keep SDL3 parity stable while UI modularization lands.
- Logs are authoritative for debugging; the agent owns `./.zide.lua` to tune log tags without permission.

If this file conflicts with the todo/app_architecture docs, treat it as stale and update/remove it.
