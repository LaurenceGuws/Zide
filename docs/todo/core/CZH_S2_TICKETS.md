# `CZH-S2` Tickets — first post-freeze implementation sprint

Sprint: `CZH-S2`  
Authority parent: `CZH-B6` freeze + audits `CZH-606`..`CZH-608`  
Super-gate (future): `CZH-GATE-61` (not opened until Architect accepts `CZH-GATE-60`)

## Execution rules (when started)

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior changes only where a ticket explicitly scopes them and validation is
  recorded.

## Ticket list (concrete)

### `CZH-611` Remove product-path test sleep from `terminal/ffi/core_api` destroy

- **Source audit:** `CZH-606` removal queue.
- **Goal:** `destroy_debug_pause_ms_for_tests` must not sleep in non-test builds;
  relocate to test-only harness or `builtin.is_test` gated path.
- **Validation:** full stress ladder + targeted FFI/session tests if any touch
  destroy teardown.

### `CZH-612` Add module `//!` doc headers to FFI/export files

- **Source audit:** `CZH-608` doc-alignment queue (files missing `//!`).
- **Files:** `shared.zig`, `core_api.zig`, `host_api.zig`, `bridge.zig`, `c_api.zig`
  (terminal), `terminal_ffi_exports.zig`, `editor/ffi/bridge.zig`,
  `editor/ffi/c_api.zig`.
- **Goal:** each file states ownership and its role in the four-layer split.

### `CZH-613` Document exported host entrypoints (`///` on key `pub fn`)

- **Source audit:** `CZH-608` function drift list.
- **Scope:** minimum: `core_api`/`host_api` exports foreign hosts call (create,
  destroy, start, poll, snapshot/diff acquire/release, redraw helpers).
- **Goal:** docs match responsibility; call out BYO-PTY vs publication-only
  paths.

### `CZH-614` Rename snapshot-diff “fallback” identifiers (optional hygiene)

- **Source audit:** `CZH-607` naming note.
- **Goal:** rename locals/flags only — **no semantic change**; replay/tests
  green.

### `CZH-615` Sprint validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Prepare Architect review for `CZH-GATE-61`.
