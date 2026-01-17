# Terminal Design & Decision Log

Date: 2026-01-17

Purpose: this document tracks terminal architecture decisions and implementation progress. It is not a fixed plan. Each layer will be researched in the reference repos before implementation, and this file will be updated with concrete decisions as they are made.

## Status Summary

- Terminal backend stub replaced by a working PTY + minimal VT pipeline.
- Shell output renders with basic cursor movement, erase ops, and SGR (16/256/truecolor).
- Scrollback ring buffer captures full‑screen scrolls and is exposed via a scrollbar + offset.
- Still missing: dirty‑row tracking and full VT coverage.

## Decisions & Progress by Layer

### Layer 0: UI Integration (Widget + Renderer)

Progress:
- Terminal widget renders from a single snapshot per frame instead of per‑cell getters.

Decision:
- Render from contiguous snapshot data to minimize call overhead and improve cache locality.

Why:
- Hot paths must be allocation‑free and branch‑light.

Notes:
- Rendering uses two passes (bg then glyphs) and a dedicated terminal font pipeline.

### Layer 1: Snapshot API

Progress:
- `TerminalSnapshot` exists and is returned by `TerminalSession.snapshot()`.
- Snapshot includes rows/cols, flat cell slice, cursor, dirty state, and damage rect.
- Dirty state is cleared after snapshot creation.

Decision:
- Snapshot is immutable and backed by terminal‑owned memory, valid for one frame.

Why:
- Matches high‑performance render‑state patterns and avoids per‑frame allocations.

### Layer 2: PTY + IO

Progress:
- Implemented cross‑platform PTY API with Linux `openpty`, macOS login shell handling, and Windows ConPTY stub.
- PTY output is piped into the VT stream; input is sent back to PTY.

Research notes:
- Alacritty (Unix) uses `openpty`, sets IUTF8 on the master, spawns with `setsid` + `TIOCSCTTY`, and polls for PTY + child exit.
- Alacritty (Windows) uses ConPTY + `CreateProcessW` with pseudoconsole attributes.
- foot uses `posix_openpt` + `grantpt` + `unlockpt`, and validates shells.
- wezterm (Unix) splits read/write handles and uses wake pipes.
- libtsm emphasizes edge‑triggered polling and read‑until‑EAGAIN.

Decision:
- Linux: `openpty` (master/slave) + fork/exec + `setsid` + `TIOCSCTTY`.
- macOS: same, with login shell handling.
- Windows: ConPTY with anonymous pipes and `CreateProcessW`.
- Non‑blocking master/pipe with read‑until‑EAGAIN.
- Resize via `TIOCSWINSZ` (Unix) / `ResizePseudoConsole` (Windows).

Why:
- Mirrors battle‑tested terminal implementations and avoids PTY HUP pitfalls.

### Layer 3: VT Parser

Progress:
- Minimal UTF‑8 stream decoder and CSI parser implemented.
- ESC + CSI sequences are now interpreted instead of printed.

Decision:
- Incremental byte stream -> UTF‑8 decoder -> control/CSI parser.

Why:
- Low‑latency streaming; no buffering needed for most inputs.

Current coverage:
- Cursor moves: `A/B/C/D`, `E/F`, `G`, `H/f`, `d`
- Erase: `J`, `K`
- Insert/delete: `@`, `P`, `L`, `M`
- Scroll region: `r`, `S`, `T`
- Reset: `ESC c`
- SGR: 16‑color + 256‑color + truecolor, bold/reverse

### Layer 4: Screen Model (Grid + Scrollback)

Progress:
- Flat grid exists with basic scrolling and line erase.
- Scroll region support added.
- Scrollback ring buffer stores rows on full‑screen scroll; cleared on column resize.
- Terminal UI can render scrollback with a right-side scrollbar and scroll offset.

Notes:
- Scrollback is currently appended only on full-screen scroll (scroll region must be full height).
- Scrollback view supports wheel + drag via the terminal widget; no selection/copy yet.

Decision:
- Current grid is a minimal stepping stone; will be replaced by a proper model with dirty‑row tracking and scrollback.

Why:
- Necessary for performance and correctness with real TUI apps.

Research notes:
- Alacritty stores rows in a ring buffer with a movable zero index to make rotations O(1).
- xterm keeps a fixed-size FIFO of saved lines and overwrites oldest entries as the buffer fills.
- libtsm uses a power-of-two ring buffer and wraps with a start/used cursor.

### Layer 5: Renderer Core

Progress:
- Terminal rendering uses dedicated font cache and box‑drawing fast path.

Decision:
- TBD for glyph atlas + cache LRU specifics.

Why:
- TBD (will be updated after reference review).

### Layer 6: Font + Shaping

Progress:
- FreeType + HarfBuzz used for single‑codepoint glyph rendering.

Decision:
- TBD for full grapheme shaping and fallback chain.

Why:
- TBD.

### Layer 7: Input + UX

Progress:
- Key and character input forwarded to PTY.
- Basic mouse selection + clipboard copy added for the terminal widget.
- Clipboard paste supports Ctrl+Shift+V and middle-click.
- Bracketed paste mode (?2004) is honored when enabled by the shell.

Decision:
- Implement a simple linear (non-rect) selection stored as global scrollback row/col coordinates.
- Draw selection highlight as a translucent overlay each frame, independent of the cached terminal texture.
- Copy selection with Ctrl+Shift+C, trimming trailing spaces per line and joining with newlines.

Why:
- Matches minimal terminal expectations while avoiding deep model changes.
- Overlay rendering keeps selection updates cheap and does not invalidate cached rows.
- Simple per-line trimming approximates common terminal clipboard behavior.

Notes:
- Selection is cleared on terminal resize and when new PTY output arrives to avoid stale indices.

Research notes:
- Ghostty tracks selections with pins into the screen/page list for durability across mutations.
- foot keeps selection coordinates in absolute (scrollback) row space and extracts selection text via an extraction pipeline.
- rio (Alacritty-derived) models multiple selection types (simple/block/semantic/lines) with anchors and side tracking.

### Layer 8: Correctness + Compatibility

Progress:
- Not implemented beyond basic CSI/SGR.

Decision:
- TBD.

Why:
- TBD.

### Layer 9: Performance + Polish

Progress:
- Snapshot + flat grid in place; still full redraw each frame.
- Added per-row dirty tracking in the grid with bounding damage ranges.
- Terminal rendering now caches the grid into a render texture and only re-renders dirty rows.
- Terminal glyph atlas now reuses a staging buffer and supports compaction when full.
- Added lightweight frame/draw/input-latency metrics to track pacing.
- Refined ED (erase display) damage to track the cursor row column range separately from full-row damage below/above.

Decision:
- Cache terminal grid in a render texture and update only dirty rows; draw cursor as an overlay on the main frame.
- Use atlas compaction to keep the glyph cache effective without per-glyph allocations.
- Track frame/draw/input latency with EMA metrics for future tuning.
- Track per-row column bounds; multi-row ops issue separate dirty ranges so partial rows don’t force full-row redraw.

Why:
- Render texture keeps frame cost stable while preserving per-row invalidation for partial updates.
- Reusing a staging buffer reduces per-glyph churn; compaction avoids hard failures when atlas fills.
- Metrics make pacing regressions visible without heavy profiling.
- Column bounds reduce overdraw for row-local edits while keeping row-level dirtiness simple.

Research notes:
- Alacritty tracks per-line damage bounds per frame and merges them into renderer rectangles.
- Ghostty marks per-row dirty flags, promoting to full redraw when global state changes.
- libvterm damage tests emphasize scroll/move damage vs. cell damage merging.

### Layer 10: Tests + Fixtures

Progress:
- Not implemented.

Decision:
- TBD.

Why:
- TBD.

## Immediate next steps

1) Add dirty‑row tracking to the grid + renderer.
2) Add scrollback viewport polish (selection, copy, and mouse wheel modes).
