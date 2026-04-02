# VT War 4 Resize Report Review

Date: 2026-04-03

## Purpose

Open the second War 4 interaction slab:

- resize / report contract

The first slab, output feed/apply, is now coherent enough to stop by default.
The next honest question is whether resize semantics should read more
terminal-owned while transport resize reporting stays runtime-owned.

## Current Shape

Today resize is split across:

- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  for terminal resize/reflow semantics
- [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)
  for transport resize and in-band notification
- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  as the exported shell entrypoint
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
  and native callers as the host-facing route

## Why This Is The Right Second Slab

Resize is one of the clearest host-driven terminal verbs.

But it is currently mixed:

- terminal reflow and viewport/selection consequences are engine semantics
- PTY resize and in-band resize reporting are runtime/transport concerns

That makes it the right next test of the War 4 rule:

- move the semantic part toward the engine
- keep reporting/transport outside it

## Design Bar

The correct shape is not:

- move `transport.resize(...)` into
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- move in-band resize report generation into core

The correct shape is:

- terminal resize/reflow semantics read as a core-owned verb
- shell/runtime still owns:
  - locking
  - PTY/external transport resize
  - in-band resize reporting

## Bottom Line

If War 4 continues in code, resize/reporting is now the next clean slab.

Progress note, later on 2026-04-03:

- the first resize slice is now in
- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns the semantic `resizeLocked(...)` verb
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  still owns shell locking plus transport resize reporting
- this matches the same successful War 4 pattern used for feed/apply:
  - semantic terminal behavior moved closer to core
  - transport/reporting stayed outside it
