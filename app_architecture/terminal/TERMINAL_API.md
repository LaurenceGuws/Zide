# Terminal API Contract

Date: 2026-01-24

Purpose: define stable API contracts for the terminal surface to prevent accidental behavior drift during modularization.

Status: post-modularization. Treat behaviors as hypotheses unless verified by baseline fixtures.

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
- Populate test names as fixtures and unit tests land in `fixtures/terminal` and `src/terminal_*_tests.zig`.
- Update this table with observed behavior once baseline fixtures exist.
- Contracted behavior only after verified tests; do not assert guarantees early.
- Implementation is now modularized across `src/terminal/core/*` helpers; API surface remains `TerminalSession`.

Replay fixtures referenced above live under `fixtures/terminal` and are executed via `zig build test-terminal-replay`.

## Workspace API Contract (tabs)

`TerminalWorkspace` lives in `src/terminal/core/workspace.zig` and owns tab/session orchestration above `TerminalSession`.

| API | Inputs | Outputs | Lifetime | Allocations | Invariants | Tests |
| --- | ------ | ------- | -------- | ----------- | ---------- | ----- |
| TerminalWorkspace.init | allocator, init_options | TerminalWorkspace | caller owns workspace | no session alloc yet | active index is 0 with no tabs | terminal_workspace_tests |
| TerminalWorkspace.deinit | self | void | n/a | frees owned sessions + tab storage | all sessions deinitialized exactly once | terminal_workspace_tests |
| TerminalWorkspace.createTab | rows, cols | TabId | tab/session owned by workspace | allocates one session + tab entry | new tab becomes active | terminal_workspace_tests |
| TerminalWorkspace.closeTab | tab_id | bool | n/a | frees one owned session on success | active index normalized after removal | terminal_workspace_tests |
| TerminalWorkspace.closeActiveTab | - | bool | n/a | frees one owned session on success | no-op when empty | terminal_workspace_tests |
| TerminalWorkspace.activateIndex | index | bool | n/a | none | active index valid only when index in range | terminal_workspace_tests |
| TerminalWorkspace.activateTab | tab_id | bool | n/a | none | tab id maps to one active entry | terminal_workspace_tests |
| TerminalWorkspace.activateNext/Prev | - | bool | n/a | none | wraps when more than one tab exists | terminal_workspace_tests |
| TerminalWorkspace.moveTab | tab_id, to_index | bool | n/a | may move backing entries | active tab id preserved across move | terminal_workspace_tests |
| TerminalWorkspace.metadataAt | index | ?TabMetadata | borrowed from active session state | none | metadata is session-derived, not duplicated | terminal_workspace_tests |
| TerminalWorkspace.pollAll | active_input_index?, has_input | bool(any polled) | n/a | none | input pressure only applied to selected tab for current frame | terminal_workspace_tests |
| TerminalWorkspace.resizeAll | rows, cols | void/error | n/a | session-internal resize alloc behavior | applies consistently across all tabs | pending |
| TerminalWorkspace.setCellSizeAll | cell_width, cell_height | void | n/a | none | applies consistently across all tabs | pending |

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
