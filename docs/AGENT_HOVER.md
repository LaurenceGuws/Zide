# Agent Handover (High-Level Editor Context)

Date: 2026-02-02

This file is intentionally high-level. Detailed progress and research live in:
- `app_architecture/ui/renderer_todo.yaml`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
See `docs/INDEX.md` for the full doc map.

High-level state:
- Terminal modularization is active: extraction-only refactors of `src/terminal/core/terminal_session.zig` and helpers (see `app_architecture/terminal/MODULARIZATION_PLAN.md`).
- Terminal replay harness goldens are the baseline; keep `zig build test-terminal-replay -- --all` green during refactors.
- SDL3 + OpenGL is the Linux baseline; keep SDL3 parity stable while terminal changes land.
- Logs are authoritative for debugging; the agent owns `./.zide.lua` to tune log tags without permission.

If this file conflicts with the todo/app_architecture docs, treat it as stale and update/remove it.
