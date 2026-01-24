# Terminal API Contract

Date: 2026-01-24

Purpose: define stable API contracts for the terminal surface to prevent accidental behavior drift during modularization.

Status: pre-refactor. Treat behaviors as hypotheses unless verified by baseline fixtures.

## Contract Table

| API | Inputs | Outputs | Lifetime | Allocations | Invariants | Tests |
| --- | ------ | ------- | -------- | ----------- | ---------- | ----- |
| TerminalSession.init | allocator, rows, cols | *TerminalSession | caller owns session | allocates internal buffers | to be verified | terminal_init_basics |
| TerminalSession.deinit | self | void | n/a | frees all owned buffers | to be verified | terminal_deinit_frees |
| TerminalSession.start | shell? | void | n/a | PTY alloc | to be verified | terminal_start_pty |
| TerminalSession.poll | - | void | n/a | to be verified | to be verified | terminal_poll_io |
| TerminalSession.resize | rows, cols | void | n/a | to be verified | to be verified | terminal_resize_rules |
| TerminalSession.setCellSize | w, h | void | n/a | to be verified | to be verified | terminal_cell_metrics |
| TerminalSession.sendKey | key, mod | void/error | n/a | to be verified | to be verified | terminal_send_key |
| TerminalSession.sendKeypad | key, mod | void/error | n/a | to be verified | to be verified | terminal_send_keypad |
| TerminalSession.sendChar | codepoint, mod | void/error | n/a | to be verified | to be verified | terminal_send_char |
| TerminalSession.sendText | text | void/error | n/a | to be verified | to be verified | terminal_send_text |
| TerminalSession.reportMouseEvent | event | bool/error | n/a | to be verified | to be verified | terminal_mouse_reporting |
| TerminalSession.snapshot | - | TerminalSnapshot | to be verified | to be verified | to be verified | terminal_snapshot_basic |
| TerminalSession.selectionState | - | ?TerminalSelection | to be verified | to be verified | to be verified | terminal_selection_state |
| TerminalSession.clearSelection | - | void | n/a | to be verified | to be verified | terminal_selection_clear |
| TerminalSession.currentCwd | - | []const u8 | to be verified | to be verified | to be verified | terminal_cwd |
| TerminalSession.takeOscClipboard | - | ?[]const u8 | to be verified | to be verified | to be verified | terminal_osc52 |
| TerminalSession.hyperlinkUri | link_id | ?[]const u8 | to be verified | to be verified | to be verified | terminal_osc8 |
| TerminalSession.isAlive | - | bool | n/a | to be verified | to be verified | terminal_is_alive |
| TerminalSession.lock/unlock | - | void | n/a | to be verified | to be verified | terminal_locking |

Notes:
- Populate test names as fixtures land in `src/terminal_tests.zig`.
- Update this table with observed behavior once baseline fixtures exist.
- Contracted behavior only after verified tests; do not assert guarantees early.

## Layering Rules (Imports)

Use `zig build check-terminal-imports` to enforce these rules.

| Layer | Allowed Imports |
| --- | --- |
| core | model, parser, protocol, io, input, kitty |
| protocol | parser, model, io |
| parser | parser |
| model | model |
| input | io, model |
| io | io |
| kitty | core |
| harness | any (test-only) |

## Fixture Scope (authoritative)
- VT replay fixtures: see `app_architecture/terminal/MODULARIZATION_PLAN.md`
- Harness API fixtures (selection)
- Encoder unit tests (CSI-u)
