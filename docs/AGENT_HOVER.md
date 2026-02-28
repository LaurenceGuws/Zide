# Agent Handover (High-Level Editor Context)

Date: 2026-02-28

This file is intentionally high-level. Detailed progress and research live in:
- `app_architecture/ui/renderer_todo.yaml`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `app_architecture/ui/ui_widget_modularization_todo.yaml`
- `app_architecture/ui/font_rendering_todo.yaml`
See `docs/INDEX.md` for the full doc map.

High-level state:
- Terminal FFI Bridge base is landed and under active extension (`app_architecture/terminal/ffi_bridge_todo.yaml`).
- Config subsystem contract is established, with hardened parser and live reload (`app_architecture/config_todo.yaml`, `app_architecture/CONFIG.md`).
- Editor multi-cursor editing is maturing, recently gaining caret preservation across edits and routing via Lua keybinds (`app_architecture/editor/editor_widget_todo.yaml`).
- Editor search/replace track is now in progress with literal+regex query scaffolding, active match navigation, and render overlays in both immediate + cached paths (`app_architecture/editor/editor_widget_todo.yaml`, `app_architecture/editor/protocol_todo.yaml`, `src/editor/editor.zig`, `src/ui/widgets/editor_widget_draw.zig`).
- Tree-sitter render integration advanced with shared stable token ordering across immediate + cached paths and new comparator regression tests (`app_architecture/editor/treesitter_todo.yaml`, `src/editor/syntax.zig`, `src/editor/render/cache.zig`, `src/editor_tests.zig`).
- Font rendering strategy remains an ongoing focus: close the quality gap vs kitty/ghostty (especially for IosevkaTerm).
  - Plan/todo: `app_architecture/ui/font_rendering_todo.yaml`
  - Architecture doc: `app_architecture/ui/font_rendering_architecture.md`
  - Primary Zide files: `src/ui/terminal_font.zig`, `src/ui/renderer/gl_backend.zig`
  - Fixtures for regression signals (not called goldens yet): `fixtures/ui/font_sample/`
- UI widget modularization remains an active maintenance track; TerminalWidget has been split and should stay stable.
  - Plan/todo: `app_architecture/ui/ui_widget_modularization_todo.yaml`
- Terminal backend modularization is largely complete, but terminal changes should still keep the replay harness green.
  - Terminal plan: `app_architecture/terminal/MODULARIZATION_PLAN.md`
  - Run: `zig build test-terminal-replay -- --all`
- SDL3 + OpenGL is the Linux baseline; keep SDL3 parity stable while UI modularization lands.
- Logs are authoritative for debugging; the agent owns `./.zide.lua` to tune log tags without permission.

Recent notable additions:
- Terminal FFI bridge (`src/terminal/ffi/bridge.zig`) + Python ctypes smoke host.
- Config reload dynamically applies font rendering knobs and re-sizes terminal.
- Editor carets preserved during edits + vertical expansion shortcuts (`editor_add_caret_up/down`).
- Editor tests now include search navigation/regex coverage and immediate-vs-cached conceal/url parity checks (`src/editor_tests.zig`).
- Terminal reflow tests were stabilized to assert semantic outcomes across reflow/view-cache layouts (`src/terminal_reflow_tests.zig`).
- Linear text pipeline: coverage atlas (R8) + premultiplied blending + linear offscreen rendering + explicit present conversion.
- Luminance-based linear correction (ghostty-style), with per-glyph background plumbed for terminal and editor.
- FreeType hinting/autohint knobs moved into Lua config (`assets/config/init.lua`).
- Terminal combining marks supported as grapheme clusters (cell stores combining marks; renderer draws shaped cluster).
- Terminal + editor ligature shaping enabled with kitty/ghostty-style controls via Lua config.
- Editor selection overlay rendering/caching stabilized (no known multiline seam issue at handoff level).

If this file conflicts with the todo/app_architecture docs, treat it as stale and update/remove it.
