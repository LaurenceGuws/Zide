# VT Core Feed Execution Front

Date: 2026-04-04

## Purpose

Name the next exact broader `TerminalCore` sufficiency contradiction after the
resize owner front flattened.

## Current Judgment

The next live contradiction is feed execution dependency.

This is where `TerminalCore` still most clearly reads like:

- core owns output feed as a method
- but parser/protocol execution still requires a composite outer execution
  receiver to make that method complete

## Live Pressure

The pressure is concentrated in:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - `feedOutputBytesLocked(self, owner, bytes)`
- [protocol_execution.zig](/home/home/personal/zide/src/terminal/core/session/protocol_execution.zig)
  - `ProtocolExecution.init(owner, core)`

The surviving execution receiver is cleaner than before, but it still bundles:

- protocol state reach
- publication/update reach
- runtime write/wake reach
- lock access

That is materially better than shell-shaped ownership, but it is still the
strongest remaining place where a core method depends on outer execution shape
to become complete host-visible terminal behavior.

## Why This Beats Other Candidates

It beats:

- reopening resize after its stop-marker
- chasing `deinit(...)`, which now reads mostly lifecycle-shaped
- reopening shell cleanup by momentum

Because feed/application still sits closer to the center of "this is the
terminal" than the remaining weaker owner-shaped methods.

## Required Bar

The next move must not be:

- renaming `owner` to a nicer noun
- pretending the current execution contract is final just because it is named
- dragging reply/report/runtime mechanics into core

The next move must:

- isolate one narrower surviving feed execution dependency
- reduce the composite execution receiver in substance
- make parser/protocol feed read more terminal-centered than it does now

## Decision

The next default VT front is feed execution dependency unless a stronger named
`TerminalCore` contradiction overtakes it immediately.
