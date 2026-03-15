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
  (`reference_repos/terminals/alacritty/alacritty/src/display/damage.rs`)
- Kitty: explicit dirty flags and full GPU reload paths for certain
  operations; overlays tracked separately
  (`reference_repos/terminals/kitty/kitty/screen.c`)
- WezTerm: rewrap/scrollback logic keeps stable row indices and uses per-line
  sequence numbers to decide updates
  (`reference_repos/terminals/wezterm/term/src/screen.rs`)

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
- [ ] Keep replay/manual authority current for real clear-and-redraw regressions
  that survive on the rewritten path.
- [ ] Continue collapsing damage/publication ownership into a smaller set of
  explicit contracts (model dirty, published cache, presented ack).
- [ ] Remove any remaining renderer-facing dirty-retirement assumptions that are
  still broader than the current publication contract requires.
