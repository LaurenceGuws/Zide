# Editor Modularization Plan

Date: 2026-01-24

Goal: split the editor into clear layers with stable APIs so we can grow features without ballooning `editor_widget.zig` or `renderer.zig`.

## Scope
- Editor widget + text engine + syntax + rendering pipeline (editor-side).
- Preserve current behavior; start with extraction-only refactors.
- Keep hot paths allocation-light (per editor design principles).

## Constraints
- Small, reviewable diffs.
- No behavior changes during extraction-only refactors.
- Behavior changes require a harness-backed baseline (now in place for editor render).

## Target Layer Split
1) UI Widget (input + draw orchestration)
   - `src/ui/widgets/editor_widget.zig`
2) View Model (layout, selections, cursor navigation, view state)
   - `src/editor/view/*` (new)
3) Editor Core (commands, undo/redo, selection model)
   - `src/editor/editor.zig`
4) Text Model (rope/piece tree)
   - `src/editor/rope.zig`
5) Syntax/Highlight
   - `src/editor/syntax.zig`
6) Rendering Support (glyph metrics, caching, draw lists)
   - `src/ui/renderer.zig` (split later)

## Proposed Module Map (incremental)
- `src/editor/view/layout.zig` — line/column to pixel mapping, line wrapping, viewport transforms.
- `src/editor/view/cursor.zig` — cursor movement rules (word, line, page).
- `src/editor/view/selection.zig` — selection model + normalization.
- `src/editor/view/scroll.zig` — scroll offsets + caret visibility.
- `src/editor/view/metrics.zig` — cached line metrics (height, column widths).

- `src/editor/render/draw_list.zig` — editor draw primitives (text runs, highlights, cursors).
- `src/editor/render/highlight.zig` — syntax highlight to draw spans.

(Names are targets; start with extracting one subsystem per step.)

## Stable API Surface (proposed)
EditorWidget should depend on:
- `EditorSession` (commands + state)
- `EditorView` (layout/selection/scroll)
- `EditorDrawList` (render-ready primitives)

Proposed contracts (sketch):
- `EditorSession` owns text model + undo/redo.
- `EditorView` owns viewport, cursor, selection, and exposes layout queries.
- `EditorDrawList` is immutable per-frame and allocation-free during render.

## Layering Rules (imports)
- `ui/widgets/editor_widget.zig` → `editor/view/*`, `editor/editor.zig`, `editor/render/*`.
- `editor/view/*` → `editor/editor.zig`, `editor/text_store.zig`, `editor/rope.zig`, `editor/syntax.zig` (read-only), `editor/types.zig`, no UI.
- `editor/render/*` → `editor/view/*`, `editor/syntax.zig`, `editor/types.zig`, no UI.
- `editor/editor.zig` → `editor/text_store.zig`, `editor/rope.zig`, `editor/syntax.zig`, `editor/types.zig` only.

Use `zig build check-editor-imports` to enforce these rules.

## Migration Steps (incremental)
1) Extract view state (cursor + selection) into `src/editor/view/selection.zig`.
2) Extract layout helpers into `src/editor/view/layout.zig`.
3) Extract scrolling logic into `src/editor/view/scroll.zig`.
4) Introduce `EditorDrawList` to decouple rendering.
5) Split `editor_widget.zig` into input + draw orchestration.
6) Split renderer editor-specific code into `src/editor/render/*`.
7) Add editor render snapshot harness (baseline draw ops).
8) Implement render cache + dirty redraw path (render texture + per-seg hashing).

## Non-goals (for now)
- No new features or UI changes.
- No text model changes unless tests are added first.
- No renderer-wide refactors before editor harness exists.
