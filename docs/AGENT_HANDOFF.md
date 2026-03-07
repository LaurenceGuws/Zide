## Handoff (High-Level)

### Current Focus
- Primary: remove UI/render-thread blocking on backend/session work and move expensive compute off the UI thread.
  - tracking and phased plan: `app_architecture/review/PERFORMANCE_REVIEW_1.md`
  - task tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml` (Phase 5)
- Keep mode-layer extraction stable and continue shrinking `main.zig` ownership through app-runtime module extraction (`app_architecture/app_mode_layering_todo.yaml`).
- Keep dependency packaging robust and documented:
  - SDL3, Lua, tree-sitter core, and FreeType/HarfBuzz are Zig package managed in normal flow (non-vcpkg paths).
- Keep terminal-only distribution healthy:
  - terminal-focused build graph (`-Dmode=terminal`)
  - bundle packaging flow under `tools/bundle_terminal_linux.sh`
  - terminfo/runtime identity behavior documented and consistent.

### Recent Changes (High-Level)
- Completed UI-thread/backend contention audit (2026-03-07) and documented prioritized refactor plan.
- Added explicit Phase 5 performance/offload tasks to UI widget modularization todo (terminal lock scope, polling budgets, async highlighter/search work, UI-path I/O cleanup).
- Completed a first Phase 5 implementation batch (2026-03-07):
  - terminal input lock path now avoids blocking fallback waits under contention
  - visible-terminal polling now uses bounded active-first budgets with background fairness
  - editor grammar auto-bootstrap no longer blocks frame path (`spawnAndWait` removed from highlighter init path)
  - terminal ctrl+click open path no longer performs sync file detect I/O
- Completed terminal draw lock-scope reduction (2026-03-07):
  - render cache is copied under short lock into widget-owned snapshot buffers
  - shaping/glyph batching and draw passes run lock-free
  - dirty-clear now uses generation-guarded session helper (`clearDirtyIfGeneration`)
- Added terminal-focused input/poll/redraw refinement + telemetry (2026-03-07):
  - terminal poll pressure now follows terminal-relevant activity (not generic event count)
  - passive terminal hover-only mouse movement is skipped in visible-terminal widget input path (unless mouse-reporting/ctrl-link intent applies)
  - `input.latency` logs now include terminal poll budget usage + terminal draw phase attribution
- Build graph now supports focused compile-time mode planning:
  - default `zig build` plans full IDE app
  - `-Dmode=terminal` plans terminal-only app
  - `-Dmode=editor` plans editor-only app
- Build logic was split into focused `build_utils/*` planners/reports/dependency resolution modules.
- SDL3 + Lua + tree-sitter core now run through Zig package manager in normal flow.
- Tree-sitter terminal-policy tightened:
  - terminal target does not link tree-sitter
  - dependency policy checks enforce this.
- Terminal bundle flow was hardened:
  - mode-aware asset whitelist copy
  - bundled terminfo compile
  - launcher/runtime directory semantics.
- Terminal identity/runtime environment tightened:
  - project terminfo aliases: `xterm-zide|zide-256color`
- runtime TERM preference: `xterm-kitty`, then `xterm-zide`, then `zide-256color`, then `zide`, then `xterm-256color`

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).

### Where to Look
- UI blocking/offload plan: `app_architecture/review/PERFORMANCE_REVIEW_1.md`
- UI performance task tracker: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Mode layering/refactor tracker: `app_architecture/app_mode_layering_todo.yaml`
- Dependency packaging tracker: `app_architecture/dependencies_todo.yaml`
- Dependency architecture notes: `app_architecture/DEPENDENCIES.md`
- Bootstrap/build/run guide: `app_architecture/BOOTSTRAP.md`
- Terminal compatibility surface: `docs/terminal/compatibility.md`
- Doc workflow policy: `docs/WORKFLOW.md`

### Known Risk (High-Level)
- Terminal polling and search recompute still need final metrics/offload tuning under worst-case load.
- Editor search recompute is still synchronous and can cause visible stalls on large files.
- Focused mode extraction is broad; regressions can hide in runtime wiring if checkpoints are not kept small.
- FreeType/HarfBuzz pinned package path still needs continued parity attention across environments.
- Terminal packaging/runtime can drift if terminfo identity docs and launcher behavior are not kept aligned with core.
