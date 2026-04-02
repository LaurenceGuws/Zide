# Terminal War 3 Runtime Contradiction Review 2026-04-02

## Purpose

Choose the next concrete War 3 contradiction now that publication is no longer
the default enemy.

## Current Read

After the recent publication wave, the strongest remaining contradiction to the
target `zide-vt` shape appears to be runtime shell weight.

Target shape remains:

- `TerminalCore` is the library center
- `session/runtime.zig` is runtime shell only
- `terminal_publication.zig` is export boundary only

Current runtime read:

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  is behaviorally narrower than before
- but it still reads like important terminal ownership because it owns:
  - session allocation and full state assembly
  - runtime/publication storage-layout initialization
  - transport/thread lifecycle entrypoint surface
  - launch-shell-path state

That means the current live stack still reads less like:

- engine
- thin runtime shell
- export edge

and more like:

- engine
- still-important runtime owner
- export edge

## Why This Matters

Against Ghostty and WezTerm pressure, the runtime shell should feel boring.

Right now, `session/runtime.zig` still reads too much like the constructor and
storage authority for "the terminal session" rather than a shell wrapped around
an obvious engine-centered object model.

## Best Next Question

Which slab in
[session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
is the biggest contradiction to "runtime shell only"?

Current candidates:

1. `init(...)` owning full session storage-layout assembly
2. lifecycle entrypoint surface still concentrated in one runtime root
3. launch-shell-path state living on runtime instead of a narrower host shell

## Bottom Line

The next likely War 3 battlefield is runtime-shell shape, not publication.

Status note, later on 2026-04-02:

- the first runtime-shell slab is now moved
- session allocation and storage-layout assembly no longer live in
  [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- that whole constructor slab now lives in
  [runtime_init.zig](/home/home/personal/zide/src/terminal/core/session/runtime_init.zig)
- `session/runtime.zig` now reads more like entrypoint forwarding around the
  narrower runtime owners instead of the place where the full session is born

Status note, later on 2026-04-02 again:

- launch-shell-path state no longer lives in
  [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- that slab now lives in
  [launch_shell_path.zig](/home/home/personal/zide/src/terminal/core/session/launch_shell_path.zig)
- bootstrap and workspace host callers now use that owner directly
- runtime is narrower again and less mixed with host bootstrap state
