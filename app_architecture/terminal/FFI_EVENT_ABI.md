# Terminal FFI Event ABI

Date: 2026-02-28

Purpose: define the first exported event-buffer contract for foreign hosts.

Status: milestone-1 baseline. This document describes the event shape currently implemented by `src/terminal/ffi/bridge.zig`.

## Versioning

Current scalar version queries:
- `zide_terminal_event_abi_version() -> 1`

Current event struct:
- `ZideTerminalEvent`
- `ZideTerminalEventBuffer`

Unlike snapshots, the event buffer does not yet carry an inline struct header.
Hosts should treat the exported scalar version query as the authority for the
current event layout.

## Exported types

### `ZideTerminalEvent`

Fields:
- `kind`
- `data_ptr`
- `data_len`
- `int0`
- `int1`

Rules:
- `kind` selects the payload semantics
- `data_ptr`/`data_len` carry optional owned bytes
- `int0`/`int1` carry small scalar metadata when needed

### `ZideTerminalEventBuffer`

Fields:
- `events`
- `count`
- `_ctx`

Rules:
- `events` points to a flat array of `count` events
- `_ctx` is release bookkeeping only and is not host data

## Ownership contract

Acquisition:
- host calls `zide_terminal_event_drain(handle, &buffer)`
- on success, the bridge owns all pointed-to memory until release

Release:
- host must call `zide_terminal_events_free(&buffer)`
- after release, all `events` pointers and all per-event `data_ptr` values are invalid
- release zeroes the exported event buffer as a defensive measure

Invalid usage:
- retaining any event payload pointer after release
- mutating bridge-owned payload memory
- freeing `data_ptr` directly instead of releasing the full event buffer

## Event kinds in milestone 1

### `title_changed`

Kind:
- `ZideTerminalEventKind.title_changed`

Payload:
- `data_ptr`/`data_len` contain UTF-8 title bytes
- `int0 = 0`
- `int1 = 0`

### `cwd_changed`

Kind:
- `ZideTerminalEventKind.cwd_changed`

Payload:
- `data_ptr`/`data_len` contain UTF-8 cwd bytes
- `int0 = 0`
- `int1 = 0`

### `clipboard_write`

Kind:
- `ZideTerminalEventKind.clipboard_write`

Payload:
- `data_ptr`/`data_len` contain clipboard bytes
- payload is normalized for hosts: no trailing internal NUL terminator
- `int0 = 0`
- `int1 = 0`

Notes:
- milestone 1 does not yet expose clipboard MIME or selection kind
- treat payload as opaque bytes, not necessarily text

### `child_exit`

Kind:
- `ZideTerminalEventKind.child_exit`

Payload:
- `data_ptr = null`
- `data_len = 0`
- `int0 = exit code`
- `int1 = 1` when the exit code is present

Notes:
- current implementation emits one `child_exit` event per session
- hosts may still call `zide_terminal_is_alive()` as the latest-state check
- hosts may also call `zide_terminal_child_exit_status()` as the latest-state getter

### `alive_changed`

Kind:
- `ZideTerminalEventKind.alive_changed`

Payload:
- `data_ptr = null`
- `data_len = 0`
- `int0 = 1` when alive, `0` when not alive
- `int1 = 0`

Notes:
- this is emitted when the bridge observes host/session liveness change
- it is latest-state compatible with `zide_terminal_is_alive()`

### `redraw_ready`

Kind:
- `ZideTerminalEventKind.redraw_ready`

Payload:
- `data_ptr = null`
- `data_len = 0`
- `int0 = 0`
- `int1 = 0`

Notes:
- current milestone-1 meaning is only: a newer snapshot generation exists
- this is a wake signal for snapshot pull, not a presentation contract
- shared semantic authority now lives in:
  - `app_architecture/terminal/RENDER_PUBLICATION_CONTRACT.md`
- this event remains intentionally separate from present acknowledgement

Update:
- the first explicit host-facing present acknowledgement surface is now landed
  as direct bridge calls:
  - `zide_terminal_present_ack(handle, generation)`
  - `zide_terminal_acknowledged_generation(handle, &generation)`
- the bridge now also exposes:
  - `zide_terminal_published_generation(handle, &generation)`
  - `zide_terminal_needs_redraw(handle)`
- `redraw_ready` itself remains a wake signal for snapshot pull; it is still
  not a present event

## Drain semantics

Event delivery is destructive:
- `event_drain()` returns the currently queued discrete events
- the bridge queue is cleared when the drain succeeds
- a later drain will only contain newer events

This is intentional. The event queue marks change boundaries, while snapshots
and direct getters provide latest state.

## Host guidance

Recommended host behavior:
1. call `zide_terminal_event_abi_version()`
2. drain events
3. dispatch by `kind`
4. consume `data_ptr` bytes before release
5. release the whole buffer with `zide_terminal_events_free()`

Do not:
- hold onto event payload pointers after release
- assume every event kind has string payload bytes
- infer ownership from `data_ptr` alone

## Deliberate omissions in milestone 1

Not exported yet:
- bell
- clipboard read request/response
- hyperlink open intent
- MIME-tagged clipboard events
- wakeup hints or callbacks
- acknowledged/presented generation events or getters

Explicit host present acknowledgement is now handled by direct getters/calls
instead of by overloading the event stream. Additional acknowledged-generation
event semantics remain follow-on work after the baseline queue contract.
