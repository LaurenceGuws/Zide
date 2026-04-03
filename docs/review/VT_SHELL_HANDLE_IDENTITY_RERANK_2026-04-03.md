# VT Shell Handle Identity Rerank

Date: 2026-04-03

## Purpose

Recheck the host-edge identity pressure after the constructor story and FFI
handle internals were both tightened.

## What Changed

The FFI boundary still exports one opaque terminal handle:

- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
  exports `ZideTerminalHandle`
- [bridge.zig](/home/home/personal/zide/src/terminal/ffi/bridge.zig)
  and [c_api.zig](/home/home/personal/zide/src/terminal/ffi/c_api.zig)
  keep terminal-centered public nouns

But the internal FFI story is now less misleading too:

- the internal handle now stores `shell: *TerminalRuntimeShell`
  rather than `session: *TerminalRuntimeShell`
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
  constructs a shell through the VT root constructor path and names it as a
  shell internally
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
  now routes through `h.shell`, which makes the boundary explicit

## Current Judgment

This weakens the host-edge identity suspicion again.

Why:

- the public ABI remains terminal-named and opaque
- the constructor story no longer teaches shell self-construction
- the FFI internals no longer pretend the shell is a generic terminal session

That means the remaining host-edge identity pressure is now narrower:

- the host still necessarily reaches terminal behavior through a shell-backed
  handle
- but that now reads more like honest runtime storage than like a mistaken
  public object model

## Decision

Host-edge identity remains worth watching under completion items 5 and 8, but
it is no longer the strongest live shell contradiction from this baseline.

The stronger remaining shell-hostile front is now likely:

- lock choreography

unless a deeper `TerminalCore` sufficiency gap overtakes shell pressure again.

## Bottom Line

After constructor and handle cleanup, the shell no longer wins as the default
identity problem.
