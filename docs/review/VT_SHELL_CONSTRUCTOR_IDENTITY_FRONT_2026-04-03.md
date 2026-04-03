# VT Shell Constructor Identity Front

Date: 2026-04-03

## Purpose

Take the first direct cut against the shell-first constructor story.

The question is:

- does the host entry path still teach `TerminalRuntimeShell` as the object
  being created, or is the runtime shell now clearly a root-owned runtime
  boundary around the terminal?

## Contradiction

Before this slice, the shell still constructed itself:

- [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  exposed `init(...)` and `initWithOptions(...)`
- public creation paths consumed those shell methods directly:
  - [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  - [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig)
  - [replay_harness.zig](/home/home/personal/zide/src/terminal/replay_harness.zig)
  - runtime/input tests

That still taught a shell-first object story even after the earlier VT cleanup.

## Slice

Creation ownership now lives on the VT root:

- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
  now exposes:
  - `init(...)`
  - `initWithOptions(...)`
- [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  no longer constructs itself

Live callers now enter through the root-owned constructor path instead of
calling `TerminalRuntimeShell.init*` directly.

## Why This Matters

This is not enough to finish the identity front.

It does matter because it changes the first lesson the code teaches:

- the shell is no longer self-instantiating
- construction belongs to the VT runtime root
- the shell now reads more like a runtime boundary object that gets created by
  the VT layer, not the public center that owns its own birth

## What It Does Not Solve Yet

The FFI handle still stores a shell pointer and the create path still returns a
shell-backed opaque handle.

So the remaining identity question is now narrower:

- whether the public edge still makes the shell feel like the real object even
  after constructor ownership moved off the shell type itself

## Current Read

This was the right first constructor/object-identity slice.

The shell survives the cut, but one major shell-first teaching path is gone.

The next honest question is now:

- does the host edge still need a stronger terminal-centered constructor or
  handle story, or is the remaining shell-backed opacity now honest enough?
