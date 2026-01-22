# Agent Handoff (Zide)

Date: 2026-01-22

## Quick start for next agent

- Repo: `/home/home/personal/zide`
- Current focus: editor/widget + text engine roadmap (rope-only text model, selections, widget input).
- Key docs (editor):
  - `app_architecture/editor/DESIGN.md`
  - `app_architecture/editor/editor_widget_todo.yaml`
  - `app_architecture/editor/protocol_todo.yaml`
  - `app_architecture/editor/rendering_todo.yaml`
- Key docs (terminal, legacy reference):
  - `app_architecture/terminal/DESIGN.md`
  - `app_architecture/terminal/terminal_widget_todo.yaml`
  - `app_architecture/terminal/protocol_todo.yaml`

Suggested next steps:
1) Read `app_architecture/editor/editor_widget_todo.yaml` and its reference paths before coding.
2) Read `app_architecture/editor/protocol_todo.yaml` and `app_architecture/editor/rendering_todo.yaml` for per-feature guidance.
3) Identify the first editor milestone (ED-01/EP-01/ER-01) and begin implementation.
4) Update editor docs as tasks are completed (keep notes concise).

## Summary of this session

- Kitty graphics: PNG decoded to RGBA in core so dimensions are known for cursor advance; scrollback overlays now move with viewport.
- Kitty graphics: query (`a=q`) validates payloads and returns `ENODATA`/`EBADPNG`/`EINVAL` as appropriate; `ENOENT` for missing images; cycle + depth checks (`ECYCLE`/`ETOODEEP`) for parented placements.
- Kitty graphics: per-screen storage (primary vs alt) so alt apps like yazi can render without leaking to scrollback; alt entry/exit clears its own kitty state.
- Terminfo: added `assets/terminfo/xterm-kitty.info` and set TERM to xterm-kitty with fallback to xterm-256color when missing.
- Editor: piece-table removed; rope-only text model with undo/redo, batching, and grouping.
- Editor: selection set scaffolding + rectangular selection expansion and per-line editing.
- Editor: editor-only tests added (`zig build test-editor`) using `src/tests_main.zig` + `src/editor_tests.zig`.
- Editor widget: mouse drag selection wired (normal + Alt-rect) and selection overlay drawing added.
- Editor widget: drag selection now preserves selection while updating cursor.
- Editor widget: undo now groups edits per input tick to avoid over-merged inserts.
- Editor: undo/redo updates cursor based on last undo/redo op position.
- Editor widget: selection highlight now renders on empty lines.
- Editor widget: cursor/selection rendering uses UTF-8 codepoint columns for placement.
- Editor widget: long lines now use allocated buffers to avoid selection/cursor truncation.
- Editor widget: grapheme cluster mapping uses HarfBuzz cluster offsets for cursor/selection placement.
- Editor widget: per-frame cluster cache reduces HarfBuzz shaping overhead.
- Editor: per-line width cache now uses grapheme clusters when available.

## Current issues (editor)

- None noted.

## Current issues (terminal, parked)

- Codex input field background still does not render. Codex sends `OSC 10;?` and `OSC 11;?` queries only; no `48` background SGR observed. Raw CSI logging shows only `CSI 0/39/49 m`.
- Lazygit arrow navigation fixed via DECCKM, but re-validate after further input changes.
- NumLock state is not tracked; keypad always treated as keypad unless app keypad mode is disabled.
- XTGETTCAP support is minimal (TN/Co/RGB only).
- Kitty graphics: delete semantics are approximate (e.g., 'n/N' treated like 'i/I'); no placement queries, no animation support.
- Kitty graphics: virtual placements (U=1) are stored but not rendered; no unicode placeholder handling.
- Kitty graphics: file/temp/shm media support is basic; error mapping for file/shm failures is still coarse.

## Key changes (recent)

- `src/terminal/core/terminal.zig`
  - Kitty graphics: parsing/validation, chunking + zlib inflate, storage limits, delete actions, parented placements, query validation, per-screen storage, PNG decode, alt screen handling
- `src/terminal/parser/parser.zig`
  - DCS parser added (minimal)
- `src/ui/widgets/terminal_widget.zig`
  - Kitty z-layer ordering + viewport-aware overlay placement
- `src/terminal/io/pty_unix.zig`
  - TERM set to xterm-kitty with fallback to xterm-256color
- `src/terminal/parser/csi.zig`
  - max CSI params = 16
  - `:` treated as a separator in SGR
- `app_architecture/terminal/protocol_todo.yaml`
  - Checklist updated for completed tasks
- `scripts/manual.sh`
  - XTGETTCAP query helper

## Files to review first

- `src/terminal/core/terminal.zig`
- `src/terminal/parser/parser.zig`
- `src/terminal/parser/csi.zig`
- `app_architecture/terminal/DESIGN.md`
- `app_architecture/terminal/protocol_todo.yaml`

## Editor files to review

- `src/ui/widgets/editor_widget.zig`
- `src/main.zig`
- `src/editor/editor.zig`
- `src/editor/rope.zig`
- `src/editor_tests.zig`
- `src/tests_main.zig`
