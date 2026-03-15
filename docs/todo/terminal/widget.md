# Terminal Widget TODO

## Scope

Build a best-in-class embedded terminal widget for Zide, Linux first.

## Constraints

- Keep the fast path strong for ASCII monospace workloads.
- Preserve correctness for real TUIs such as `nvim`, `btop`, and `tmux`.
- Favor GPU-first rendering with low per-frame CPU cost.
- Treat this file as mixed current plan plus historical backlog; the active module layout now lives under `src/terminal/{core,model,parser,protocol,io,input,kitty}`.

## Performance Budgets

- Frame time: target `8.3ms`, max `16.7ms`
- Terminal render: target `2.0ms`, max `4.0ms`
- Parse throughput: target `200 MB/s`, minimum `100 MB/s`
- Input-to-draw latency: target `8ms`, max `16ms`

## TODO

### Phase 0 Architecture And Bench Harness

- [ ] `P0-01` Define the immutable terminal snapshot API used by the renderer.
- [ ] `P0-02` Add parse/render micro-benchmarks.
- [ ] `P0-03` Keep performance budgets documented and current.

### Phase 1 PTY And IO

- [ ] `P1-01` Linux PTY abstraction with non-blocking reads.
- [ ] `P1-02` Windows ConPTY and macOS PTY stubs.
- [ ] `P1-03` Event-loop integration without busy-waiting.

### Phase 2 VT Parser

- [ ] `P2-01` UTF-8 decoder and control-byte stream.
- [ ] `P2-02` CSI parser for movement, erase, scroll, insert, and delete.
- [ ] `P2-03` SGR handling for colors and attributes.
- [ ] `P2-04` OSC basics for title, clipboard, and hyperlinks.
- [ ] `P2-05` VT conformance tests from recorded sessions.

### Phase 3 Screen Model

- [ ] `P3-01` Grid storage with dirty tracking.
- [ ] `P3-02` Scrollback ring buffer.
- [ ] `P3-03` Selection and search hooks.

### Phase 3.5 Scrollback Reflow Redesign

- [x] `P3.5-01` Define the scrollback model with wrap metadata.
- [ ] `P3.5-02` Implement resize reflow from logical lines to rows.
- [x] `P3.5-03` Remap cursor and selection across reflow.
- [ ] `P3.5-04` Add scrollback correctness tests and harness coverage.

### Phase 4 Renderer Core

- [x] `P4-01` Background pass with solid rects per cell.
- [x] `P4-02` Glyph atlas with GPU texture and LRU eviction.
- [x] `P4-03` Glyph cache and instance buffer.
- [ ] `P4-04` Box drawing and special glyph fast path.
  Notes: the original task is superseded by the dedicated UI plan in `docs/todo/ui/terminal_special_glyphs.md`.

### Phase 5 Font And Shaping

- [ ] `P5-01` Font discovery and fallback chain.
- [ ] `P5-02` HarfBuzz shaping pipeline.
- [ ] `P5-03` Unicode width and grapheme segmentation.
- [ ] `P5-04` Emoji and color font baseline support.
- [ ] `P5-05` FreeType rasterization quality settings.

### Phase 6 Input And UX

- [ ] `P6-01` Key encoding, with later kitty keyboard protocol support.
- [ ] `P6-02` Mouse reporting for X10, VT200, and SGR.
- [ ] `P6-03` Selection and copy/paste integration.

### Phase 7 Correctness And Compatibility

- [ ] `P7-01` Alternate screen, cursor save/restore, and scroll regions.
- [ ] `P7-02` Hyperlinks and OSC 8.
- [ ] `P7-03` Truecolor and 256-color palette handling.
- [ ] `P7-04` Keyboard protocol extensions such as CSI u and kitty.
- [ ] `P7-05` DECCOLM 80/132-column semantics.

### Phase 8 Performance And Polish

- [ ] `P8-01` Dirty-line tracking and partial redraw.
- [ ] `P8-02` Texture upload batching and atlas compaction.
- [ ] `P8-03` Frame pacing and latency tracking.
- [ ] `P8-04` SIMD UTF-8 and batch parsing.
- [x] `P8-05` Batch terminal draw calls for glyphs and backgrounds.
- [x] `P8-06` Honor dirty column bounds in partial redraw.
- [x] `P8-07` Reduce render lock contention with double-buffered snapshots.
- [x] `P8-08` Keep hover/link styling in an overlay pass.
- [x] `P8-09` Skip `view_cells` rebuilds when idle.
- [x] `P8-10` Support Ctrl+click terminal paths into the editor.

### Phase 9 Tests And Fixtures

- [ ] `P9-01` Port vttest-like recordings into tests.
- [ ] `P9-02` Add a synthetic stream generator for fuzzing.
- [ ] `P9-03` Build a correctness corpus for widths and combining characters.
