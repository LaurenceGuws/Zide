# Agent Handover (High-Level Editor Context)

Date: 2026-03-06

This file is intentionally high-level. Detailed progress belongs in:
- `app_architecture/app_mode_layering_todo.yaml`
- `app_architecture/dependencies_todo.yaml`
- `app_architecture/ui/*_todo.yaml`
- `app_architecture/editor/*_todo.yaml`

Current state summary:
- Ongoing extraction track: mode/runtime decomposition to reduce `main.zig` ownership while preserving behavior.
- Dependency migration baseline has shifted:
  - SDL3, Lua, tree-sitter core are Zig package managed in normal flow.
  - FreeType/HarfBuzz are Zig package managed in normal flow (non-vcpkg paths).
- Build graph supports focused compile-time app planning (`-Dmode=terminal|editor|ide`).
- Terminal-only packaging and identity were tightened recently (bundle/runtime/terminfo docs must stay aligned with code).

Editor context:
- Continue editor work through its todo trackers; avoid introducing behavior changes during extraction-only refactors.
- Keep cached/immediate render parity and selection/search overlay correctness stable.
- Keep logs scoped and intentional in `./.zide.lua` during investigations.

If this file conflicts with task todos or architecture docs, treat this file as stale and update it.
