# Terminal Design & Decision Log

Date: 2026-01-19

Purpose: this document tracks terminal architecture decisions and implementation progress. It is not a fixed plan. Each layer will be researched in the reference repos before implementation, and this file will be updated with concrete decisions as they are made.

## Status Summary

- Terminal backend stub replaced by a working PTY + minimal VT pipeline.
- Shell output renders with basic cursor movement, erase ops, and SGR (16/256/truecolor).
- Scrollback ring buffer captures full‑screen scrolls and is exposed via a scrollbar + offset, plus a scrollback indicator.
- Alternate screen uses per-screen state (grid, cursor, scroll region, key mode stack, attrs); alt disables scrollback/selection and fully dirties on switch.
- OSC parsing handles title (OSC 0/2), hyperlinks (OSC 8), clipboard write (OSC 52), and default fg/bg set + query (OSC 10/11). Queries for OSC 12/19 are answered.
- Keyboard input supports CSI u/kitty protocol flags with per-screen stacks and modifier-aware encoding.
- Legacy modifier combos now include full letter/number/punctuation mapping; macOS Command is reserved for app shortcuts.
- Dirty-row tracking and render-texture caching are live; full VT coverage still missing.
- CSI params support up to 16 entries and `:` separators for SGR sequences.
- Default colors are configurable per session; erase/blank fills use current attributes so TUI background colors persist.

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
- PTY read thread now queues bytes; the main thread drains with a per-frame budget to avoid render starvation.
- Drain budget scales up when backlog is large to keep cat/scrollback responsive.

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
- Erase: `J`, `K`, `X`
- Insert/delete: `@`, `P`, `L`, `M`
- Scroll region: `r`, `S`, `T`
- Reset: `ESC c`
- DSR/DA replies: `CSI n` (5/6) + `CSI c`
- SGR: 16‑color + 256‑color + truecolor, bold/reverse; colon-separated SGR supported; params up to 16
- OSC: `0/2` title, `7` cwd (parsed, not yet consumed), `8` hyperlinks, `52` clipboard write, `10/11` default fg/bg set + query, `12/19` query replies

### Layer 4: Screen Model (Grid + Scrollback)

Progress:
- Flat grid exists with basic scrolling and line erase.
- Scroll region support added.
- Scrollback ring buffer stores rows on full‑screen scroll; cleared on column resize.
- Terminal UI can render scrollback with a right-side scrollbar and scroll offset.

Notes:
- Scrollback is currently appended only on full-screen scroll (scroll region must be full height).
- Scrollback view supports wheel + drag via the terminal widget; no selection/copy yet.

Planned redesign:
- Replace the current row-only scrollback with a logical-line buffer that tracks wrap boundaries.
- Reflow on column resize by merging wrapped rows into logical lines, then re-wrapping into the new width.
- Preserve anchors: bottom when scrollback offset is 0, otherwise preserve top logical line and cursor/selection mapping.

Scrollback redesign proposal (kitty/ghostty/wezterm inspired):
- Data model: store scrollback as logical lines, not raw rows.
  - Each logical line owns a list of cells plus a wrap flag indicating whether it continues.
  - Maintain stable line ids (monotonic) so selections/anchors can persist across reflow.
  - Keep a viewport pin (active/bottom vs pinned line) similar to ghostty's PageList pins.
- Mapping strategy:
  - For reflow, rebuild rows from logical lines using the new column width.
  - Recompute viewport start by preserving the top logical line when scrolled, or bottom when at offset=0.
  - Remap cursor to its logical position within a line; clamp if it falls outside.
  - Remap selection by logical line id + column offset; clear only if line dropped.
- Lifecycle on resize:
  - Pre-prune trailing blank lines (wezterm) to avoid scrollback growth on repeated resize.
  - Reflow only when columns change; row-only changes skip reflow and adjust viewport.
  - Ensure active area is always fully populated (pad blank rows if necessary).
- Storage approach:
  - Ring buffer of logical lines (alacritty/xterm behavior), or paged list with pins (ghostty).
  - Keep wrap metadata with the logical line, not in the grid.
  - Track total rows for scrollbar + scroll offset calculations.
- Compatibility rules:
  - Alternate screen: no scrollback; resize uses truncation without reflow.
  - Scroll regions: only full-screen scroll pushes into scrollback; regions remain in-grid.

Why this approach:
- Mirrors the reflow model in wezterm (rewrap_lines) and alacritty (resize reflow) while keeping kitty-style line semantics.
- Stable logical line ids make scrollback anchors, cursor, and selection durable across reflow.

Decision:
- Grid model supports dirty‑row tracking and scrollback; treat it as the current baseline rather than a throwaway prototype.

Why:
- Necessary for performance and correctness with real TUI apps.

Why the redesign:
- Current scrollback breaks on resize because it has no line wrap metadata.
- Reference terminals (kitty/wezterm/alacritty/ghostty) model logical lines and reflow across width changes.

Research notes:
- Alacritty stores rows in a ring buffer with a movable zero index to make rotations O(1).
- xterm keeps a fixed-size FIFO of saved lines and overwrites oldest entries as the buffer fills.
- libtsm uses a power-of-two ring buffer and wraps with a start/used cursor.
- wezterm rewraps by merging wrapped lines into logical lines, then splitting into new rows while remapping cursor.
- alacritty reflows on column change and uses wrap flags to stitch lines together.

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
- Render symbol glyphs using their bearing (no custom centering), clamped so they never start left of the cell origin.
- Render backgrounds in a separate pass so glyphs can overflow into adjacent cells without being overdrawn.

Why:
- Integer cell metrics prevent box drawing striping/gaps and keep glyph baselines consistent across DPI/scales.
- Integer math avoids cumulative float rounding error in long rows.
- Overflow-only-when-space matches common terminal behavior while avoiding constant clipping.
- The 0.7 threshold matches wezterm’s heuristic for identifying square-ish glyphs.
- Always-overflow PUA/symbols avoids shrinking icon glyphs; aligns with wezterm when configured to allow overflow and with alacritty’s non-scaling render path.
- Left clamp prevents negative bearings from pushing icons off the viewport edge while still honoring font bearings.
- Separating background and glyph passes avoids clipping overflowed icons inside the grid.

Research notes:
- kitty rounds ascent/baseline and cell metrics to integer pixels and computes cell height with ceil/floor to avoid subpixel jitter.
- wezterm stores cell pixel sizes as integers in its glyph cache metrics and uses pixel dimensions for rendering decisions.

### Layer 6: Font + Shaping

Progress:
- FreeType + HarfBuzz used for single‑codepoint glyph rendering.
- Linux fontconfig fallback resolves missing glyphs via system font discovery (cached per codepoint + face).
- Embedded fallback fonts are optional; current default relies on system fallback with the primary mono font.

Decision:
- Linux: use fontconfig to resolve missing glyphs across installed fonts; cache resolved faces for reuse.
- macOS/Windows: TODO for CoreText/DirectWrite fallback to match Linux behavior.
- Keep embedded fallback fonts optional to avoid bundling large font sets by default.

Why:
- System font discovery is the common approach in kitty/wezterm/alacritty; it provides broad glyph coverage without large bundles.

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
- OSC 8 hyperlinks are parsed and rendered with link color + underline.
- Fixed autowrap with wrap-next semantics to avoid duplicate lines in full-screen apps (btop/lazygit).
- Application cursor keys (DECCKM via `CSI ?1 h/l`) implemented.
- DSR/DA replies added for cursor position queries (Codex compatibility).
- Default color queries (OSC 10/11) are answered; sets are applied to session defaults.
- Synchronized updates (DECSET ?2026) now freeze terminal rendering until reset.

Decision:
- Track an alternate grid and per-screen cursor/scroll region state; swap on DECSET/DECRST.
- Treat alt screen as no-scrollback and clear on ?1047/?1049 per xterm/VTE behavior.
- Keep save/restore cursor per screen, including attributes.
- Decode OSC 52 payloads (base64) with size caps and defer clipboard integration to the UI layer.
- Track OSC 8 hyperlink state and map it to underline + link color during render.

Why:
- Matches common terminal behavior without forcing a full screen model rewrite.
- Keeps scrollback semantics clean and prevents history pollution while in alt screen.
- Aligns cursor save/restore with recorded reference behavior (ESC 7/8 + ?1049 flows).
- Avoids emitting OSC 52 text while keeping clipboard ownership in the UI.
- Allows hyperlink rendering without blocking VT progress.

Research notes:
- Alacritty saved-cursor fixtures exercise ESC 7/8 and ?1049 enter/exit behavior.
- VTE scrolling-region notes show cursor movement/scrolling within margins.

Known gaps (as of 2026-01-28):
- Kitty graphics protocol is still partial (see IMG-01 in `app_architecture/terminal/protocol_todo.yaml`).
- Terminfo feature parity sweep is pending (TERM-01).
- Tests + fixtures are not implemented yet (see Layer 10).
- Cross-platform font fallback (macOS/Windows) is still TODO.

### Layer 9: Performance + Polish

Progress:
- Snapshot + flat grid in place with dirty rows and render-texture caching (no full redraw per frame in steady state).
- Added per-row dirty tracking in the grid with bounding damage ranges.
- Terminal rendering now caches the grid into a render texture and only re-renders dirty rows.
- Terminal grid updates now batch background and glyph draws to reduce per-cell GL calls.
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

Planned improvements (2026-01-28):
- Batch terminal draw calls into large vertex buffers (glyphs + backgrounds) to avoid per-cell GL draws.
- Honor dirty column bounds in partial redraws and avoid redrawing neighbor rows unless overflow requires it.
- Reduce render-thread lock contention by double-buffering snapshots or shortening parser lock holds.
- Avoid full re-render on hover/link changes; draw link/hover underline as a lightweight overlay pass.
- Skip rebuilding view_cells when nothing changed (dirty == none and scroll unchanged).

### Layer 10: Tests + Fixtures

Progress:
- Not implemented.

Decision:
- TBD.

Why:
- TBD.

## Immediate next steps

1) Implement the terminal replay harness + goldens (Layer 10; see `app_architecture/terminal/REPLAY_HARNESS_SPEC.md`).
2) Finish kitty graphics protocol completeness (IMG-01 plan).
3) Improve font fallback and rasterization quality (multi-font chain + LCD/grayscale).

## Related docs

- Alt screen redesign proposal: `app_architecture/terminal/ALT_SCREEN_REDESIGN.md`.
