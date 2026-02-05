# Terminal Feature Inventory (Code-Derived)

Date: 2026-02-05

Source of truth: protocol and input handler switches in:
- `src/terminal/protocol/csi.zig`
- `src/terminal/protocol/osc.zig`
- `src/terminal/protocol/dcs_apc.zig`
- `src/terminal/input/input.zig`

This is a snapshot of currently implemented behavior, not a spec or compliance claim.

## CSI (Control Sequence Introducer)

Cursor + positioning:
- `CSI A` (CUU), `CSI B` (CUD), `CSI C` (CUF), `CSI D` (CUB)
- `CSI E` (CNL), `CSI F` (CPL)
- `CSI G` (CHA), `CSI H`/`CSI f` (CUP)
- `CSI d` (VPA)

Erase + insert/delete:
- `CSI J` (ED), `CSI K` (EL)
- `CSI @` (ICH), `CSI P` (DCH), `CSI X` (ECH)
- `CSI L` (IL), `CSI M` (DL)

Scroll + region:
- `CSI S` (SU), `CSI T` (SD)
- `CSI r` (DECSTBM)

Tabs:
- `CSI g` (TBC 0/3)

Cursor save/restore + key protocol:
- `CSI s` (SCP)
- `CSI u` (RCP)
- `CSI > u` (key mode push)
- `CSI < u` (key mode pop)
- `CSI = u` (key mode modify)
- `CSI ? u` (key mode query)

Status queries:
- `CSI n` (DSR), including DEC variants when `?` leader present
- `CSI c` (DA)

Modes (SM/RM):
- `CSI 20 h/l` (LNM)
- `CSI ? 1 h/l` (DECCKM app-cursor keys)
- `CSI ? 3 h/l` (DECCOLM 80/132 column mode)
- `CSI ? 5 h/l` (DECSCNM reverse video)
- `CSI ? 6 h/l` (DECOM origin mode)
- `CSI ? 7 h/l` (DECAWM autowrap)
- `CSI ? 25 h/l` (DECTCEM cursor visible)
- `CSI ? 47 h/l` (alt screen)
- `CSI ? 1047 h/l` (alt screen)
- `CSI ? 1048 h/l` (save/restore cursor)
- `CSI ? 1049 h/l` (alt screen + cursor save)
- `CSI ? 2004 h/l` (bracketed paste)
- `CSI ? 2026 h/l` (sync updates)
- `CSI ? 1000 h/l` (mouse X10)
- `CSI ? 1002 h/l` (mouse button tracking)
- `CSI ? 1003 h/l` (mouse any tracking)
- `CSI ? 1006 h/l` (mouse SGR)

Cursor style:
- `CSI q` (DECSCUSR)

SGR (Select Graphic Rendition):
- reset: `0`
- bold: `1`, normal intensity: `22`
- blink slow/fast: `5`, `6`, blink off: `25`
- underline on/off: `4`, `24`
- reverse on/off: `7`, `27`
- default fg/bg: `39`, `49`
- underline color reset: `58`, `59`
- basic colors: `30-37`, `40-47`
- bright colors: `90-97`, `100-107`
- palette index: `38;5;idx`, `48;5;idx`, `58;5;idx`
- truecolor: `38;2;r;g;b`, `48;2;r;g;b`, `58;2;r;g;b`
- RGBA (WezTerm extension): `38;6;r;g;b;a`, `48;6;r;g;b;a`, `58;6;r;g;b;a`

## OSC (Operating System Command)

- `OSC 0/2` set title
- `OSC 4` palette set/query (multiple pairs)
- `OSC 104` palette reset (all or per-index)
- `OSC 10-19` dynamic colors set/query
- `OSC 110-119` dynamic color reset
- `OSC 7` CWD (file:// URI parsing + host validation)
- `OSC 8` hyperlinks
- `OSC 52` clipboard write + query
- `OSC 133` semantic prompt markers
- `OSC 1337` SetUserVar (base64)

## DCS/APC

`DCS +q` XTGETTCAP:
- TN, Co/colors, RGB

`APC` kitty graphics:
- `APC G` payload routed to kitty graphics parser

## Input Encoding + Reporting

Key input:
- Legacy sequences for arrows, home/end, page up/down, ins/del, tab, enter, backspace, escape
- Application keypad SS3 sequences for keypad keys when enabled
- Kitty key encoding for core functional keys with press/repeat/release (key mode flags)
- CSI u text encoding when report_text/embed_text flags are set

Mouse reporting:
- X10 and SGR mouse reporting
- Button, motion, and wheel events

## Kitty Parity Notes (Code-Based)

- Graphics: supports Kitty graphics payloads via `APC G` routed to the in-process parser; placements and images tracked in core snapshot state.
- Keyboard: supports Kitty keyboard protocol subset for core functional keys + CSI u text reporting; no broader key coverage beyond the mapped keys in `src/terminal/input/input.zig`.
- OSC 1337: only `SetUserVar` is handled; other OSC 1337 subcommands are ignored.
- DCS: only `DCS +q` XTGETTCAP is handled; other DCS sequences are ignored.
- VT feature set is limited to the CSI/OSC lists above; unlisted sequences are not handled.
