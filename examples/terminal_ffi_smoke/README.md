# Terminal FFI Smoke

Purpose: minimal non-Zide consumer for the terminal FFI bridge.

This host is intentionally small and disposable. It exists to prove the bridge contract:
- shared library loading
- opaque handle lifecycle
- resize through the foreign API
- snapshot acquire/release ownership
- event drain/free ownership

## Why Python

The first smoke host should be Python `ctypes`, not C:
- less setup friction
- easier to inspect flat structs and ownership mistakes
- easier to iterate before ABI details settle

If the bridge is painful to bind from Python, the ABI is probably too clever.

## Current flow

1. load the terminal bridge shared library
2. create a terminal session
3. resize it through the bridge
4. acquire a snapshot
5. verify dimensions, cell count, title/cwd pointers, and initial row data
6. query renderer metadata for representative glyphs (box/rounded, braille/graph, powerline) and validate damage-policy flags
7. acquire a scrollback window and verify copied row content
8. drain events and verify ownership/release paths
9. destroy the session

This is intentionally a no-PTY smoke today.

Reason:
- it proves the FFI contract directly
- it avoids conflating bridge-shape validation with the still-open embedded PTY hosting path

The PTY-backed smoke remains a follow-on once the bridge-owned shell path is stabilized for foreign hosts.

## Run

1. `zig build build-terminal-ffi`
2. `python3 examples/terminal_ffi_smoke/main.py --lib zig-out/lib/libzide-terminal-ffi.so`

Mock external-host scenario:
1. `zig build build-terminal-ffi`
2. `python3 examples/terminal_ffi_smoke/main.py --scenario mock-service --lib zig-out/lib/libzide-terminal-ffi.so`

ABI-shape regression scenario:
1. `zig build build-terminal-ffi`
2. `python3 examples/terminal_ffi_smoke/main.py --scenario abi-mismatch --lib zig-out/lib/libzide-terminal-ffi.so`

Shared Python host boot helpers:
- `examples/common/ffi_host_boot.py`

Host migration checklist:
- poll terminal-side output/publication before editor-side work when a host owns both surfaces
- release owned buffers in reverse order of acquisition
- keep terminal snapshot/scrollback/event lifetimes scoped to one host pump tick
- treat no-PTY feed loops as first-class, not just fallback smokes

Installed bridge artifacts:
- `zig-out/lib/libzide-terminal-ffi.so`
- `zig-out/include/zide_terminal_ffi.h`

## PTY-backed variant

The PTY-backed foreign-host smoke is kept separate from the Python `ctypes` host:

1. `zig build test-terminal-ffi-pty`

Behavior:
- starts `/bin/sh` on Unix-like systems
- sends a small command over the bridge
- polls until output appears or the child exits
- checks for a child-exit event separately from the base no-PTY ownership smoke

This path is intentionally separate so PTY-hosting issues do not blur the baseline Python FFI contract.

## Mock Service Scenario

The Python smoke host also includes a `mock-service` scenario that simulates an
external non-PTY byte source feeding the terminal through FFI in chunks.

It verifies:
- incremental output feeding from a host-owned service loop
- title/cwd updates
- clipboard-write events
- final snapshot content
- scrollback content after streamed line output

This is meant to model the first embedded/mobile/Flutter-style host shape more
closely than the baseline one-shot smoke.
