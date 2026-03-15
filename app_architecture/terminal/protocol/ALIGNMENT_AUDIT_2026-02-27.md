# Protocol Alignment Audit (2026-02-27)

Owner: agent
Scope: Cross-reference Zide terminal protocol behavior against xterm/kitty/ghostty/foot snapshots.
Method: Parallel subsystem audit (VT CSI/private modes, kitty graphics, keyboard/CSI-u), then merged implementation backlog.

## VT CSI / Private Modes (xterm + ghostty)

### Confirmed mismatches

1. `CSI s` ambiguity under `?69` (`DECLRMM`)
- Reference behavior: under `?69`, `CSI s` is `DECSLRM`, not save-cursor.
- Zide currently routes zero-param `CSI s` to save-cursor when `?69` is enabled.
- Evidence:
  - `reference_repos/terminals/xterm_snapshots/ctlseqs.txt:1584`
  - `reference_repos/terminals/xterm_snapshots/ctlseqs.txt:1588`
  - `reference_repos/terminals/ghostty/src/terminal/stream.zig:1736`
  - `src/terminal/protocol/csi.zig:167`

2. `DECSTBM` cursor-home semantics differ (DECOM interaction)
- Ghostty/xterm-family behavior homes to display/home semantics via cursor-pos logic.
- Zide currently forces cursor to `top,leftBoundary` unconditionally in `setScrollRegion`.
- Evidence:
  - `reference_repos/terminals/ghostty/src/terminal/Terminal.zig:1354`
  - `src/terminal/model/screen/screen.zig:745`

3. Equal bounds acceptance (`top==bottom`, `left==right`)
- Ghostty rejects invalid/equal bounds.
- Zide currently accepts `top <= bottom` and `left <= right`.
- Evidence:
  - `reference_repos/terminals/ghostty/src/terminal/Terminal.zig:1357`
  - `reference_repos/terminals/ghostty/src/terminal/Terminal.zig:1371`
  - `src/terminal/protocol/csi.zig:161`
  - `src/terminal/protocol/csi.zig:174`

4. DECRQM param cardinality/policy gaps
- Ghostty enforces single param for DECRQM.
- Zide reads first param and ignores extras.
- Evidence:
  - `reference_repos/terminals/ghostty/src/terminal/stream.zig:1600`
  - `src/terminal/protocol/csi.zig:268`

## Kitty Graphics (kitty + ghostty)

### Confirmed mismatches

1. Delete success reply policy
- Kitty/ghostty suppress success reply for delete.
- Zide currently emits `OK` after delete action.
- Evidence:
  - `reference_repos/terminals/ghostty/src/terminal/kitty/graphics_exec.zig:291`
  - `reference_repos/terminals/kitty/kitty/graphics.c:796`
  - `src/terminal/kitty/graphics.zig:124`

2. Unknown delete selectors
- Kitty/ghostty treat unknown selectors as invalid.
- Zide currently no-ops unsupported selector and reports success (existing fixture lock).
- Evidence:
  - `reference_repos/terminals/kitty/kitty/parse-graphics-command.h:185`
  - `reference_repos/terminals/ghostty/src/terminal/kitty/graphics_command.zig:954`
  - `src/terminal/kitty/graphics.zig:1534`
  - `fixtures/terminal/kitty_delete_unsupported_selector_noop.vt`

3. Parent semantics and depth limit
- Kitty allows `P` without `Q` (default parent placement), and depth limit differs.
- Zide currently requires both `P` and `Q`; depth threshold differs from kitty.
- Evidence:
  - `reference_repos/terminals/kitty/kitty/graphics.c:1084`
  - `src/terminal/kitty/graphics.zig:547`
  - `src/terminal/kitty/graphics.zig:68`

4. Query missing ID behavior
- Ghostty expects no reply when query lacks both `i/I`.
- Zide currently replies `EINVAL`.
- Evidence:
  - `reference_repos/terminals/ghostty/src/terminal/kitty/graphics_exec.zig:536`
  - `src/terminal_kitty_reply_tests.zig:73`

## Keyboard / CSI-u (kitty + foot + ghostty)

### Confirmed mismatches

1. `embed_text` emitted on release
- Ghostty/foot suppress associated text on release.
- Zide currently emits associated text field on release.
- Evidence:
  - `reference_repos/terminals/ghostty/src/input/key_encode.zig:279`
  - `reference_repos/terminals/foot/input.c:1327`
  - `src/terminal/input/input.zig:361`

2. `embed_text` limited to single codepoint
- Kitty/foot support multi-codepoint associated text fields.
- Zide currently serializes one codepoint.
- Evidence:
  - `reference_repos/terminals/kitty/kitty/key_encoding.c:84`
  - `reference_repos/terminals/foot/input.c:1515`
  - `src/terminal/input/input.zig:364`

3. Alternate key serialization is shift-gated
- Kitty/foot can emit alternate without requiring shifted variant.
- Zide currently gate-checks alternate on shift path.
- Evidence:
  - `reference_repos/terminals/kitty/kitty/key_encoding.c:56`
  - `reference_repos/terminals/foot/input.c:1488`
  - `src/terminal/input/input.zig:335`

## Merged Backlog (Combined Todos)

- `AUDIT-01` Fix `CSI s` ambiguous dispatch under `?69` (`DECLRMM`) and lock with unit+replay.
- `AUDIT-02` Align `DECSTBM` cursor-home semantics with DECOM/DECLRMM interactions.
- `AUDIT-03` Enforce strict invalid equal-bounds rejection for `DECSTBM` / `DECSLRM`.
- `AUDIT-04` Tighten DECRQM single-param validation and update policy matrix fixtures.
- `AUDIT-05` Suppress success replies for kitty delete (`a=d`) and lock missing-id query no-reply policy decision.
- `AUDIT-06` Replace unknown kitty delete selector no-op with explicit invalid error.
- `AUDIT-07` Extend kitty delete selector surface (`q/Q`, `f/F`) or explicitly defer with lock.
- `AUDIT-08` Parent semantics parity decision (`P` without `Q`) + depth-limit policy lock.
- `AUDIT-09` Keyboard P0: suppress `embed_text` on release.
- `AUDIT-10` Keyboard P0: multi-codepoint associated text field for `embed_text`.
- `AUDIT-11` Keyboard P1: allow alternate-field emission without shift.

## Master Loop Order

1. `AUDIT-01`
2. `AUDIT-09`
3. `AUDIT-05`
4. `AUDIT-03`
5. `AUDIT-10`
6. `AUDIT-06`
7. `AUDIT-02`
8. `AUDIT-04`
9. `AUDIT-08`
10. `AUDIT-11`
11. `AUDIT-07`

Notes:
- Keep commits small: one backlog item per commit.
- Each item requires explicit tests/fixtures and PROTOCOL progress doc update before commit.
