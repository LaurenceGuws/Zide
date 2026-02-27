# Terminal Compatibility

Zide currently exposes a conservative xterm-compatible terminal surface with a
small set of explicitly supported modern extensions.

This document is the public support contract. If behavior is not listed here,
do not assume it is supported just because a reference terminal implements it.

## Identity

- Recommended `TERM`: `zide`
- Fallback `TERM`: `xterm-256color`
- Terminfo source: `terminfo/zide.terminfo`

Install the bundled terminfo entry with:

```sh
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

After installation, new shells launched inside Zide will prefer `TERM=zide`.
If the entry is not installed, Zide falls back to `xterm-kitty` when available,
otherwise `xterm-256color`.

## Supported Baseline

- Core cursor movement and positioning
- Erase, insert/delete char and line
- Scroll regions and indexed scrolling
- SGR:
  - normal/bold/dim/italic/blink/reverse/invisible
  - 16-color, 256-color, truecolor
  - underline color
- Alternate screen
- Bracketed paste (`CSI ? 2004 h/l`)
- Focus reporting (`CSI ? 1004 h/l`)
- Sync updates (`CSI ? 2026 h/l`)
- Mouse:
  - X10
  - normal/button-motion/any-motion (`1000/1002/1003`)
  - SGR mouse (`1006`)
- OSC:
  - title (`0/2`)
  - cwd (`7`)
  - hyperlinks (`8`)
  - dynamic colors (`10/11/12/19`, bounded query support)
  - clipboard (`52`)
  - kitty clipboard (`5522`, bounded scope)
- DSR / DA / DECRQM / DECRPM:
  - representative xterm-family query/reply behavior for the implemented mode set
- DCS:
  - XTGETTCAP (`DCS + q`, bounded termcap scope)
  - legacy sync-update alias (`DCS = 1/2 s`)
  - bounded `DECRQSS`:
    - cursor style (`DECSCUSR`)
    - bounded SGR state
    - `DECSTBM`
    - `DECSLRM`
- Keyboard input:
  - VT/xterm key encoding baseline
  - kitty keyboard / CSI-u progressive enhancement
  - bounded alternate-key metadata support
- Kitty graphics:
  - store/place/delete/query subset
  - multipart uploads
  - virtual placements (`U=1`) / Unicode-placeholder rendering
  - bounded parent/child placement support

## Explicitly Bounded Or Partial

- Kitty graphics is not full kitty parity.
  - animation/composition paths are deferred
  - some delete selectors remain intentionally deferred
- `DECRQSS` is bounded, not a full xterm state-query implementation
- Xterm window ops are bounded to:
  - `CSI 14 t`
  - `CSI 16 t`
  - `CSI 18 t`
  - `CSI 19 t`
- `DECSLRM` support is aimed at real TUI behavior, not full rectangular editing breadth
- Layout-aware kitty alternate-key reporting is improved but still not full cross-layout parity

## Strategic Non-Support / Deferred

- Alternate mouse encodings `1005` and `1015`
- Printer/media/status families
- Legacy tab-stop report/edit variants (`CSI Ps W`)
- Sixel / DRCS graphics
- Generic APC payloads outside the kitty graphics family

## Notes For App Authors

- Prefer xterm-compatible control sequences with modern opt-in extensions.
- For image rendering, kitty graphics is the supported path; sixel is not.
- For keyboard richness, kitty keyboard / CSI-u should be treated as progressive enhancement, not the only usable input path.

## Validation Sources

- Replay fixtures under `fixtures/terminal/`
- Protocol tracker: `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`
- Terminal API notes: `app_architecture/terminal/TERMINAL_API.md`
