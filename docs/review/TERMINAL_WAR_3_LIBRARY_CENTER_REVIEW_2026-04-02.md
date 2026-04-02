# Terminal War 3 Library Center Review 2026-04-02

## Purpose

Identify the single strongest remaining obstacle to reading the live terminal
stack as a serious `zide-vt` extraction target.

This review uses:

- Ghostty as the nearest Zig-relative library-boundary comparison
- WezTerm as the mature stack-discipline bar

## Inputs Reviewed

Live Zide authority:

- [VT_CORE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)
- [TERMINAL_ARCHITECTURE_COMPARISON.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md)
- [BRIDGE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/ffi/BRIDGE_DESIGN.md)
- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)

Reference pressure:

- [ghostty `vt.h`](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
- [ghostty `Termio.zig`](/home/home/personal/zide/dev_references/terminals/ghostty/src/termio/Termio.zig)
- WezTerm repo shape as the mature stack discipline reference

## Current Read

Zide is no longer weak on host-facing contract volume.

The FFI bridge already proves that.

The remaining weakness is simpler and more serious:

- the live stack still does not read like one unmistakable engine/library
  center plus one runtime shell around it

Ghostty still wins that comparison at first glance:

- `Terminal` reads like the engine
- `Termio` reads like runtime/transport shell around it
- the public VT umbrella stays intentionally narrow

Zide is closer than before, but the current live shape still reads more like:

- real engine center
- plus one still-important publication/export center
- plus one still-important runtime shell
- plus the native host path around them

That is better than before, but it is not yet the cleanest possible library
story.

## Strongest Remaining Obstacle

The strongest remaining obstacle is:

- `TerminalCore` is real, but it is still not the one indisputable center that
  the rest of the stack visibly orbits

More concretely:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  is real engine state and behavior
- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  is now much narrower, but still reads like important terminal ownership
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
  is much smaller, but still reads like a parallel center rather than a
  boring export edge

That three-way weight is the current blocker to a serious `zide-vt` first
glance.

## What This Means

War 3 should not start with:

- more widget cleanup
- more parser cleanup
- more host aggregation cleanup

War 3 should start by fixing the target shape in explicit terms:

- `TerminalCore` is the library center
- `session/runtime.zig` is runtime shell only
- `terminal_publication.zig` is export boundary only

Then the first code cut should be chosen by one rule:

- identify the single largest current contradiction to that target shape
- delete it in one whole-slab move

## Best Next Question

If a strong terminal maintainer opened the live stack, what would still stop
them from immediately saying:

- "`TerminalCore` is the library"
- "`session/runtime.zig` is just the runtime shell"
- "`terminal_publication.zig` is just the export boundary"

That is the next War 3 target question.

The wrong next move would be:

- cautiously shaving those files because they still feel too large

The right next move is:

- pick the biggest lie relative to the target shape
- remove that lie directly

## Bottom Line

The first War 3 enemy is not a bug and not another micro-lane.

It is the remaining three-way center-of-gravity split between:

- engine
- runtime shell
- publication/export shell
