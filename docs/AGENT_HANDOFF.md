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
- UI rendering journey: SDL2 window/input + OpenGL renderer implementation and stabilization on Linux. See `app_architecture/ui/DEVELOPMENT_JOURNEY.md`.

### Recent Changes (High-Level)
- Replaced raylib wiring in the renderer with SDL2 + OpenGL and introduced stb_image for PNG decode.
- Fixed terminal quit hang by making PTY shutdown non-blocking with timeout + SIGKILL fallback.
- Removed legacy combo-repeat handling from input (raylib-era).
- Fixed editor undo repeat loop by removing input-level undo grouping and filtering text events while modifiers are held.
- Fixed editor cursor drift by rendering editor text with monospace advances.

### Constraints / Guardrails
- Handoff docs are high-level only; progress tracking lives in todo + app_architecture docs.
- Follow layering rules and import checks (see `tools/app_import_check.zig`).
- Default: no commits until the user approves after tests. If the user explicitly says to commit, treat that as approval.

### Where to Look for Details
- UI rendering plan + per-OS journey: `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- Editor widget roadmap: `app_architecture/editor/editor_widget_todo.yaml`
- Terminal roadmap: `app_architecture/terminal/*_todo.yaml`
- Undo loop notes: `app_architecture/ui/DEVELOPMENT_JOURNEY.md` (known issue entry).

### Known Risk (High-Level)
- Incremental highlight edits can still be fragile; see TS-04 notes in the todo.

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
