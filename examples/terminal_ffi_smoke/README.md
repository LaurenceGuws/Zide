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
4. resolve one terminal publication cycle through the shared Python host helper
5. verify dimensions, cell count, title/cwd pointers, and initial row data
6. query renderer metadata for representative glyphs (box/rounded, braille/graph, powerline) and validate damage-policy flags
7. query close-confirm signals and validate the host-facing close-warning getter shape
8. acquire a scrollback window and verify copied row content
9. drain events and verify ownership/release paths
10. destroy the session

The shared publication helper performs the authoritative redraw/present steps:
- query `zide_terminal_redraw_state(...)`
- acquire/release the snapshot
- acknowledge the published generation with `present_ack(...)`
- verify redraw state cools off after acknowledgement

Hosts can also drive the backend-owned viewport directly:
- `zide_terminal_set_scrollback_offset(handle, rows)`
- `zide_terminal_follow_live_bottom(handle)`

Those calls change the authoritative visible viewport used by
`snapshot_acquire(...)` and reflected by `metadata_acquire(...)`.

This keeps the dedicated terminal smoke aligned with the mixed terminal+editor host path.
The baseline smoke now also uses `metadata_acquire(...)` as its single
lifecycle/title/cwd summary instead of reconstructing that state from multiple
focused getters.

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
  - `consume_terminal_publication_once(...)` is the shared terminal publication primitive for both dedicated and mixed hosts
  - `consume_terminal_metadata_once(...)` is the shared terminal latest-state metadata primitive for both dedicated and mixed hosts
  - `consume_terminal_events_once(...)` is the shared terminal event ownership primitive for Python hosts

Host migration checklist:
- poll terminal-side output/publication before editor-side work when a host owns both surfaces
- release owned buffers in reverse order of acquisition
- keep terminal snapshot/scrollback/event lifetimes scoped to one host pump tick
- treat no-PTY feed loops as first-class, not just fallback smokes
- treat `redraw_ready` as a wake hint only
- use `zide_terminal_redraw_state(...)` as the cheap redraw-truth getter
- use snapshot generation/damage only after redraw-state says newer content is
  actually pending for the host

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
- requires `redraw_ready` on PTY-driven visible updates
- resolves the same redraw-state -> snapshot -> `present_ack(...)` cycle as the dedicated and mixed host smokes
- validates the same close-confirm latest-state getter shape that foreign hosts would use before destructive close actions
- checks for a child-exit event separately from the base no-PTY ownership smoke

This path is intentionally separate so PTY-hosting issues do not blur the baseline Python FFI contract.

## Mock Service Scenario

The Python smoke host also includes a `mock-service` scenario that simulates an
external non-PTY byte source feeding the terminal through FFI in chunks.

It verifies:
- incremental output feeding from a host-owned service loop
- redraw-ready wake events for streamed output
- the same shared publication helper used by the baseline and combo hosts
- the same shared metadata/event ownership helpers used by the Python host path
- title/cwd updates
- clipboard-write events
- explicit external-input close through `close_input`
- `alive_changed` event delivery after close
- final snapshot content
- scrollback content after streamed line output

This is meant to model the first embedded/mobile/Flutter-style host shape more
closely than the baseline one-shot smoke.
