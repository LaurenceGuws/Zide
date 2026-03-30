# Terminal Damage Tracking

This file tracks active damage/dirty follow-up work for the terminal pipeline.

Status note, 2026-03-15:

- This is no longer a broad incident queue for the main redraw rewrite.
- The highest-value native bugs that originally motivated this file have largely
  been closed on the rewritten path (`nvim`, `btop`, Codex scrollback, Zig
  progress redraw, focused input latency).
- Treat this file as a narrow cleanup/follow-up queue for publication ownership
  and replay authority, not as the primary terminal work queue.

It used to live under `app_architecture/terminal/rendering/` while the redraw
incident work was still actively reshaping ownership. It now lives under
`docs/todo/terminal/` because it is an active queue with supporting notes, not
current rendering architecture authority.

## Problem Summary

Full-screen TUIs that repeatedly clear and redraw the screen (for example
`gping` and some `nvim` plugins) can produce visual corruption:

- scrollback content bleeds into the active viewport
- line overlays and gutters occasionally render with stale cells
- dirty tracking is inconsistent across clear and scroll operations, so partial
  redraws miss updates
- `vttest` menu navigation can become unreadable due to stale cells lingering
  between redraws

These failures point to damage tracking that is too optimistic and not robust to
repeated full-screen redraws without alternate-screen usage.

## Observations

- The terminal grid tracks `dirty_rows` and dirty column bounds.
- The view-cache pipeline merges scrollback + grid and uses dirty rows for
  partial redraws.
- When applications clear the screen (`CSI 2J`) and redraw, we rely on dirty
  rows/cols to repaint, but the system can miss full invalidation.
- Scrollback view caching can become stale when full-screen redraws happen
  without scrollback changes.

Historical reference notes:

- A VT parser/handler mismatch once treated some single-parameter CSI sequences
  as defaults, leaving stale rows when a full clear was expected.
- LF should not reset column unless `SM 20` (`LNM`) is enabled.
- Wrap-next semantics force column reset on line advance regardless of `LNM`.

## Reference Techniques

- Alacritty: frame-based damage tracker with per-line damage bounds and
  full-frame invalidation when needed
  (`dev_references/terminals/alacritty/alacritty/src/display/damage.rs`)
- Kitty: explicit dirty flags and full GPU reload paths for certain
  operations; overlays tracked separately
  (`dev_references/terminals/kitty/kitty/screen.c`)
- WezTerm: rewrap/scrollback logic keeps stable row indices and uses per-line
  sequence numbers to decide updates
  (`dev_references/terminals/wezterm/term/src/screen.rs`)

## Current Follow-Up

1. Damage publication still depends on too many channels.
- Current channels include:
  - grid dirty rows/cols + dirty mode
  - `output_generation`
  - published render-cache generation
  - presented generation
  - `clear_generation`
  - `view_cache_pending`
- This is workable, but brittle because multiple callsites must keep these in
  sync.

2. `view_cache` is carrying more than damage projection.
- It now merges history + screen, selection overlay, row-hash refinement,
  viewport-shift publication, kitty ordering, and some redraw-policy decisions.
- That makes it both important and fragile: correctness and optimization live
  in the same layer.

3. Dirty acknowledgement is narrower, but the renderer still triggers it.
- `terminal_widget_draw` now uses a single backend-owned presented-ack API
  instead of selecting between multiple dirty-clear paths itself.
- Long-term, the renderer should consume a publication contract and not
  explicitly trigger retirement at all.

4. Some full-dirty paths are semantically justified, but still need explicit
ownership.
- Examples:
  - alt-screen transitions
  - resize reflow
  - `DECSTR`
  - unresolved kitty geometry fallback
- These should remain deliberate publication events, not incidental renderer
  policy.

## Remaining Queue

- [x] Add replay harness fixtures for `gping` and a minimal `nvim` overlay
  example (`gping_redraw`, `nvim_overlay`).
- [x] Add replay harness fixture for `vttest` wraparound mode test
  (`vttest_wraparound`).
- [ ] Defer the intermittent Codex completion-tail corruption bug again until
  repro authority is stable.
  Notes:
  - Dogfood report, 2026-03-16:
    - intermittent corruption near the final Codex assistant summary dump
    - partial-row / half-cell-looking UI defects that clear on the next input
      wake
    - the bug is unusually hard to catch in action because added visibility
      itself suppresses the repro: once we increase runtime logging or similar
      instrumentation, the corruption tends to stop triggering
  - Codex reference check confirms the final assistant tail is flushed through a
    distinct completion path rather than the normal newline-gated incremental
    path (`dev_references/terminals/codex/.../streaming/controller.rs`,
    `.../chatwidget.rs`).
  - Detailed Codex-side behavior already inspected locally:
    - normal streaming accumulates text and only emits completed lines once a
      delta includes `\\n`
    - trailing text without a newline remains buffered
    - on completion, Codex calls a separate flush/finalize path that drains the
      remaining buffered tail in one shot
    - relevant local references:
      - `dev_references/terminals/codex/codex-rs/tui_app_server/src/streaming/controller.rs`
      - `dev_references/terminals/codex/codex-rs/tui_app_server/src/chatwidget.rs`
      - `dev_references/terminals/codex/codex-rs/tui_app_server/src/markdown_stream.rs`
  - Current Zide reduced-log captures still have one useful clue:
    - the interesting completion-tail burst is not a visible-history / scroll
      shift case
    - current capture near the end of the run shows two clean advances followed
      by one bottom-of-viewport 2-row partial publish (`1537 -> 1540`) with
      `visible_history_changed=0` and `shift_rows=0`
    - that pushes suspicion away from scrollback corruption and toward a
      renderer/present consumption issue for an in-place partial update
  - Low-noise regression tests now rule out the easy backend theories:
    - blank exposed rows are not dropped by live-bottom shift publication
    - unpresented visible-history updates with `full/empty/full/empty` row
      shape still stay conservative
    - bottom-edge in-place footer rewrites with a `full/empty/full/empty`
      shape still keep blank separator rows dirty and visible in the published
      cache
  - Current judgment:
    - treat this as a cadence-sensitive UI/present invalidation bug around the
      completion-tail partial publish, not as confirmed scrollback corruption
      and not as a generic Codex parser/protocol bug
    - avoid escalating logging in the hot path unless we have no alternative,
      because instrumentation itself is now known to distort the repro
  - Latest status, 2026-03-17:
    - a pacing/present seam change on `main` now keeps redraw pressure keyed to
      `published_generation != presented_generation` instead of “we drew once”
    - short live re-checks against Codex did not reproduce the bug after that
      change
    - keep this issue deferred for now anyway; that is not enough authority to
      declare it fixed
    - only close it after longer normal dogfooding or a more decisive repro
      disappearance across the original trigger lane
  - Follow-up cut, 2026-03-30:
    - the live-bottom viewport-shift fast path was still allowed when visible
      history advanced and the current viewport also carried ordinary partial
      dirty rows
    - that mixed case is exactly where renderer texture self-copy is most
      likely to flash stale content under heavy streaming/clear workloads
    - current direction is more conservative:
      - keep viewport-shift publication for clean live scroll advancement
      - forbid the shift fast path when the same publication also carries
        in-place visible-grid dirtiness
    - treat any remaining Codex-style flicker after this cut as a narrower
      present/partial-consumption bug, not as a generic live-scroll-shift issue
  - Resume only when we have one of:
    - a reliable manual repro
    - a deterministic capture/log slice that actually shows the bad frame
    - a replay-style minimized stream that reproduces the corruption without
      timing-sensitive logging
- [x] Re-check the earlier Codex live-resize corruption report on current
  `main`.
  Result:
  - latest user re-check on 2026-03-17 did not reproduce corruption during GUI
    zoom plus Hyprland-driven window tiling/resize while Codex was actively
    streaming
  - treat the earlier resize report as currently non-repro on `main`
  - reopen only if a fresh repro appears
- [ ] Keep replay/manual authority current for real clear-and-redraw regressions
  that survive on the rewritten path.
- [ ] Continue collapsing damage/publication ownership into a smaller set of
  explicit contracts (model dirty, published cache, presented ack).
- [ ] Remove any remaining renderer-facing dirty-retirement assumptions that are
  still broader than the current publication contract requires.
