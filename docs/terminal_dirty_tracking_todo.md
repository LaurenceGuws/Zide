# Terminal Dirty Tracking Cleanup

## Problem Summary

Full-screen TUIs that repeatedly clear and redraw the screen (e.g. `gping`, some `nvim` plugins) produce visual corruption:

- Scrollback content bleeds into the active viewport.
- Line overlays/gutters occasionally render with stale cells.
- Dirty tracking is inconsistent across clear/scroll operations, so partial redraws miss updates.
- `vttest` menu navigation becomes unreadable due to stale cells lingering between redraws.

These failures point to damage tracking that is too optimistic and not robust to repeated full-screen redraws without alternate screen usage.

## Observations (Current Implementation)

- `TerminalGrid` tracks `dirty_rows` and dirty column bounds; `clearDirty` resets rows/cols but does not fully track per-line history across scroll/clear operations.
- `TerminalSession.updateViewCacheNoLock` builds a view cache that merges scrollback + grid and uses dirty rows for partial redraws.
- When applications clear the screen (CSI 2J) and redraw, we rely on dirty rows/cols to repaint, but the system can miss full invalidation.
- Scrollback view cache (`TerminalHistory.ensureViewCache`) has its own generation and can be stale when full-screen redraws happen without scrollback changes.
- Origin mode (DECOM, CSI ? 6) and autowrap (CSI ? 7) semantics are being added; vttest still fails WRAP AROUND when cursor/clear/scroll interactions happen in rapid sequence.
- Found a VT parser/handler mismatch: CSI params with a single value set `params[0]` but keep `count=0`, so ED/EL/DECSTBM were treating `CSI 2 J` as `CSI 0 J` (clear-from-cursor). This leaves stale lines when vttest expects full clear.
- Audit note: scanned CSI handlers for direct `count` usage; only SGR and the shared `param_len` remain, so single-parameter CSI sequences are handled consistently now.
- Newline mode fix: LF should not reset column unless SM 20 (LNM) is enabled. Added LNM tracking and a replay fixture to ensure LF preserves column by default.
- Wrap fix: wrap-next now forces column reset on line advance regardless of LNM; added a replay fixture to cover multi-line star fills without blank rows.

## Reference Techniques

- **Alacritty**: frame-based damage tracker with per-line damage bounds and full-frame invalidation when needed (`reference_repos/terminals/alacritty/alacritty/src/display/damage.rs`).
- **Kitty**: explicit `is_dirty` + `scroll_changed` flags and full GPU reload paths for certain operations; overlay lines are tracked separately (`reference_repos/terminals/kitty/kitty/screen.c`).
- **WezTerm**: rewrap/scrollback logic keeps stable row indices and uses per-line sequence numbers to decide updates (`reference_repos/terminals/wezterm/term/src/screen.rs`).

## Proposal (High-Level)

1) Introduce a **frame damage tracker** for the terminal view (similar to Alacritty):
   - Maintain per-line damage bounds for each frame.
   - Explicitly mark full-frame damage on clear/scroll region changes, alt screen transitions, and scrollback invalidations.

2) Split **grid damage** from **scrollback view cache**:
   - When scrollback offset != 0, always rebuild view cache rows or mark full damage.
   - When screen is cleared (CSI 2J/3J), mark full damage and optionally invalidate view cache generation.

3) Make **scroll and clear operations** authoritative for damage:
   - Scroll region changes and `scrollRegionUp/Down` must mark full region dirty, not partial bounds.
   - `eraseDisplay` should mark full dirty for mode 2 and set a “clear generation” marker to force redraw.
   - Sync updates (CSI ? 2026) should buffer rendering and force full redraw on disable.

4) Add **replay fixtures** for full-screen TUIs:
   - Capture gping and nvim scope-plugin scenarios with the replay harness.
   - Verify no stale rows appear after sequences of clear + redraw.

## Todo

- [x] Audit all screen ops (`eraseDisplay`, scroll regions, scrollback pushes) for missing full-damage flags.
- Audit result: clear/scroll paths already set `force_full_damage` and/or `clear_generation`; insert/delete ops rely on grid dirty ranges and look consistent with partial redraw.
- [ ] Add a view-cache invalidation path for clear/scroll events (generation bump or full-dirty flag).
- [ ] Implement frame-based damage tracking (per-line bounds) and integrate with terminal widget partial redraw.
- [ ] Add replay harness fixtures for `gping` and a minimal `nvim` overlay example.
- [ ] Add replay harness fixture for vttest WRAP AROUND mode test.
- [ ] Add tests to assert no stale rows after clear+redraw cycles.
