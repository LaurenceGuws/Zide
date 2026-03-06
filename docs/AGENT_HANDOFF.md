## Handoff (High-Level)

### Current Focus
- Keep mode-layer extraction stable and continue shrinking `main.zig` ownership through app-runtime module extraction (`app_architecture/app_mode_layering_todo.yaml`).
- Keep dependency migration robust and documented:
  - SDL3, Lua, and tree-sitter core are Zig package managed in normal flow.
  - FreeType/HarfBuzz are the active migration slice on `-Dpath=zig` (`app_architecture/dependencies_todo.yaml`, `app_architecture/DEPENDENCIES.md`).
- Keep terminal-only distribution healthy:
  - terminal-focused build graph (`-Dmode=terminal`)
  - bundle packaging flow under `tools/bundle_terminal_linux.sh`
  - terminfo/runtime identity behavior documented and consistent.

### Recent Changes (High-Level)
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
  - runtime TERM preference: `zide-256color`, then `xterm-zide`, then `zide`, then `xterm-256color`
  - no `xterm-kitty` fallback path in terminal core.

### Constraints / Guardrails
- Handoff docs remain high-level only; details belong in `app_architecture/*` docs and todo files.
- This repo intentionally has no CI; do not add CI workflows.
- Agent owns `./.zide.lua` logging scope during debugging (minimal useful tags; low noise).

### Where to Look
- Mode layering/refactor tracker: `app_architecture/app_mode_layering_todo.yaml`
- Dependency packaging tracker: `app_architecture/dependencies_todo.yaml`
- Dependency architecture notes: `app_architecture/DEPENDENCIES.md`
- Bootstrap/build/run guide: `app_architecture/BOOTSTRAP.md`
- Terminal compatibility surface: `docs/terminal/compatibility.md`
- Doc workflow policy: `docs/WORKFLOW.md`

### Known Risk (High-Level)
- Focused mode extraction is broad; regressions can hide in runtime wiring if checkpoints are not kept small.
- `-Dpath=zig` FreeType/HarfBuzz path still needs continued parity attention across environments.
- Terminal packaging/runtime can drift if terminfo identity docs and launcher behavior are not kept aligned with core.
