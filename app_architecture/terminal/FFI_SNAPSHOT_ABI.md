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

Shared semantic authority now lives in:
- `app_architecture/terminal/RENDER_PUBLICATION_CONTRACT.md`

Snapshot `generation` remains publication truth only. It is intentionally kept
separate from host acknowledgement/presentation semantics.

Update:
- the first host-facing acknowledgement slice is now landed as explicit bridge
  calls:
  - `zide_terminal_present_ack(handle, generation)`
  - `zide_terminal_acknowledged_generation(handle, &generation)`
- the bridge now also exposes `zide_terminal_published_generation(handle, &generation)`
  so hosts can compare published vs acknowledged generation without forcing a
  snapshot acquire
- `zide_terminal_redraw_state(handle, &state)` so hosts can acquire both
  generations plus `needs_redraw` atomically in one cheap getter
- `zide_terminal_redraw_state_abi_version()` so redraw-state ABI validation
  follows the same query pattern as snapshot/event/scrollback/metadata surfaces
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
  (`zide_terminal_metadata_acquire`, `zide_terminal_scrollback_acquire`, `zide_terminal_scrollback_release`)
  so snapshot ABI remains viewport-only while hosts can consume history through a separate ownership contract.
- this structured history path is the authoritative history surface; the text
  exports (`selection_text`, `scrollback_plain_text`, `scrollback_ansi_text`)
  are convenience views for copied text, not replacements for structured
  history state
- those copied text buffers now also carry inline `abi_version` /
  `struct_size`, matching the stronger ABI discipline used by the other
  exported output surfaces
- likewise, `selection_text` is a copied-text convenience export because
  milestone 1 does not yet ship structured selection geometry/ranges as an
  authoritative bridge surface

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
2. query `zide_terminal_redraw_state(...)` and require `needs_redraw == 1`
3. acquire snapshot
4. verify `abi_version` and `struct_size`
5. render or inspect all rows
6. optionally use damage as a redraw hint
7. acknowledge the published generation with `zide_terminal_present_ack(...)`
8. verify redraw state cools off
9. release snapshot

If the host also needs lifecycle/title/cwd/scrollback latest-state truth, it
should use `zide_terminal_metadata_acquire(...)` instead of reconstructing that
state from multiple narrow getters alongside the snapshot.

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
