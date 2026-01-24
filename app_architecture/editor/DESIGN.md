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

- Text engine: `src/editor/rope.zig` (rope/piece-tree + undo/redo)
- Editor state: `src/editor/editor.zig`
- Syntax highlight: `src/editor/syntax.zig`
- View/render: `src/ui/widgets/editor_widget.zig`, `src/ui/renderer.zig`

## Roadmap docs (source of truth)

- `app_architecture/editor/editor_widget_todo.yaml` (end-to-end widget + features)
- `app_architecture/editor/protocol_todo.yaml` (text engine + editing semantics)
- `app_architecture/editor/rendering_todo.yaml` (layout + rendering pipeline)
- `app_architecture/editor/MODULARIZATION_PLAN.md` (layer split + migration steps)

## Decisions

2026-01-21
- Adopt terminal-style workflow for editor work: add explicit todo lists with
  reference repo paths for each task, and update them as tasks are completed.

2026-01-21
- Text model audit complete; migrated to a rope/piece-tree implementation with
  per-node aggregates (bytes + line breaks) and rope-based undo/redo.

2026-01-21
- Rope text model implemented and integrated (see
  `app_architecture/editor/text_model_rope.md`).
