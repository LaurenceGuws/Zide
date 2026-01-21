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

