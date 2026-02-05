Agent bootstrap prompt (use this verbatim)

You are an agent working on Zide, a Zig-based IDE.
You must follow AGENTS.md exactly — do not invent your own workflow.

First, do this in order:

Read AGENTS.md.

Read docs/AGENT_HANDOFF.md.

Read the relevant `app_architecture/**/_todo.yaml` + design docs for the current focus.

---

## Handoff (High-Level)

### Current Focus
- Terminal modularization: extraction-only refactors of `src/terminal/core/terminal_session.zig` and related helpers per `app_architecture/terminal/MODULARIZATION_PLAN.md`.
- Terminal correctness fixtures are locked with replay goldens; keep replay harness green while extracting.
- SDL3 migration remains the baseline; keep parity stable while terminal changes land (see `app_architecture/ui/sdl3_migration_todo.yaml`).

### Recent Changes (High-Level)
- Terminal replay harness now supports `--update-goldens` for snapshot refresh.
- New replay fixtures for gping/nvim overlay + vttest wraparound; goldens updated.
- Modularization extractions: render cache, palette/dynamic colors, OSC helpers (semantic, clipboard, CWD, hyperlink, title), input helpers (mouse, key encoding).

### Constraints / Guardrails
- Handoff docs are high-level only; progress tracking lives in todo + app_architecture docs.
- Follow layering rules and import checks (see `tools/app_import_check.zig`).
- Default: no commits until the user approves after tests. If the user explicitly says to commit, treat that as approval.
- Use logs as a primary source of truth when debugging; configure logging via `./.zide.lua` without asking for permission.

### Where to Look for Details
- UI rendering plan + per-OS journey: `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- Renderer modularization + OS abstraction plan: `app_architecture/ui/renderer_todo.yaml`
- SDL3 migration tracker: `app_architecture/ui/sdl3_migration_todo.yaml`
- Editor widget roadmap: `app_architecture/editor/editor_widget_todo.yaml`
- Terminal roadmap + modularization: `app_architecture/terminal/MODULARIZATION_PLAN.md`
- Terminal design notes: `app_architecture/terminal/DESIGN.md`
- Undo loop notes: `app_architecture/ui/DEVELOPMENT_JOURNEY.md` (known issue entry).

### Known Risk (High-Level)
- SDL3 is the only build path; regressions must be addressed promptly.
- Incremental highlight edits can still be fragile; see TS-04 notes in the todo.
- Terminal scrollback resize is still flawed; avoid deep work in this area until the redesign is implemented.
 - Terminal DECCOLM semantics are partial (no resize); long-term fix deferred.
 - Scrollback view cache + reflow resizing are still in progress; expect instability during the redesign.

### In-Progress (Uncommitted)
- None.

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
