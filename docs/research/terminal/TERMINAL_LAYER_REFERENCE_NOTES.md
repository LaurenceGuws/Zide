# Terminal Layer Reference Notes

This file collects reference-repo notes that previously lived inline in
`app_architecture/terminal/DESIGN.md`.

Use it for:

- reference-terminal implementation notes by layer
- supporting evidence for terminal architecture choices
- source snapshots that help explain why Zide chose a given direction

Use `app_architecture/terminal/DESIGN.md` for the current high-level terminal
architecture baseline and decision summary by layer.

## Layer 2: PTY + IO

- Alacritty (Unix) uses `openpty`, sets IUTF8 on the master, spawns with
  `setsid` + `TIOCSCTTY`, and polls for PTY + child exit.
- Alacritty (Windows) uses ConPTY + `CreateProcessW` with pseudoconsole
  attributes.
- foot uses `posix_openpt` + `grantpt` + `unlockpt`, and validates shells.
- wezterm (Unix) splits read/write handles and uses wake pipes.
- libtsm emphasizes edge-triggered polling and read-until-EAGAIN.

## Layer 4: Screen Model (Grid + Scrollback)

- Alacritty stores rows in a ring buffer with a movable zero index to make
  rotations O(1).
- xterm keeps a fixed-size FIFO of saved lines and overwrites oldest entries as
  the buffer fills.
- libtsm uses a power-of-two ring buffer and wraps with a start/used cursor.
- wezterm rewraps by merging wrapped lines into logical lines, then splitting
  into new rows while remapping cursor.
- alacritty reflows on column change and uses wrap flags to stitch lines
  together.

## Layer 5: Renderer Core

- kitty rounds ascent/baseline and cell metrics to integer pixels and computes
  cell height with ceil/floor to avoid subpixel jitter.
- wezterm stores cell pixel sizes as integers in its glyph cache metrics and
  uses pixel dimensions for rendering decisions.

## Layer 7: Input + UX

- Ghostty tracks selections with pins into the screen/page list for durability
  across mutations.
- foot keeps selection coordinates in absolute (scrollback) row space and
  extracts selection text via an extraction pipeline.
- rio (Alacritty-derived) models multiple selection types
  (simple/block/semantic/lines) with anchors and side tracking.

## Layer 8: Correctness + Compatibility

- Alacritty saved-cursor fixtures exercise `ESC 7/8` and `?1049` enter/exit
  behavior.
- VTE scrolling-region notes show cursor movement/scrolling within margins.

## Layer 9: Performance + Polish

- Alacritty tracks per-line damage bounds per frame and merges them into
  renderer rectangles.
- Ghostty marks per-row dirty flags, promoting to full redraw when global state
  changes.
- libvterm damage tests emphasize scroll/move damage vs. cell damage merging.
