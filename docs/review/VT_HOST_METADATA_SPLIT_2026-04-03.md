# VT Host Metadata Split

Date: 2026-04-03

## Purpose

Land the first real host-contract normalization slice.

The exact weakness was:

- the host edge still taught one mixed "metadata" story
- immutable terminal truth and runtime status were bundled together at the
  query layer

## Split

The query layer is now explicit:

### Terminal metadata

- title
- cwd
- scrollback count
- scrollback offset

Owned by:

- `host_queries.copyTerminalMetadata(...)`

### Runtime metadata

- alive
- exit code

Owned by:

- `host_queries.currentRuntimeMetadata(...)`

### Activity metadata

Still explicit and separate:

- foreground process
- semantic prompt activity
- progress

Owned by:

- `host_queries.currentActivityMetadata(...)`

## Why This Matters

This does not shrink the public ABI yet.

It does something more important first:

- the internal host contract no longer pretends terminal truth and runtime
  status are one category

That makes the FFI metadata assembly read more deliberately and prepares later
public normalization without guessing.

## Live Callers Updated

- `src/terminal/ffi/core_api.zig`
- `src/terminal/ffi/host_api.zig`
- `src/terminal/core/workspace_host.zig`
- `src/terminal/core/pty_terminal_runtime_tests.zig`

## Current Judgment

This is the right first normalization slice:

- no ABI churn theater
- no capability loss
- clearer category line at the host edge
