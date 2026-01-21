# Editor Design & Decision Log

Goal: ship a best-in-class editor widget and text engine (Linux-first) that reaches
Notepad++-level capability while keeping Zide's core fast and minimal.

## Principles

- Fast edits on large files (avoid O(n) in hot paths).
- Correct Unicode and grapheme handling for cursor movement and selection.
- Low-latency rendering with caching and damage tracking.
- Incremental syntax highlighting with predictable latency.
- Clear separation between text engine, editor state, and UI view.

## Current architecture (Zide)

- Text engine: `src/editor/buffer.zig` (piece table + undo/redo)
- Editor state: `src/editor/editor.zig`
- Syntax highlight: `src/editor/syntax.zig`
- View/render: `src/ui/widgets/editor_widget.zig`, `src/ui/renderer.zig`

## Roadmap docs (source of truth)

- `app_architecture/editor/editor_widget_todo.yaml` (end-to-end widget + features)
- `app_architecture/editor/protocol_todo.yaml` (text engine + editing semantics)
- `app_architecture/editor/rendering_todo.yaml` (layout + rendering pipeline)

## Decisions

2026-01-21
- Adopt terminal-style workflow for editor work: add explicit todo lists with
  reference repo paths for each task, and update them as tasks are completed.

2026-01-21
- Text model audit (EP-01) complete. Current buffer is a piece table backed by
  `original` + `add` arrays with a flat `pieces` array. Inserts/deletes are
  O(n) due to array insertion/removal, and `findPiece` is linear with a small
  "last piece" cache. Line indexing is a `line_starts` array of byte offsets,
  updated incrementally only when index is ready; otherwise it is rebuilt
  (sync for memory buffers, async for file-backed buffers). All cursor and
  selection math is byte-based; no UTF-8/UTF-16/grapheme indexing yet.
- Text model upgrade plan drafted: introduce a rope-like balanced tree or
  piece-tree with per-node aggregates (bytes + line breaks, later UTF-8/UTF-16
  code unit counts). This yields O(log n) edits and offset/line queries,
  plus cheap snapshots/clones. Line index cache becomes an in-tree aggregate
  (or Scintilla-style partitioning) rather than a full rebuild array.
- Decision needed: implement a native rope/tree in Zig vs. optimize current
  piece table with a separate balanced index layer. If we keep piece-table,
  add a tree of pieces + gapless piece coalescing and switch line index to a
  partitioning structure similar to Scintilla's `LineVector`.

2026-01-21
- Decision: adopt a rope/piece-tree text model. Draft design in
  `app_architecture/editor/text_model_rope.md`. Added `src/editor/rope.zig`
  scaffold (not yet integrated).
