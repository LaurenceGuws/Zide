# Terminal FFI Snapshot ABI

Date: 2026-02-27

Purpose: define the first exported terminal snapshot contract for foreign hosts.

Status: milestone-1 baseline. This document describes the snapshot shape currently implemented by `src/terminal/ffi/bridge.zig`.

## Goals

- Give foreign hosts a simple, explicit, render-friendly snapshot.
- Keep ownership rules obvious.
- Avoid hidden borrows across FFI boundaries.
- Prefer correctness and debuggability over zero-copy cleverness.

## Milestone 1 decision

Milestone 1 uses copied full snapshots.

That means:
- snapshot acquisition allocates bridge-owned memory
- cell data is copied out of the internal terminal snapshot
- title and cwd strings are copied into bridge-owned memory
- the host must call `zide_terminal_snapshot_release()` exactly once per acquired snapshot

This is slower than a zero-copy design, but it is much safer for the first bridge.

## Exported types

Current exported snapshot surface lives in:
- `src/terminal/ffi/bridge.zig`
- `src/terminal/ffi/c_api.zig`

Primary structs:
- `ZideTerminalCell`
- `ZideTerminalSnapshot`

Snapshot header:
- `abi_version`
- `struct_size`

Current header values:
- `abi_version = 1`
- `struct_size = sizeof(ZideTerminalSnapshot)` for the library that produced it

Current scalar version query:
- `zide_terminal_snapshot_abi_version() -> 1`

Related renderer metadata helper:
- `zide_terminal_renderer_metadata_abi_version() -> 1`
- `zide_terminal_renderer_metadata(codepoint, &metadata)`

### `ZideTerminalCell`

Fields:
- codepoint
- combining_len
- width
- height
- x
- y
- combining_0
- combining_1
- fg
- bg
- underline_color
- bold
- blink
- blink_fast
- reverse
- underline
- link_id

Notes:
- this is intentionally flat and value-based
- it mirrors the internal cell model closely enough for host rendering or inspection
- it does not expose internal pointers

### `ZideTerminalSnapshot`

Fields:
- abi_version
- struct_size
- rows
- cols
- generation
- cell_count
- cells
- cursor_row
- cursor_col
- cursor_visible
- cursor_shape
- cursor_blink
- alt_active
- screen_reverse
- has_damage
- damage_start_row
- damage_end_row
- damage_start_col
- damage_end_col
- title_ptr/title_len
- cwd_ptr/cwd_len
- internal context pointer used only by release

Notes:
- hosts must validate `abi_version` before assuming the rest of the layout
- `struct_size` allows future append-only expansion without guessing which build produced the snapshot
- `cells` points to a flat array of `rows * cols` cells
- row-major order
- `title_ptr` and `cwd_ptr` are optional and may be null when len is zero
- `_ctx` is opaque release bookkeeping and not host data

## Ownership contract

Acquisition:
- host calls `zide_terminal_snapshot_acquire(handle, &snapshot)`
- on success, the bridge owns all pointed-to memory until release
- the returned header identifies the snapshot layout that was filled

Release:
- host must call `zide_terminal_snapshot_release(&snapshot)`
- after release, all pointers inside the snapshot are invalid
- release zeroes the snapshot struct as a defensive measure

Invalid usage:
- retaining `cells`, `title_ptr`, or `cwd_ptr` after release
- mutating bridge-owned memory
- calling release twice on the same live snapshot without reacquiring

## Why copied snapshots were chosen first

The internal terminal snapshot is currently a borrowed-slice contract:
- valid for internal immediate use
- not suitable as-is for foreign callers

A copy-based export avoids these risks:
- host reads from stale internal memory after poll
- host retains pointers across backend mutation
- implicit allocator ownership leaks into the foreign API

This is the right tradeoff for the first host boundary.

## Damage semantics

Milestone 1 exports coarse damage metadata only:
- `has_damage`
- row/col bounds

Important:
- damage metadata is advisory
- the host must treat the full snapshot as authoritative
- hosts may ignore damage and redraw from the full cell buffer

Current known contract gap:
- snapshot `generation` is publication truth only
- it is not yet paired with any explicit host-facing presented/acknowledged
  generation contract
- this is now behind the native renderer path, which already distinguishes
  renderer-owned submission from publication truth

That means milestone-1 FFI hosts currently have:
- full snapshot truth
- advisory damage bounds
- wakeup via `redraw_ready`

But they do not yet have:
- explicit acknowledgement of "host has now presented generation N"
- bridge-visible retirement semantics derived from host presentation

Update:
- the first host-facing acknowledgement slice is now landed as explicit bridge
  calls:
  - `zide_terminal_present_ack(handle, generation)`
  - `zide_terminal_acknowledged_generation(handle, &generation)`
- the bridge now also exposes `zide_terminal_published_generation(handle, &generation)`
  so hosts can compare published vs acknowledged generation without forcing a
  snapshot acquire
- and `zide_terminal_needs_redraw(handle)` so hosts can ask the cheap
  level-triggered question directly instead of deriving it themselves from
  multiple calls
- snapshot ABI itself is unchanged; the acknowledged-generation contract lives
  alongside snapshot acquisition instead of mutating the snapshot struct in
  milestone 1

This keeps the snapshot usable even while damage tracking evolves.

## Deliberate omissions in milestone 1

Not exported yet:
- dirty row arrays
- scrollback row-by-row diff payloads
- selection ranges
- hyperlink URI tables
- kitty image blobs or placement payloads

Reason:
- these are either not yet normalized for FFI or would expand scope beyond the first useful bridge slice

Note:
- explicit copied scrollback export is now provided via the dedicated buffer API
  (`zide_terminal_scrollback_count`, `zide_terminal_scrollback_acquire`, `zide_terminal_scrollback_release`)
  so snapshot ABI remains viewport-only while hosts can consume history through a separate ownership contract.

## Renderer metadata helper (beta-safe extension)

To reduce host-side heuristics without changing snapshot or cell layout, bridge exports
an independent metadata query:
- input: one Unicode codepoint
- output: `ZideTerminalRendererMetadata` with:
  - glyph class flags (`box`, `box_rounded`, `graph`, `braille`, `powerline`, `powerline_rounded`)
  - damage policy flags (`advisory_bounds`, `full_redraw_safe_default`)

This keeps snapshot ABI stable while giving foreign renderers explicit routing hints for
special glyph paths and conservative damage handling.

## Host guidance

Recommended host behavior:
1. call `poll()`
2. acquire snapshot
3. verify `abi_version` and `struct_size`
4. render or inspect all rows
5. optionally use damage as a redraw hint
6. release snapshot

Do not:
- cache raw snapshot pointers between polls
- assume any pointer remains valid after release

## Follow-on work

After the baseline copy-based path is proven, consider:
- diff-oriented row exports
- optional zero-copy pinned snapshot handles
- hyperlink and selection side tables
- kitty image metadata export if a real host needs it

These are extensions, not prerequisites for the first bridge.
