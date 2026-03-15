# Editor Protocol TODO

## Scope

Text engine and editing semantics: buffer model, undo, selections, search, and folding.

## Constraints

- Core protocol semantics before advanced UX.
- Modularize editor view/state before behavior changes.
- Large-file performance and bounded allocations.
- Unicode and grapheme correctness.
- Deterministic undo/redo and cursor mapping.
- Every protocol or state change needs focused regression coverage.

## Reference Map

- Helix: `reference_repos/editors/helix/docs/architecture.md`, `helix-core/src/transaction.rs`, `helix-core/src/selection.rs`
- Neovim: `reference_repos/editors/neovim/src/nvim/{buffer.c,undo.c,search.c,fold.c}`
- Kakoune: `reference_repos/editors/kakoune/src/{buffer.cc,selection.cc}`
- Xi: `reference_repos/editors/xi-editor/rust/core-lib/src/{editor.rs,selection.rs,linewrap.rs}`
- Scintilla: `reference_repos/text/scintilla/src/{Editor.c,Document.cxx,CellBuffer.cxx}`
- Ropey / xi-rope: `reference_repos/text/{ropey,xi-rope}/src/*`

## TODO

- [x] `EP-01` Text model audit and upgrade plan
  - Authority lives in `app_architecture/editor/DESIGN.md`.
  - Decision: rope / piece-tree.
  - File-backed `TextStore` now hands read buffers directly into rope ownership.
  - Large-file path supports threshold-based `mmap` with fallback and bounded line-start caching.
  - `zig build perf-editor-headless` covers open cost, line-start throughput, and viewport-pass throughput.
  - Initial rope build now uses balanced chunked leaves for materially better large-file query latency.
  - Very large files can skip tree-sitter and fall back to lightweight syntax cues.
  - Editor FFI baseline exists, including range edits, undo grouping, multicaret accessors, and search/replace hooks.
  - `examples/editor_ffi_smoke/` provides a Python ctypes smoke host.

- [ ] `EP-02` Undo/redo model and batching rules
  - Adjacent inserts and deletes merge in rope history.
  - Undo groups are implemented and widget input batches edits per input tick.
  - Undo/redo restores cursor plus selection/caret snapshots, including mixed multi-range and rectangular states.

- [ ] `EP-03` Selections, multi-cursor, and column mode
  - Selection set scaffolding, rectangular expansion, and rectangular editing are in place.
  - Routed actions now cover add-caret, extend, large visual move/extend, and word-wise movement.
  - Copy/cut/paste and caret ownership semantics are explicit for mixed multi-selection and rectangular cases.
  - Cluster-aware rectangular editing and visual-column mapping have regression coverage.

- [ ] `EP-04` Search/replace and regex engine
  - Incremental search state, highlights, active-match navigation, literal and regex entrypoints, and grouped replace operations exist.
  - Undo/redo keeps search state synchronized.
  - Status-bar search UX is wired; current priority is correctness hardening before find-in-files expansion.

- [ ] `EP-05` Folding model and markers
  - Deferred until undo/selection/search semantics above are stable and test-backed.
  - Target syntax-driven folds plus manual markers.

