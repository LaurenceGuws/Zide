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
- SDL3 migration: SDL3-only build path; SDL2 fallback removed. See `app_architecture/ui/sdl3_migration_todo.yaml`.
- SDL3 input parity: terminal-only mode on Wayland now delivers printable text when built with SDL3; continue validation + cleanup.
- Terminal scrollback redesign: current resize/scrollback handling is inadequate; redesign is planned (see Phase 3.5 in `app_architecture/terminal/terminal_widget_todo.yaml`).

### Recent Changes (High-Level)
- SDL3 shim + build flag wired; SDL3 compile + runtime smoke on Linux pass.
- SDL3 window events and scaling fixes landed; SDL3 text input now flows in terminal-only on Wayland with SDL3 build.
- Added a scrollback reflow redesign plan and updated terminal design notes to mirror kitty/ghostty/wezterm techniques.
 - Began scrollback model rework (LogicalLine + ScrollbackBuffer) and reflow resize wiring; scrollback rendering no longer drops during scroll interactions.

### Constraints / Guardrails
- Handoff docs are high-level only; progress tracking lives in todo + app_architecture docs.
- Follow layering rules and import checks (see `tools/app_import_check.zig`).
- Default: no commits until the user approves after tests. If the user explicitly says to commit, treat that as approval.

### Where to Look for Details
- UI rendering plan + per-OS journey: `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- Renderer modularization + OS abstraction plan: `app_architecture/ui/renderer_todo.yaml`
- SDL3 migration tracker: `app_architecture/ui/sdl3_migration_todo.yaml`
- Editor widget roadmap: `app_architecture/editor/editor_widget_todo.yaml`
- Terminal roadmap: `app_architecture/terminal/*_todo.yaml`
- Terminal design notes: `app_architecture/terminal/DESIGN.md`
- Undo loop notes: `app_architecture/ui/DEVELOPMENT_JOURNEY.md` (known issue entry).

### Known Risk (High-Level)
- SDL3 is the only build path; regressions must be addressed promptly.
- Incremental highlight edits can still be fragile; see TS-04 notes in the todo.
- Terminal scrollback resize is still flawed; avoid deep work in this area until the redesign is implemented.
 - Scrollback view cache + reflow resizing are still in progress; expect instability during the redesign.

### In-Progress (Uncommitted)
- SDL3 input tracing + text input decoding changes (see `src/ui/renderer/input_logging.zig`, `src/platform/input_events.zig`, `src/platform/sdl_api.zig`).
- Temporary logging enabled in `~/.config/zide/init.lua` (input.sdl) pending cleanup.
 - Scrollback rework in progress (uncommitted):
   - `src/terminal/model/scrollback_buffer.zig` (new LogicalLine ring buffer)
   - `src/terminal/model/history.zig` (rewrap cache + scrollback generation)
   - `src/terminal/model/screen/grid.zig` (wrap flags)
   - `src/terminal/model/screen/screen.zig` (wrap flags set/cleared)
   - `src/terminal/core/terminal_session.zig` (reflow resize + scroll update path)
 - Local debug logging enabled: `terminal.core`, `terminal.scroll` in `~/.config/zide/init.lua`.

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
