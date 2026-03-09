# Terminal Damage/Dirty Tracking (Notes + Todo)

This doc captures research notes and a running todo for terminal damage tracking.
It intentionally lives under `app_architecture/terminal/` (not `docs/`) so it can
hold detailed implementation notes.

## Problem Summary

Full-screen TUIs that repeatedly clear and redraw the screen (e.g. `gping`, some
`nvim` plugins) can produce visual corruption:

- Scrollback content bleeds into the active viewport.
- Line overlays/gutters occasionally render with stale cells.
- Dirty tracking is inconsistent across clear/scroll operations, so partial redraws miss updates.
- `vttest` menu navigation can become unreadable due to stale cells lingering between redraws.

These failures point to damage tracking that is too optimistic and not robust to
repeated full-screen redraws without alternate screen usage.

## Observations (Current Implementation)

- The terminal grid tracks `dirty_rows` and dirty column bounds.
- The view cache pipeline merges scrollback + grid and uses dirty rows for partial redraws.
- When applications clear the screen (CSI 2J) and redraw, we rely on dirty rows/cols to repaint, but the system can miss full invalidation.
- Scrollback view caching can become stale when full-screen redraws happen without scrollback changes.

Historical fixes/notes (keep as reference):
- Found a VT parser/handler mismatch where some single-parameter CSI sequences were treated as defaults, leaving stale rows when full clear was expected.
- Newline mode: LF should not reset column unless SM 20 (LNM) is enabled.
- Wrap-next semantics: wrap-next forces column reset on line advance regardless of LNM.

## Reference Techniques

- Alacritty: frame-based damage tracker with per-line damage bounds and full-frame invalidation when needed (`reference_repos/terminals/alacritty/alacritty/src/display/damage.rs`).
- Kitty: explicit dirty flags and full GPU reload paths for certain operations; overlays tracked separately (`reference_repos/terminals/kitty/kitty/screen.c`).
- WezTerm: rewrap/scrollback logic keeps stable row indices and uses per-line sequence numbers to decide updates (`reference_repos/terminals/wezterm/term/src/screen.rs`).

## Proposal (High-Level)

1) Introduce a frame damage tracker (similar to Alacritty):
- Maintain per-line damage bounds for each frame.
- Explicitly mark full-frame damage on clear/scroll region changes, alt screen transitions, and scrollback invalidations.

2) Split grid damage from scrollback view cache:
- When scrollback offset != 0, rebuild view cache rows or mark full damage.
- When screen is cleared (CSI 2J/3J), mark full damage and optionally invalidate view cache generation.

3) Make scroll and clear operations authoritative for damage:
- Scroll region changes and scrollRegionUp/Down must mark full region dirty, not partial bounds.
- eraseDisplay should mark full dirty for mode 2 and set a clear-generation marker to force redraw.
- Sync updates (CSI ? 2026) should buffer rendering while active; disable should publish the buffered real damage rather than inventing a blanket full redraw.

4) Add replay fixtures for full-screen TUIs:
- Capture gping/nvim redraw scenarios with the replay harness.
- Assert no stale rows appear after sequences of clear + redraw.

## Todo

- [x] Add replay harness fixtures for `gping` and a minimal `nvim` overlay example (`gping_redraw`, `nvim_overlay`).
- [x] Add replay harness fixture for vttest wraparound mode test (`vttest_wraparound`).
- [ ] Add explicit assertions/tests that no stale rows remain after clear+redraw cycles.
- [ ] Consider a frame-based damage tracker and integrate with terminal widget partial redraw.
