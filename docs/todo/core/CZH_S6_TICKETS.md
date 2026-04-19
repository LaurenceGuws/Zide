# `CZH-S6` Tickets — remove residual FFI debug test hook

Sprint: `CZH-S6`  
Authority parent: accepted FFI/export doc-alignment sprint (`CZH-B10`)  
Super-gate: `CZH-GATE-65`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No file moves or compatibility shims in this sprint.

## Ticket list

### `CZH-631` Audit destroy debug-hook usage and replacement plan

- **Goal:** record every read/write path for `destroy_debug_pause_ms_for_tests`
  and define the test-owned replacement seam.
- **Minimum targets:** `src/terminal/ffi/core_api.zig`,
  `tests/terminal_ffi_smoke_tests.zig`, queue references in
  `docs/todo/core/implementation.md`.
- **Done when:** a bounded replacement plan is captured in `implementation.md`
  with no ambiguity about `CZH-632`/`CZH-633`.

### `CZH-632` Remove product-global debug hook from `core_api.zig`

- **Goal:** eliminate `destroy_debug_pause_ms_for_tests` from product FFI code.
- **Constraint:** production destroy behavior must remain unchanged.
- **Done when:** `core_api.zig` has no debug pause global and no test-hook sleep
  logic.

### `CZH-633` Re-home test behavior to test-owned seam

- **Goal:** keep equivalent test control/coverage without product debug globals.
- **Scope:** test code and test-owned helper seams only.
- **Done when:** `tests/terminal_ffi_smoke_tests.zig` no longer references the
  removed global and passes with equivalent intent.

### `CZH-634` Sync queue/authority docs to post-removal truth

- **Goal:** remove stale references to the debug hook and align ownership notes.
- **Files:** at minimum `docs/todo/core/implementation.md`; update
  entrypoint/handoff wording only if needed by changed test seam language.
- **Done when:** no active queue row claims the removed hook still exists.

### `CZH-635` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S6_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-65`.
