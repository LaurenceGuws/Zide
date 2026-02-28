# Terminal FFI PTY ABI

Date: 2026-02-27

Purpose: define how PTY/process ownership crosses the first terminal bridge.

Status: planning baseline with milestone-1 decisions aligned to the current implementation.

## Goal

Make PTY ownership explicit so hosts understand what the bridge does today and what may become optional later.

## Milestone 1 decision

Milestone 1 uses backend-owned PTYs.

That means:
- the bridge creates and owns the PTY/process when `start()` is called
- the host does not supply file descriptors, pipes, or byte streams
- the host drives progress by calling `poll()`
- process liveness is exposed through `is_alive()` and child-exit events

This matches the current `TerminalSession` architecture and keeps the first bridge small.

## Why this is the right first step

The backend already owns:
- platform PTY setup
- shell spawning
- resize propagation
- read/write coordination
- exit-code tracking

Exporting that as-is gives us a real host boundary quickly.

Designing a more abstract transport immediately would add risk before we have a proven foreign consumer.

## Current ownership model

Backend owns:
- PTY allocation and teardown
- child process lifecycle
- platform-specific resize calls
- output buffering and parser feed
- exit-code observation

Host owns:
- when to call `start()`
- what shell path to pass to `start()`
- when to call `poll()`
- when to send bytes/text/key/mouse events
- when to destroy the session

## Current host calls

Relevant exported calls:
- `zide_terminal_start(handle, shell)`
- `zide_terminal_poll(handle)`
- `zide_terminal_resize(handle, cols, rows, cell_width, cell_height)`
- `zide_terminal_send_bytes(handle, ptr, len)`
- `zide_terminal_send_text(handle, ptr, len)`
- `zide_terminal_send_key(handle, event)`
- `zide_terminal_send_mouse(handle, event)`
- `zide_terminal_is_alive(handle)`

## Poll model

Milestone 1 is polling-based, not callback-based.

Reason:
- easier to bind from Python `ctypes`
- easier to reason about lock ownership
- avoids callback re-entry and thread-affinity issues too early

Expected host loop:
1. start session
2. send input if needed
3. call `poll()` periodically
4. acquire snapshot and/or drain events
5. stop when `is_alive()` is false or the host is done

## Platform notes

The PTY backend is already platform-split:
- `src/terminal/io/pty_unix.zig`
- `src/terminal/io/pty_windows.zig`
- stub for unsupported platforms

Bridge implication:
- exported behavior is conceptually uniform
- implementation differences remain platform-specific underneath
- the bridge docs must not pretend unsupported platforms behave the same

Milestone 1 target platforms:
- Linux
- macOS
- Windows

Non-goal for milestone 1:
- browser/mobile PTY stories

## Shell parameter policy

`start(shell)` currently accepts either:
- null: use backend default shell behavior
- explicit shell path: host-supplied program path

Hosts should not assume shell startup is synchronous or prompt-ready immediately.

Recommended smoke approach:
- start `/bin/sh` explicitly on Unix-like systems
- poll briefly before asserting output state

## Future extension: external byte-source mode

A future bridge may allow hosts to bypass backend-owned PTYs and instead:
- create a session without spawning
- feed output bytes into the parser directly
- consume encoded input bytes instead of writing them internally

That mode is useful for:
- remote shells
- multiplexers
- replay tools
- daemon/session-sharing models

But it is not part of milestone 1.

## Future extension: daemon/session-sharing mode

A future out-of-process model may still reuse the same high-level contracts:
- poll or drain output
- acquire snapshot
- drain events
- resize and send input

That should be treated as a follow-on architecture, not baked into the initial in-process bridge.

## Current limitations

Milestone 1 does not provide:
- host-supplied PTY/file descriptor adoption
- async wake callbacks
- transport-neutral session start modes
- explicit environment map export/import in the bridge API

Those can be added later once the current backend-owned PTY flow is exercised by a real foreign host.

## Focused follow-on slice

The next PTY-hosting step should be a dedicated bridge slice:
- stabilize `start()` for foreign hosts
- add a PTY-backed Python smoke variant separately from the base no-PTY smoke
- keep create/resize/snapshot/event contract coverage green while debugging PTY hosting

Current status:
- the base `ctypes` smoke remains non-PTY and is the stable contract authority
- a separate opt-in PTY smoke may start `/bin/sh`, send bytes, poll, inspect snapshots, and observe child-exit behavior
- PTY smoke failures should not weaken the non-PTY ownership/lifetime contract
