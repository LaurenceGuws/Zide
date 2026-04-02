# VT Public Resize War

Date: 2026-04-03

## Purpose

Open the next concrete VT plug-and-play gap after the input-semantics wave:

- public resize still reads shell-first in feel

This is not another general shell-thinning pass.
It is specifically about making the host-facing resize contract read like:

- configure terminal resize inputs once
- apply terminal resize semantics once
- let runtime/transport consequences happen outside that semantic center

## Live Problem

Before this cut, the live host resize story was split:

- app/native paths commonly did:
  - `setCellSize(...)`
  - then `resize(...)`
- FFI host resize did:
  - `resize(...)`
  - then `setCellSize(...)`

That split was not just ugly.
It taught two different public stories for the same host-facing operation.

It also meant that in-band resize reporting could observe stale cell metrics on
the FFI path.

## First Slice

The first public-resize slice is now landed:

- new host-facing contract:
  `session_runtime.resizeWithCellSize(...)`
- transport/runtime owner:
  [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)
- semantic resize owner remains:
  [TerminalCore.resizeLocked(...)](/home/home/personal/zide/src/terminal/core/terminal_core.zig)

What this unifies:

- host-supplied rows/cols
- host-supplied cell width/height
- semantic resize application
- transport resize reporting
- in-band resize notification payload

What it does not change:

- runtime shell still owns locking
- runtime shell still owns PTY/external transport resize
- runtime shell still owns in-band reporting
- `TerminalCore` still owns the resize semantics

That is the right ownership line.

## Updated Public Story

From the live code baseline after this slice:

- hosts no longer need to teach resize as two separate public steps
- FFI and native host paths now share one resize contract shape
- the runtime shell now looks more like a transport/reporting shell around a
  single semantic resize operation

## Regression Authority

The new regression test proves the public contract now uses the configured cell
metrics for in-band resize reporting:

- [pty_terminal_runtime_tests.zig](/home/home/personal/zide/src/terminal/core/pty_terminal_runtime_tests.zig)
  `\"resizeWithCellSize uses current cell metrics for in-band resize report\"`

## Current Judgment

This is a real plug-and-play improvement because it makes the public resize
story less shell-first and less path-dependent.

It does not finish the wider `TerminalCore` sufficiency question.
It does remove one concrete parity gap without dragging transport mechanics
into core.

## Next Question

After this resize slice, the next VT question should be reranked again between:

- broader `TerminalCore` sufficiency
- viewport/selection mutation surface
- or a clean stop-marker if no new crisp contradiction is stronger
