# Editor Widget TODO

## Scope

Build a Linux-first editor widget and text engine with large-file performance, deterministic rendering, and strong editing semantics.

## Constraints

- Core correctness and performance before feature breadth.
- Keep editor widget and renderer modularized into view and render layers.
- Preserve immediate vs cached draw parity.
- Stabilize editing, rendering, performance, and protocol invariants before net-new features.
- Extraction-only slices must keep the existing regression authority green.

## Key Entry Points

- `src/main.zig`
- `src/editor/editor.zig`
- `src/editor/syntax.zig`
- `src/ui/widgets/editor_widget.zig`
- `src/ui/renderer.zig`

## TODO

- [x] `ED-00` Editor modularization plan
  - Plan captured in `app_architecture/editor/MODULARIZATION_PLAN.md`.

- [ ] `ED-01` Text model upgrade for large files
  - Audit and rope decision are complete.
  - Rope is the sole text model, with ownership transfer on file open, large-file `mmap` fallback strategy, bounded line-start caching, and balanced initial chunking.
  - Headless perf harnesses and perf gates exist.
  - Large-file tree-sitter deferral and lightweight fallback coloring are in place.
  - Rope undo/redo, adjacent merge, and undo grouping hooks exist.

- [ ] `ED-02` Undo/redo batching and history model
  - Group edits by command, merge adjacent inserts, and expose checkpoints for macros and multi-step operations.
  - Selection and caret state snapshots already restore multicaret layouts.

- [ ] `ED-03` Selections, multi-cursor, and column mode
  - Core selection scaffolding, rectangular editing, wrapped movement, grapheme-aware mapping, and shared scrollbar geometry are in place.
  - Routed actions cover multi-caret add, word-wise movement, visual extend, and large cursor jumps.
  - Selection overlay smoothing and Lua configuration controls are implemented.
  - Remaining work is hardening and finishing the column-mode surface.

- [ ] `ED-04` Syntax highlighting pipeline
  - Target incremental tree-sitter parsing with cached visible-range queries and layered highlights.

- [ ] `ED-05` Soft wrap and line layout engine
  - Target fast wrapping with width caching and correct handling of tabs, wide glyphs, and grapheme clusters.

