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

## Boundary Contract (2026-03-09)

This is the current intended ownership split for the next cleanup phase. It is more
important than the exact file layout.

| Concern | Owner | Must Not Own |
| --- | --- | --- |
| PTY lifecycle, read/write threading, backlog drain policy | terminal runtime/core | widget draw/input policy |
| VT parser dispatch + protocol semantics | parser/protocol layer | renderer policy, widget state |
| screen/history/selection state | model layer | frame pacing, GL upload decisions |
| damage publication -> render cache publication | publication/cache layer | app-level scheduling, widget interaction policy |
| presented-generation ack / dirty retirement | backend publication boundary | renderer-local heuristics |
| tab ownership + simple active/background polling surface | workspace | app-global frame timing state |
| frame sleep, redraw cadence, metrics aggregation | app runtime | terminal model mutation |
| hover/open/selection gestures, clipboard UX, scrollbar UX | widget layer | terminal core invalidation policy |

### Immediate Cleanup Rules

1. `TerminalSession` should trend toward an orchestrator, not a universal owner.
2. Widgets should consume published terminal state and emit intents; they should not
   participate in backend dirty-ack lifecycle.
3. Protocol modules should mutate terminal state through an explicit facade or narrow
   contract, not broad implicit `anytype self` assumptions.
4. Input-mode publication must become harder to forget than the current
   branch-by-branch `updateInputSnapshot()` pattern.
5. Scheduler state should be instance-owned, not file-global.

### Current Violations To Reduce

- `TerminalSession` still owns too many domains.
- `terminal_widget_draw` still clears backend dirty state after upload.
- `view_cache` still embeds both cache publication and some redraw-policy knowledge.
- poll/render runtime still carries terminal-global state in helper modules.
- protocol handlers still rely on implicit `self` capabilities.

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
| TerminalWorkspace.resizeAll | rows, cols | void/error | n/a | session-internal resize alloc behavior | applies consistently across all tabs | pending |
| TerminalWorkspace.setCellSizeAll | cell_width, cell_height | void | n/a | none | applies consistently across all tabs | pending |
| TerminalWorkspace.pollForFrame | input_active_index, has_input | bool/error | n/a | none | workspace-owned polling fairness policy; return value means published generation advanced for the tracked active session | pending |

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
