# VT Core Protocol Owner Rerank

Date: 2026-04-03

## Purpose

Rerank the `terminal_core_protocol.zig` front after the three whole slabs that
were worth taking:

- edit/erase semantics
- scroll/newline/reverse-index semantics
- DECRQSS state/query assembly

The question is:

- does this file still read like a parallel semantic center?

## Current Judgment

No. Not in the old damaging way.

`src/terminal/core/protocol/terminal_core_protocol.zig` is now close to a real
stop-marker.

## What It Still Owns

What remains is much narrower:

- scroll-region helper forwarding
- palette lookup
- cursor/tab convenience forwarding
- hyperlink append forwarding
- kitty-image clearing forwarding
- cell/cursor read helpers

Those are not all beautiful, but they no longer add up to one false center.

## Why This Front Should Stop

Continuing here now would mostly mean:

- tiny forwarding cleanup
- local aesthetic tidying
- "one more helper" momentum

That is exactly the kind of faux progress this campaign is trying to avoid.

The meaningful semantic gravity has already been removed.

## What This Means For VT Scrutiny

The important result is not that `terminal_core_protocol.zig` became tiny.

The important result is:

- `TerminalCore` now owns far more of the behavior that a strong maintainer
  expects the terminal object to own
- the helper file no longer competes with it as a live semantic center

That is the real maturity gain.

## Decision

Park the `terminal_core_protocol.zig` owner front.

Return to the broader `TerminalCore` sufficiency ranking from this stronger
baseline.
