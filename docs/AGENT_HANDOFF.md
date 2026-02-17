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
- Font rendering strategy (terminal + editor): make our text rendering competitive with kitty/ghostty-tier quality.
  - Primary stress font: `assets/fonts/IosevkaTermNerdFont-Regular.ttf` (still under iteration); JetBrainsMono is the secondary sanity font.
  - Source of truth: `app_architecture/ui/font_rendering_todo.yaml`
  - Key files: `src/ui/terminal_font.zig`, `src/ui/renderer/gl_backend.zig`, `src/ui/renderer/font_manager.zig`, `src/ui/renderer/terminal_glyphs.zig`, `src/ui/widgets/terminal_widget_draw.zig`
  - Architecture doc: `app_architecture/ui/font_rendering_architecture.md`
  - Special-glyph docs: `app_architecture/ui/terminal_special_glyph_coverage.md`, `app_architecture/ui/terminal_special_glyph_todo.yaml`
  - Regression signals (not called goldens yet): `fixtures/ui/font_sample/`
- UI widget modularization is largely complete for TerminalWidget; keep using the established split pattern.
  - Plan/todo: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Terminal backend modularization is largely complete; still keep replay harness green when touching terminal code.
  - Terminal plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - Run: `zig build test-terminal-replay -- --all`
- SDL3 migration remains the baseline; keep parity stable while UI changes land (see `app_architecture/ui/sdl3_migration_todo.yaml`).

### Recent Changes (High-Level)
- Terminal replay harness now supports `--update-goldens` for snapshot refresh.
- New replay fixtures for gping/nvim overlay + vttest wraparound; goldens updated.
- Modularization extractions: render cache, palette/dynamic colors, OSC helpers (semantic, clipboard, CWD, hyperlink, title), input helpers (mouse, key encoding).
- Added UI widget modularization todo to guide widget-level extraction work (TerminalWidget UI-side split).
- Added a font comparison harness mode: `zig build run -- --mode font-sample` (JetBrainsMono vs IosevkaTerm side-by-side).
- Font rendering pipeline upgrades:
  - Split atlas: coverage (R8) vs color (RGBA8).
  - Premultiplied blending for coverage, linear offscreen rendering, explicit present conversion.
  - Optional luminance-based linear correction (ghostty-style) with per-glyph background plumbed.
- Config knobs moved into Lua example config: `assets/config/init.lua` (`font_rendering.*`).
- Editor parity: selection/current-line/gutter now supply per-text background so correction stays stable.
- Terminal correctness: combining marks attach to prior cell; renderer can draw a shaped grapheme cluster for a cell.
- Fixture authority expanded: `fixtures/ui/font_sample/jbmono_iosevka_size{12,14,16,20}.ppm` include multiple background bands.
- Terminal + editor now support first-class ligature shaping with config controls (`terminal.disable_ligatures`, `terminal.font_features`, `editor.disable_ligatures`, `editor.font_features`).
- Editor multiline selection overlay seams were fixed and deselect cleanup now invalidates cached overlays correctly.
- Terminal draw now locks the session cache during render to avoid stale view-cache reads during rapid zoom/resize.
- Special-glyph rendering work is in active iteration for powerline separators (`   `) and is not quality-complete yet.

### Constraints / Guardrails
- Handoff docs are high-level only; progress tracking lives in todo + app_architecture docs.
- Follow layering rules and import checks (see `tools/app_import_check.zig`).
- Default: no commits until the user approves after tests. If the user explicitly says to commit, treat that as approval.
- Use logs as a primary source of truth when debugging; configure logging via `./.zide.lua` without asking for permission.

### Where to Look for Details
- UI rendering plan + per-OS journey: `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- Renderer modularization + OS abstraction plan: `app_architecture/ui/renderer_todo.yaml`
- SDL3 migration tracker: `app_architecture/ui/sdl3_migration_todo.yaml`
- Font rendering improvement plan: `app_architecture/ui/font_rendering_todo.yaml`
- Font rendering architecture: `app_architecture/ui/font_rendering_architecture.md`
- Special glyph coverage + execution plan: `app_architecture/ui/terminal_special_glyph_coverage.md`, `app_architecture/ui/terminal_special_glyph_todo.yaml`
- Font sample fixtures: `fixtures/ui/font_sample/README.txt`
- UI widget modularization plan: `app_architecture/ui/ui_widget_modularization_todo.yaml`
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
- Terminal special-glyph powerline experiments are currently in progress in `src/ui/renderer/terminal_glyphs.zig` and `src/ui/widgets/terminal_widget_draw.zig`.
- Docs were expanded with dedicated special-glyph coverage + todo files; keep those in sync with code status while iterating.

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
- Smoke:
  - `zig build run -- --mode terminal`
  - `ZIDE_FONT_SAMPLE_FRAMES=2 ZIDE_FONT_SAMPLE_SCREENSHOT=/tmp/font.ppm zig build run -- --mode font-sample`
