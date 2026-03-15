# VT Core Split Progress (2026-03-10)

This file holds the extraction-progress notes that previously lived inline in
`app_architecture/terminal/VT_CORE_DESIGN.md`.

Use it for:
- dated split-progress notes
- extraction checkpoints
- transport/feed/dispatch ownership progression

Use `app_architecture/terminal/VT_CORE_DESIGN.md` for the current engine/core
boundary authority, target types, ownership map, event model, FFI direction,
and compatibility strategy.

## 2026-03-10 Protocol Split Follow-up

The next extraction-only step moved pure engine-side protocol helpers behind
`src/terminal/core/terminal_core_protocol.zig`.

This module currently owns the protocol behaviors that are already clearly
core/model-centered:

- screen erase/insert/delete helpers
- palette lookups
- core cursor and cell queries
- cursor style changes
- tab-stop-at-cursor
- DECRQSS reply formatting that only depends on core state

`session_protocol.zig` now remains focused on the still session-coupled pieces:

- parser feed/dispatch entrypoints
- alt-screen transitions
- selection/cache invalidation coordination
- runtime-facing protocol side effects

## 2026-03-10 Dispatch Split Follow-up

Parser/control dispatch ownership is now partially split again:

- `src/terminal/core/terminal_core_dispatch.zig` owns control, CSI, OSC, APC,
  DCS, codepoint, and ASCII dispatch entry helpers
- `session_protocol.zig` now keeps the session-coupled pieces that still depend
  on session-owned locking and publication

The main remaining reason parser feed still lives in `session_protocol.zig` is
that byte feed currently owns:

- state mutex acquisition
- output generation increments
- view-cache publication updates

That is the next real boundary to cleanly separate if we want parser feed to
become fully core-owned.

## 2026-03-10 Feed Split Follow-up

Parser byte feed is now split one step further:

- `src/terminal/core/terminal_core_feed.zig` owns the actual parser feed call
- `src/terminal/core/terminal_core_feed.zig` now also returns an explicit
  `FeedResult` carrying publication-relevant state
- `session_protocol.zig` now only wraps that feed with:
  - state mutex ownership
  - delegation of generation/view-cache publication to
    `src/terminal/core/session_rendering.zig`

This makes the remaining session-owned part of parser feed explicit: it is not
parsing anymore, it is lock and publication choreography.

## `TerminalTransport`

The internal `TerminalTransport` contract lives in
`src/terminal/core/terminal_transport.zig`.

Current scope:

- PTY open/start wiring
- transport resize delivery
- has-data checks
- child-exit polling
- aliveness checks
- foreground-process label and close-confirm metadata
- transport deinit

Current PTY-backed runtime code now consumes that contract in:

- `session_runtime.zig`
- `resize_reflow.zig`
- `session_queries.zig`

This was intentionally not the final transport split at first: host lifecycle
and metadata were moved behind the contract before byte IO.

## 2026-03-10 Writer Contract Follow-up

The transport boundary now also owns the main locked writer contract:

- `terminal_transport.Writer` replaces the old raw `Pty` writer guard
- input send paths now call transport-owned writer methods for:
  - key actions
  - key action events
  - keypad sends
  - char actions
  - char action events
  - mouse reports
  - plain text sends
  - raw byte writes

This means the common protocol/input write surface no longer depends on a raw
`Pty*` shape.

What still remains PTY-direct:

- a smaller set of transport setup/existence paths

## 2026-03-10 Read Path Follow-up

The transport boundary now also owns the common read side:

- `terminal_transport.Transport.read(...)`
- `terminal_transport.Transport.waitForData(...)`

Current PTY-backed runtime code now uses those methods in:

- `io_threads.zig`
- `pty_io.zig`

This means the main byte pump no longer depends on raw `Pty` ownership in the
runtime helpers. The remaining PTY-direct uses are narrower and mostly about
transport existence checks plus setup paths that have not been re-cut yet.

## 2026-03-10 Transport Presence Follow-up

The remaining low-risk presence gates are now also routed through
`terminal_transport` helpers:

- `terminal_transport.Writer.exists(...)`
- `terminal_transport.Transport.exists(...)`

Current session-side users no longer peek at `self.pty` directly just to answer
"is there a writable transport?" for the mouse-report and OSC 5522 paste-event
paths.

The protocol-side OSC 5522 reply/read path now also uses the locked transport
writer contract instead of reaching into raw `self.pty` ownership directly.

## 2026-03-10 Attach/Detach Follow-up

PTY setup now also has a transport-owned attach/detach seam:

- `terminal_transport.attachPty(...)`
- `terminal_transport.detachPty(...)`

Current users:

- `terminal_transport.openPty(...)`
- `replay_harness.zig` reply-capture setup

That removes another direct `session.pty = ...` / `session.pty = null` setup
pair from callers outside the transport owner.
