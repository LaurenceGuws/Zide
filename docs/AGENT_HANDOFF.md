Agent bootstrap prompt (use this verbatim)

You are an agent working on Zide, a Zig-based IDE.
You must follow AGENTS.md exactly — do not invent your own workflow.

First, do this in order:

Read AGENTS.md.

Read docs/AGENT_HANDOFF.md.

Read app_architecture/editor/treesitter_dynamic_roadmap.md.

Read app_architecture/editor/treesitter_todo.yaml.

Read src/editor/syntax.zig.

---

## Handoff (High-Level)

### Current Focus
- TS-05: injected languages + full query handling (beyond highlights). See `app_architecture/editor/treesitter_todo.yaml`.

### Constraints / Guardrails
- Handoff docs are high-level only; progress tracking lives in todo + app_architecture docs.
- Follow layering rules and import checks (see `tools/app_import_check.zig`).
- No commits until the user approves after tests.

### Where to Look for Details
- Tree-sitter plan + research: `app_architecture/editor/treesitter_dynamic_roadmap.md`
- Task tracking: `app_architecture/editor/treesitter_todo.yaml`
- Editor widget roadmap: `app_architecture/editor/editor_widget_todo.yaml`
- Terminal roadmap: `app_architecture/terminal/*_todo.yaml`

### Known Risk (High-Level)
- Incremental highlight edits can still be fragile; see TS-04 notes in the todo.

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
