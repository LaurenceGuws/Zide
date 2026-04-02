# Terminal War 3 Session Object Review 2026-04-02

## Purpose

Identify the next concrete War 3 contradiction now that publication and
runtime-shell roots are materially flatter.

## Current Read

The remaining problem is no longer concentrated in
[session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
or
[terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
as API roots.

It is concentrated in the aggregate session object itself:

- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
  still exposes `PtyTerminalRuntime` as the visible session/library root
- `PtyTerminalRuntime` still physically owns the full cross-domain storage:
  - runtime fields
  - core
  - interaction fields
  - publication fields
  - control fields

That means the live stack still reads like:

- one broad aggregate session object
- plus several narrower helper/owner modules around it

instead of the cleaner War 3 target shape:

- one unmistakable engine/library center
- one runtime shell
- one export boundary

## Why This Matters

Ghostty and WezTerm pressure is no longer mainly about whether our helper files
are narrow enough.

It is about whether a strong terminal maintainer can open the live stack and
immediately see:

- which object is the library
- which object is the host shell around it
- which object is the export edge

`PtyTerminalRuntime` still blurs that answer.

## Best Next Question

What is the single largest contradiction inside the current aggregate session
shape?

Current candidates:

1. `PtyTerminalRuntime` physically storing both engine and non-engine domains
2. `TerminalCore` being real but not visibly the owning center of the library
3. the flat session field bundles making "the terminal session" read as the
   primary reality instead of the engine

## Bottom Line

The next likely War 3 battlefield is the aggregate session object model.

Do not reopen runtime/publication micro-cuts by momentum unless a fresh whole
slab contradiction appears there first.
