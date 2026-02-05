# Terminal API Contract

Date: 2026-01-24

Purpose: define stable API contracts for the terminal surface to prevent accidental behavior drift during modularization.

Status: pre-refactor. Treat behaviors as hypotheses unless verified by baseline fixtures.

## Contract Table

| API | Inputs | Outputs | Lifetime | Allocations | Invariants | Tests |
| --- | ------ | ------- | -------- | ----------- | ---------- | ----- |
| TerminalSession.init | allocator, rows, cols | *TerminalSession | caller owns session | allocates internal buffers | to be verified | replay:smoke |
| TerminalSession.deinit | self | void | n/a | frees all owned buffers | to be verified | replay:smoke |
| TerminalSession.start | shell? | void | n/a | PTY alloc | to be verified | pending |
| TerminalSession.poll | - | void | n/a | to be verified | to be verified | pending |
| TerminalSession.resize | rows, cols | void | n/a | to be verified | to be verified | terminal_reflow_tests |
| TerminalSession.setCellSize | w, h | void | n/a | to be verified | to be verified | pending |
| TerminalSession.sendKey | key, mod | void/error | n/a | to be verified | to be verified | encoder:csi_u_encoder_bytes |
| TerminalSession.sendKeypad | key, mod | void/error | n/a | to be verified | to be verified | pending |
| TerminalSession.sendChar | codepoint, mod | void/error | n/a | to be verified | to be verified | encoder:csi_u_encoder_bytes |
| TerminalSession.sendText | text | void/error | n/a | to be verified | to be verified | replay:smoke |
| TerminalSession.reportMouseEvent | event | bool/error | n/a | to be verified | to be verified | pending |
| TerminalSession.snapshot | - | TerminalSnapshot | to be verified | to be verified | to be verified | replay:cursor_moves_basic |
| TerminalSession.selectionState | - | ?TerminalSelection | to be verified | to be verified | to be verified | replay:selection_basic_flow |
| TerminalSession.clearSelection | - | void | n/a | to be verified | to be verified | replay:selection_basic_flow |
| TerminalSession.currentCwd | - | []const u8 | to be verified | to be verified | to be verified | replay:osc_cwd_st |
| TerminalSession.takeOscClipboard | - | ?[]const u8 | to be verified | to be verified | to be verified | replay:osc_52_clipboard_bel |
| TerminalSession.hyperlinkUri | link_id | ?[]const u8 | to be verified | to be verified | to be verified | replay:osc_8_hyperlink_bel |
| TerminalSession.isAlive | - | bool | n/a | to be verified | to be verified | pending |
| TerminalSession.lock/unlock | - | void | n/a | to be verified | to be verified | pending |

Notes:
- Populate test names as fixtures land in `src/terminal_tests.zig`.
- Update this table with observed behavior once baseline fixtures exist.
- Contracted behavior only after verified tests; do not assert guarantees early.
- Implementation is now modularized across `src/terminal/core/*` helpers; API surface remains `TerminalSession`.

Replay fixtures referenced above live under `fixtures/terminal` and are executed via `zig build test-terminal-replay`.

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
