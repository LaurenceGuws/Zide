# VT Host Activity Split

Date: 2026-04-03

## Purpose

Land the second real host-contract normalization slice.

The exact weakness was:

- `metadataAcquire(...)` still re-bundled terminal truth, runtime status, and
  semantic activity into one mixed ABI story
- the first internal metadata split was not enough while the public edge still
  taught that same mixed category

## Split

The public host edge is now clearer:

### Terminal metadata acquire

- `zide_terminal_metadata_acquire(...)`
- `ZideTerminalMetadata`

Carries terminal truth only:

- scrollback count
- scrollback offset
- title
- cwd

### Runtime status

Still lives on the cheap runtime getters:

- `zide_terminal_is_alive(...)`
- `zide_terminal_child_exit_status(...)`

### Activity acquire

- `zide_terminal_activity_acquire(...)`
- `ZideTerminalActivity`

Carries semantic activity only:

- foreground process presence
- semantic prompt/input/output state
- semantic prompt kind / exit-code-known / exit code
- optional foreground-process label

## Why This Matters

This is not just helper cleanup.

It changes the public contract story:

- terminal truth is not "metadata plus some runtime plus some activity"
- runtime state is not hidden inside metadata
- semantic activity is not smuggled through a terminal metadata call

That is the right kind of maturity gain against Ghostty/WezTerm pressure:

- fewer mixed public categories
- more deliberate host-facing nouns
- less historical accumulation at the ABI edge

## Live Surfaces Updated

- `src/terminal/ffi/shared.zig`
- `src/terminal/ffi/bridge.zig`
- `src/terminal/ffi/c_api.zig`
- `src/terminal/ffi/core_api.zig`
- `src/terminal_ffi_exports.zig`

## Current Judgment

This is a real host-contract normalization win:

- `metadataAcquire(...)` is now terminal-only
- activity gets its own honest acquire/release surface
- runtime remains on explicit runtime queries

The next host-contract question is no longer "metadata is mixed."

It is whether any remaining host-facing ABI surface still teaches two stories
for the same category.
