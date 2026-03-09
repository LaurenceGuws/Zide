# Terminal Workspace Contract

Date: 2026-03-03

Purpose: define the backend-owned tab/workspace layer for terminal-only mode and future FFI tab support.

Status: initial contract and implementation baseline.

## Why this layer exists

`TerminalSession` is the VT/session primitive. It should stay focused on:
- PTY lifecycle and I/O
- parser/protocol/screen state
- snapshots and per-session metadata

Tab management is a separate concern:
- session orchestration
- active tab routing
- tab ordering and stable tab ids
- workspace-level lifecycle policy

That orchestration now lives in `src/terminal/core/workspace.zig` as `TerminalWorkspace`.

## Boundary rules

- `TerminalSession` remains single-session and tab-unaware.
- `TerminalWorkspace` owns session objects and tab ids.
- UI tab chrome (`TabBar`) projects workspace state; it does not own tab lifecycle.
- FFI tab APIs should map to workspace operations, not UI widget internals.

## Data model

- `TabId`: stable u64 id for workspace lifetime.
- internal `Tab`: `{ id, session }`.
- `TabSyncEntry` / `TabSyncState`:
  - workspace-owned projection for tab-bar sync
  - carries tab ids plus derived title/cwd/alive/exit state
  - string storage is exported as one caller-owned blob with per-entry offsets, so UI sync consumes one coherent snapshot instead of multiple indexed queries

## Core operations

- `createTab(rows, cols)` -> creates a new `TerminalSession` and activates it.
- `createTabWithSession(rows, cols)` -> same creation path, but returns the created session for immediate bootstrap/configuration by runtime code.
- `closeTab(id)` / `closeActiveTab()` -> destroys session and normalizes active index.
- `activateTab(id)` / `activateIndex(index)` / `activateNext()` / `activatePrev()`.
- `moveTab(id, to_index)` -> ordered move with active-tab preservation.
- `activeSessionCwd()` / `activeSessionShouldConfirmClose()` / `firstConfirmCloseTab()` -> read-only workspace queries for app/runtime decisions that should not need raw session access.
- `activeSessionHasData()` / `activeSessionPublishedGeneration()` / `activeSessionCurrentGeneration()` / `publishedGenerationAt(index)` -> read-only workspace queries for runtime pacing/publication code.
- `copyTabSyncState(...)` -> workspace-owned tab-bar projection contract for ids + labels + active-tab state.
- `setCellSizeAll()` + `resizeAll()` -> workspace-wide geometry propagation.
- `pollForFrame(active_input_index, has_input)` -> workspace-owned resource-aware polling across tabs; budget shaping is internal to workspace polling, not part of the public contract.

## Invariants

- Active index is always valid when tabs exist.
- Closing a tab destroys exactly one owned `TerminalSession`.
- Metadata remains session-derived; no duplicated title/cwd caches in workspace.
- UI tab-bar sync should consume `copyTabSyncState(...)` rather than stitching together `tabCount/tabIdAt/activeTabId` plus per-index metadata calls.
- UI and FFI should consume ids/metadata via workspace APIs.

## Background tab resource policy (initial)

- Poll all tabs each frame, but only when `session.hasData()` is true.
- Input pressure is applied only to the active tab during that frame.
- No per-tab busy-wait loops.
- This is a conservative baseline for battle testing; advanced scheduling can follow once production traces exist.

## `--mode terminal` integration policy

- Terminal-only mode uses workspace as tab source of truth.
- UI tab bar state is synchronized from workspace each frame.
- Required baseline actions:
  - new tab
  - close active tab
  - next/previous tab
  - activate tab by index (1-9)

## Follow-on for FFI

After workspace behavior stabilizes in terminal-only mode:
- extend FFI with workspace handle operations
- preserve stable `TabId` semantics across host calls
- keep explicit ownership rules consistent with existing snapshot/event/string APIs
