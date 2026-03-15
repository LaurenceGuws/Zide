# Terminal Beta Compatibility

This doc defines the current beta support surface for Zide's terminal. If a
behavior is not listed here, do not assume it is supported just because another
terminal implements it.

## Positioning

Zide should currently be understood as:

- strong on the xterm-family baseline needed by real TUIs
- intentionally modern in a bounded set of high-value extensions
- still a beta terminal, not a full `kitty` / `ghostty` parity claim

## Identity

Current runtime TERM selection order in the Unix PTY path is:

- `xterm-kitty`
- `xterm-zide`
- `zide-256color`
- `zide`
- `xterm-256color`

Practical interpretation:

- If `xterm-kitty` terminfo is already installed on the system, Zide currently
  prefers that identity for broad app compatibility.
- If not, Zide prefers its own `xterm-zide` entry.
- `zide-256color` and `zide` remain Zide-owned fallbacks.
- `xterm-256color` is the final fallback when no richer entry is available.

Short version:

- Zide prefers the broadest already-installed compatible terminfo first.
- If that is not available, it falls back to Zide-owned entries.
- This is a compatibility choice, not a product-identity claim.

Bundled terminfo source:

- `terminfo/zide.terminfo`

Install the bundled entry with:

```sh
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

After installation, a fresh shell inside Zide should be able to use
`xterm-zide` on systems where `xterm-kitty` is not already installed.

For packaged installs that place terminfo under `/usr/share/terminfo`,
`TERMINFO` is typically unset by design.

## What Zide-Owned Terminfo Advertises

The Zide-owned entry intentionally stays conservative and audited. It is based
on `xterm-256color` plus a bounded set of extensions:

- `Tc` for truecolor
- `Su` and `Smulx` for styled underlines
- `Setulc` for underline color
- `XF` for focus reporting
- `fullkbd` for kitty keyboard / CSI-u full keyboard mode
- `Sync` for synchronized-update capability advertising
- `Ms` for OSC 52 clipboard transport

That set is intentionally smaller than what some peer terminals advertise. The
goal is to advertise what Zide can defend, not everything a more mature peer
terminal happens to ship.

## Supported Baseline

- core cursor movement and positioning
- erase, insert/delete char and line
- scroll regions and indexed scrolling
- SGR:
  - bold / dim / italic / blink / reverse / invisible
  - 16-color, 256-color, truecolor
  - underline style and underline color
- alternate screen
- bracketed paste (`CSI ? 2004 h/l`)
- focus reporting (`CSI ? 1004 h/l`)
- synchronized updates (`CSI ? 2026 h/l`)
- mouse:
  - X10
  - `1000` / `1002` / `1003`
  - SGR mouse (`1006`)
- OSC:
  - title (`0/2`)
  - cwd (`7`)
  - hyperlinks (`8`)
  - dynamic colors (`10/11/12/19`, bounded query support)
  - clipboard (`52`)
  - kitty clipboard (`5522`, bounded scope)
- representative xterm-family query/reply coverage for the implemented mode set
- bounded `XTGETTCAP` (`DCS + q`)
- bounded `DECRQSS`
- keyboard input:
  - VT/xterm baseline
  - kitty keyboard / CSI-u progressive enhancement
  - bounded alternate-key metadata
- kitty graphics:
  - store/place/delete/query subset
  - multipart uploads
  - virtual placements / Unicode placeholder rendering
  - bounded parent/child placement support

## Explicitly Bounded

- kitty graphics is not full kitty parity
- `DECRQSS` is bounded, not full xterm breadth
- xterm window ops are bounded to:
  - `CSI 14 t`
  - `CSI 16 t`
  - `CSI 18 t`
  - `CSI 19 t`
- keyboard richness is materially better than plain xterm, but not full
  cross-layout parity
- `DECSLRM` is implemented for real TUI behavior, not as a claim of full
  rectangular-editing breadth

## Deferred / Non-Supported

- alternate mouse encodings `1005` and `1015`
- printer/media/status families
- generic APC payloads outside the kitty graphics family
- sixel / DRCS graphics
- legacy tab-stop report/edit variants (`CSI Ps W`)

## Capability Discovery Notes

- Primary DA answers as an xterm-family VT identity for broad compatibility.
- `XTGETTCAP` currently has bounded support including `TN=zide`, `Co=256`, and
  `RGB=8`.
- Canonical sync-update mode is `CSI ? 2026 h/l`.
- Legacy `DCS = 1/2 s` remains a compatibility alias, but is not the preferred
  advertised form.

## Installing And Verifying

Install the bundled terminfo entry:

```sh
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

Verify the entry is present:

```sh
infocmp zide-256color
```

Then start a fresh shell inside Zide and check:

```sh
printf '%s\n' "$TERM"
```

Expected value is compatibility-driven:

- `xterm-kitty` when that terminfo is already available
- otherwise `xterm-zide`
- then `zide-256color`
- finally `xterm-256color`

Practical reading:

- seeing `xterm-kitty` in Zide is not a failure by itself
- it means the runtime picked the strongest already-installed compatible entry
- if you want the Zide-owned identity to win, install the bundled terminfo and
  use an environment where `xterm-kitty` is not already taking precedence

## Validation Sources

- replay fixtures under `fixtures/terminal/`
- TERM selection logic in `src/terminal/io/pty_unix.zig`
- protocol tracker:
  `app_architecture/terminal/protocol/ACCURACY_PROGRESS.md`
- detailed protocol review/evidence:
  `docs/review/TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md`
- terminal API notes:
  `app_architecture/terminal/TERMINAL_API.md`
