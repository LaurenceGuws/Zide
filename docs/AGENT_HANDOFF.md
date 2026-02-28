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
- The active streams of work have diversified recently into terminal FFI bridge, config subsystem maturation, and editor multi-selection:
  - **Terminal FFI Bridge**: Base bridge landed with python smoke host (`app_architecture/terminal/ffi_bridge_todo.yaml`).
  - **Config Subsystem**: Parser hardened, reload truth aligned, and subsystem contract formalized (`app_architecture/config_todo.yaml`, `app_architecture/CONFIG.md`).
  - **Editor Multi-cursor**: Carets preserved across edits, multi-caret vertical expansion shortcuts routed via Lua keybinds (`app_architecture/editor/editor_widget_todo.yaml`, `app_architecture/editor/protocol_todo.yaml`).
- Font rendering strategy (terminal + editor) is also an ongoing priority: make our text rendering competitive with kitty/ghostty-tier quality.
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
- Editor multi-selection carets are now preserved during edits, with multi-caret vertical expansion shortcuts routed via Lua keybinds (`editor_add_caret_up` / `editor_add_caret_down`).
- Editor tree-sitter render integration advanced: immediate + cached draw now share a stable `HighlightToken` comparator, with new regression tests for equal-range capture ordering and conceal/url metadata behavior (`app_architecture/editor/treesitter_todo.yaml`, `src/editor/syntax.zig`, `src/editor/render/cache.zig`, `src/editor_tests.zig`).
- Editor search scaffolding advanced to `in_progress`: literal + regex query entrypoints, incremental in-buffer match collection, active match next/prev navigation, and cursor jump to active match (`app_architecture/editor/editor_widget_todo.yaml`, `app_architecture/editor/protocol_todo.yaml`, `src/editor/editor.zig`).
- Editor rendering now overlays search matches in both immediate and cached paths (`src/ui/widgets/editor_widget_draw.zig`).
- Config subsystem contract established: `app_architecture/CONFIG.md` and `app_architecture/config_todo.yaml` define parser/runtime/reload behavior. Config reload now live-applies font rendering changes.
- Terminal FFI bridge baseline landed (`src/terminal/ffi/bridge.zig`): stable snapshot export, PTY ABI, event queue, and a standalone Python ctypes smoke host.
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
- `./.zide.lua` logging workflow was tightened: agent owns log configuration and should keep bug-scoped low-noise tags (currently focused on `terminal.glyph.special` during powerline work; file logging can be disabled for interactive debugging).
- Powerline pipeline status:
  - Current active path is sprite-only for `U+E0B0..U+E0B3` with analytic geometry + supersample/downsample coverage masks.
  - Outline-preference experiment was tried and reverted due visible pixelation regression.
  - Best quality so far was committed as baseline (`71a02df`) before continued tuning.
- SDL/SDL_ttf documentation sweep was completed from `reference_repos/sdlwiki_md` (DPI, hinting, LCD/subpixel, texture scaling, Wayland scaling notes) and summarized in `app_architecture/ui/terminal_special_glyph_todo.yaml` `research_notes`.

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
- Editor uncommitted progress:
  - Search scaffold + navigation + regex entrypoint + render overlays.
  - Tree-sitter render-order stability tests and shared comparator rollout.
  - Test harness updates for highlight replay/input/reflow API drift.
- Workspace note:
  - `.github/workflows/ci.yml` is intentionally deleted for this pet project (do not restore unless user asks).

### Next Agent Should Do
- Continue `TSG-2-04` only (single pipeline), avoid reintroducing alternate powerline paths until quality is accepted.
- Keep `terminal.glyph.special` logging scoped in `./.zide.lua` and collect zoom-specific observations against `term_cell` sizes.
- Execute a controlled parameter sweep for filled vs thin separators within the same pipeline:
  - supersample factor
  - stroke thickness quantization
  - seam extension
  - downsample kernel behavior
- Promote changes only if they improve both startup quality and zoom consistency across dynamic render scales (use `1.6` only as one checkpoint, not the optimization target).

### Checklist
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
- Smoke:
  - `zig build run -- --mode terminal`
  - `ZIDE_FONT_SAMPLE_FRAMES=2 ZIDE_FONT_SAMPLE_SCREENSHOT=/tmp/font.ppm zig build run -- --mode font-sample`
