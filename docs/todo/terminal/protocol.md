# Terminal Protocol TODO

## Scope

Close VT protocol gaps across OSC, CSI, DCS, and related compatibility surfaces for modern shells and TUIs.

## Priorities

- Dynamic colors and palette control with query/reset support.
- Keyboard and cursor mode parity.
- SGR completeness.
- Query/response parity.

## Status Snapshot

As of 2026-01-19, the core protocol backlog is mostly closed: CSI parameter handling expanded, DSR/DA replies exist, DECCKM and DECKPAM/DECKPNM are implemented, OSC 8/52/10/11 support exists, DECSCUSR is implemented, XTGETTCAP minimal replies exist, and kitty key encoding is in place for core functional keys. The main open protocol lanes are kitty graphics parity and a broader terminfo audit.

## TODO

- [x] `OSC-01` Implement OSC 4 palette set/query and OSC 104 reset.
- [x] `OSC-02` Implement OSC 10-19 dynamic colors with query/reset and 110-119 reset.
- [x] `OSC-03` Implement OSC 52 clipboard read support.
- [x] `OSC-04` Implement OSC 7 CWD parsing and validation.
- [x] `OSC-05` Implement OSC 133/1337 semantic prompt and user vars.
- [x] `CSI-01` Implement SGR 58 underline color and 59 reset.
- [x] `CSI-02` Implement SGR 38/48/58:6 RGBA support.
- [x] `CSI-03` Implement DECSCUSR cursor style handling.
- [x] `CSI-04` Implement application keypad mode (`DECKPAM`/`DECKPNM`).
- [x] `CSI-05` Complete the DSR coverage audit.
- [x] `DCS-01` Implement minimal XTGETTCAP (`DCS +q`) support.
- [-] `IMG-01` Implement kitty graphics protocol parity.
  Notes: parser, transmit/display/delete, anchoring, layering, storage limits, basic replies, parented placements, and direct/file/temp/shm media are in place. Remaining work is full parity and deferred action families, not first support.
- [-] `TERM-01` Complete the terminfo feature parity sweep.
  Notes: `docs/reference/terminal_compatibility.md`, `terminfo/zide.terminfo`, `xterm-zide` TERM selection, compiled-terminfo smoke, and replay-backed identity queries are in place. Further capability expansion still needs feature-by-feature audit.

