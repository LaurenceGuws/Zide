# Terminal War 3 Core Center Review 2026-04-02

## Purpose

Decide whether a deeper War 3 move is still required after the publication,
runtime, session-object, and public-identity waves.

## Inputs Reviewed

Live Zide:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
- [TERMINAL_ARCHITECTURE_COMPARISON.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md)
- [VT_CORE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)

Reference pressure:

- [Ghostty Terminal.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/terminal/Terminal.zig)
- [Ghostty Termio.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/termio/Termio.zig)
- [libghostty-vt vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
- [WezTerm terminal.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)

## Current Read

War 3 already killed the obvious contradictions:

- publication no longer reads like a competing center
- runtime no longer reads like a competing center
- the aggregate session object is grouped and cleaner
- the public root now exports `TerminalSession` directly

That leaves one narrower but more important question:

- is `TerminalCore` already strong enough as the indisputable library center?

## What The References Still Do Better

Ghostty and WezTerm still share one first-glance advantage:

- the engine object itself reads like the complete terminal reality
- runtime/transport sits around it
- the public mental model starts with the engine object, not the wrapper

Zide is much closer now, but it still reads more like:

- `TerminalSession` owns `TerminalCore`
- `TerminalCore` is the dominant field inside the session

instead of:

- `TerminalCore` is plainly the library
- `TerminalSession` is plainly a host/runtime shell around it

## Why This Is Harder Than The Earlier Cuts

The remaining gap is not a helper file or a misplaced slab.

It is an object-model question:

- should `TerminalCore` stay a rich field inside `TerminalSession`
- or should a deeper redesign make `TerminalCore` more visibly sufficient as
  the library object in its own right?

Right now that answer is not obvious enough to justify a blind code cut.

## Current Judgment

This is now too ambiguous for momentum-driven surgery.

The live stack is already much stronger.

If War 3 continues, it should continue only after a deliberate design decision
about whether `TerminalCore` needs a stronger owning role than "primary field of
TerminalSession".

## Bottom Line

War 3 is near a real stop-marker.

The next honest move is:

1. either declare the current library-center shape good enough for this war,
2. or open a deliberate deeper design step for `TerminalCore` vs
   `TerminalSession`,

but not to keep cutting locally by inertia.
