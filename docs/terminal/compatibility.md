# Terminal Beta Compatibility

Zide currently exposes a conservative xterm-compatible terminal surface with a
small set of explicitly supported modern extensions.

This document defines the current beta support surface for Zide's terminal. If
behavior is not listed here, do not assume it is supported just because a
reference terminal implements it.

## Identity

- Recommended `TERM`: `xterm-zide`
- Fallback `TERM`: `xterm-256color`
- Terminfo source: `terminfo/zide.terminfo`
- Runtime selection order inside Zide:
  - `xterm-zide` when available
  - `zide-256color` when available
  - `zide` when available
  - `xterm-256color` as the final fallback

Install the bundled terminfo entry with:

```sh
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

After installation, new shells launched inside Zide should prefer `TERM=xterm-zide`.
If the entry is not installed, Zide falls back to `xterm-256color`.
For packaged installs that place entries under `/usr/share/terminfo`, `TERMINFO` is typically unset by design.

The initial `zide` terminfo entry intentionally keeps `xterm-256color` as its
base and adds only audited extensions:

- `Tc` for truecolor
- `Su` and `Smulx` for styled underlines
- `Setulc` for underline color (`SGR 58`)
- `XF` for focus reporting
- `fullkbd` for kitty keyboard / CSI-u full keyboard mode
- `Sync` for synchronized-update capability advertising (`CSI ? 2026 h/l`)
- `Ms` for OSC 52 clipboard transport

This set is intentionally frozen for the current beta release.

Reasoning against peer terminals:

- kitty, ghostty, foot, and modern alacritty entries advertise a broader set of
  nonstandard capabilities
- the most visibly meaningful ones for modern TUIs are already covered here:
  truecolor, styled underlines, underline color, clipboard transport, focus,
  sync updates, and richer keyboard reporting
- adding more caps just for breadth is lower-value than keeping the advertised
  set exact and defensible
- Zide should look conservative-but-serious, not parity-aspirational

So the current terminfo strategy is:

- advertise capabilities that make Zide feel modern next to kitty/ghostty/foot
- do not advertise every peer extension unless there is direct authority and a
  real app-interop reason

## Capability Discovery

- `TERM`:
  - primary identity is `xterm-zide`
  - `zide-256color` is also provided by the same terminfo entry
  - runtime fallback order is `xterm-256color` after Zide-specific identities
- Primary DA:
  - Zide answers as an xterm-family VT identity for broad compatibility
- XTGETTCAP (`DCS + q`):
  - bounded support includes `TN=zide`, `Co=256`, and `RGB=8`
  - replay authority: `fixtures/terminal/terminal_identity_query_reply.vt`
- Sync updates:
  - canonical mode is `CSI ? 2026 h/l`
  - legacy `DCS = 1/2 s` remains a compatibility alias, but is not the primary advertised form

## Positioning

Zide should be understood as:

- more modern than a plain `xterm-256color` baseline
- intentionally compatible with xterm-family TUIs first
- selectively competitive with kitty/ghostty/foot on high-value modern features

Zide should not be described as:

- full kitty parity
- full xterm extension parity
- full ghostty/foot parity

The intended claim is narrower and more defensible:

- strong xterm-family compatibility
- a curated set of modern extensions that matter in real TUIs
- explicit documentation of bounded and deferred areas

## Capability Matrix

This is a rough product-positioning table, not a claim of exhaustive parity.

| Capability family | Zide beta | xterm | kitty | ghostty | foot |
| --- | --- | --- | --- | --- | --- |
| Core VT / xterm TUI baseline | strong | reference | strong | strong | strong |
| Truecolor + modern SGR | strong | partial/varies by extension | strong | strong | strong |
| Underline style + underline color | strong | partial | strong | strong | strong |
| Focus / bracketed paste / sync updates | strong | mixed by feature | strong | strong | strong |
| Clipboard transport (`OSC 52`) | strong | baseline | strong | strong | strong |
| Keyboard richness (`CSI-u` / kitty keyboard) | bounded | low | reference | strong | medium |
| State queries (`DECRQSS` / `XTGETTCAP`) | bounded | broad | broad | broad | medium |
| Window ops / legacy control breadth | bounded | reference | bounded | bounded | bounded |
| Image protocol | bounded kitty subset | none | reference | strong kitty subset | none |
| Sixel / DRCS | deferred | mixed/legacy | none | none | none |

Interpretation:

- `strong`: good practical coverage for modern TUI use
- `bounded`: implemented and useful, but intentionally not full breadth/parity
- `reference`: peer is the compatibility source for that family

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

## Installing And Verifying

Install the bundled terminfo entry:

```sh
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

Verify the entry is visible:

```sh
infocmp zide-256color
```

Then launch a new shell inside Zide and confirm:

```sh
printf '%s\n' "$TERM"
```

Expected value is `xterm-zide` (or `zide-256color` in compatibility scenarios).
If the terminfo entry is not installed yet, expect `xterm-256color`.

## Validation Sources

- Replay fixtures under `fixtures/terminal/`
- Protocol tracker: `app_architecture/terminal/PROTOCOL_ACCURACY_PROGRESS.md`
- Terminal API notes: `app_architecture/terminal/TERMINAL_API.md`
- PTY TERM smoke: `src/terminal/io/pty_unix.zig`
