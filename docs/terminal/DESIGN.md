# Terminal Design & Decision Log

Date: 2026-01-17

Purpose: this document tracks terminal architecture decisions and implementation progress. It is not a fixed plan. Each layer will be researched in the reference repos before implementation, and this file will be updated with concrete decisions as they are made.

## Status Summary

- Terminal backend stub replaced by a working PTY + minimal VT pipeline.
- Shell output renders with basic cursor movement, erase ops, and SGR (16/256/truecolor).
- Scrollback ring buffer captures full‑screen scrolls and is exposed via a scrollbar + offset, plus a scrollback indicator.
- Alternate screen switching and cursor save/restore are supported; alt screen disables scrollback.
- OSC parsing now handles clipboard (OSC 52) and hyperlinks (OSC 8) as internal state.
- Keyboard input supports CSI u/kitty protocol flags with per-screen stacks and modifier-aware encoding.
- Legacy modifier combos now include full letter/number/punctuation mapping; macOS Command is reserved for app shortcuts.
- Dirty-row tracking and render-texture caching are live; full VT coverage still missing.

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
- OSC: basic parsing for `OSC 0/2` title updates (consumed, no UI binding yet)

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
- R1: snapped terminal cell metrics and draw positions to integer pixels.
- R2: terminal glyph atlas uses point filtering to avoid blur.
- R3: square/wide glyph overflow policy (scale-to-fit vs allow overflow when followed by space).

Decision:
- Keep terminal cell width/height as integer pixel metrics and snap cell origins and glyph draws to integer pixels.
- Maintain integer math for per-cell positioning (base + col/row * cell size) to avoid float drift.
- Use point filtering for terminal glyph atlases to preserve pixel edges.
- For square/wide glyphs, allow width overflow only when followed by space (default), otherwise scale to fit the cell.
- Use a wezterm-style aspect heuristic: treat glyphs with width >= 0.7 * cell height as square/wide.
- Always allow PUA/symbol glyphs to overflow (no scaling) to match common terminal behavior for icons.
- Clamp symbol glyphs to never render left of the cell origin to avoid left-edge clipping.

Why:
- Integer cell metrics prevent box drawing striping/gaps and keep glyph baselines consistent across DPI/scales.
- Integer math avoids cumulative float rounding error in long rows.
- Overflow-only-when-space matches common terminal behavior while avoiding constant clipping.
- The 0.7 threshold matches wezterm’s heuristic for identifying square-ish glyphs.
- Always-overflow PUA/symbols avoids shrinking icon glyphs; aligns with wezterm when configured to allow overflow and with alacritty’s non-scaling render path.
- Left clamp prevents negative bearings/centering from pushing icons off the viewport edge.

Research notes:
- kitty rounds ascent/baseline and cell metrics to integer pixels and computes cell height with ceil/floor to avoid subpixel jitter.
- wezterm stores cell pixel sizes as integers in its glyph cache metrics and uses pixel dimensions for rendering decisions.

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
- Selection auto-scrolls when dragging beyond the viewport; scrollback indicator shows when scrolled.
- CSI u/kitty keyboard protocol support added (push/pop/query flags + modifier-aware encoding).
- Mouse reporting (X10/VT200/SGR) enabled via CSI ?1000/?1002/?1003 and ?1006.
- OSC 8 hyperlinks now mark cells with link attributes and render with a link color + underline.

Decision:
- Implement a simple linear (non-rect) selection stored as global scrollback row/col coordinates.
- Draw selection highlight as a translucent overlay each frame, independent of the cached terminal texture.
- Copy selection with Ctrl+Shift+C, trimming trailing spaces per line and joining with newlines.
- Maintain per-screen keyboard protocol flag stacks and emit CSI u sequences when enabled.

Why:
- Matches minimal terminal expectations while avoiding deep model changes.
- Overlay rendering keeps selection updates cheap and does not invalidate cached rows.
- Simple per-line trimming approximates common terminal clipboard behavior.
- Aligns with kitty/CSI-u progressive enhancement without breaking legacy input flows.

Notes:
- Selection is cleared on terminal resize and when input resumes the live view to avoid stale indices.

Research notes:
- Ghostty tracks selections with pins into the screen/page list for durability across mutations.
- foot keeps selection coordinates in absolute (scrollback) row space and extracts selection text via an extraction pipeline.
- rio (Alacritty-derived) models multiple selection types (simple/block/semantic/lines) with anchors and side tracking.

### Layer 8: Correctness + Compatibility

Progress:
- Added alternate screen support (DECSET ?47/?1047/?1049) with per-screen cursor state.
- Save/restore cursor via ESC 7/8 and CSI s/u, plus DECSET ?1048.
- Newline now scrolls within the active scroll region when the cursor hits its bottom edge.
- OSC 52 clipboard payloads decode into a pending clipboard buffer for the UI.
- OSC 8 hyperlinks are parsed and stored as active/inactive state (no rendering yet).

Decision:
- Track an alternate grid and per-screen cursor/scroll region state; swap on DECSET/DECRST.
- Treat alt screen as no-scrollback and clear on ?1047/?1049 per xterm/VTE behavior.
- Keep save/restore cursor per screen, including attributes.
- Decode OSC 52 payloads (base64) with size caps and defer clipboard integration to the UI layer.
- Track OSC 8 hyperlink state without rendering until cell attributes support links.

Why:
- Matches common terminal behavior without forcing a full screen model rewrite.
- Keeps scrollback semantics clean and prevents history pollution while in alt screen.
- Aligns cursor save/restore with recorded reference behavior (ESC 7/8 + ?1049 flows).
- Avoids emitting OSC 52 text while keeping clipboard ownership in the UI.
- Keeps hyperlink parsing in place for later rendering without blocking VT progress.

Research notes:
- Alacritty saved-cursor fixtures exercise ESC 7/8 and ?1049 enter/exit behavior.
- VTE scrolling-region notes show cursor movement/scrolling within margins.

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

1) Add overflow policy for square/wide glyphs (scale-to-fit vs allow overflow when followed by space).
2) Add Symbols Nerd Font Mono fallback for PUA glyphs.
3) Improve rasterization quality (LCD + grayscale fallback).
