# `CZH-S5` Tickets — FFI/export doc-alignment closure

Sprint: `CZH-S5`  
Authority parent: accepted BYO-PTY extraction sprint (`CZH-B9`)  
Super-gate: `CZH-GATE-64`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No file moves or compatibility shims in this sprint.

## Ticket list

### `CZH-626` Audit remaining FFI/export doc drift

- **Goal:** record the exact remaining drift between code, queue audits, and
  authority docs after `CZH-B7`..`CZH-B9`.
- **Minimum targets:** `src/editor/ffi/bridge.zig`, `src/editor/ffi/c_api.zig`,
  `src/terminal/ffi/core_api.zig`, `src/terminal/ffi/bridge.zig`,
  `src/terminal_ffi_exports.zig`, and the stale `CZH-608` table rows in
  `implementation.md`.
- **Done when:** `implementation.md` contains a bounded audit list and there is
  no ambiguity about what `CZH-627`/`CZH-628` must fix.

### `CZH-627` Fix remaining module-doc drift

- **Goal:** make module `//!` state truthful everywhere in the audited target
  set.
- **Constraint:** only module docs / nearby comments; no logic changes.
- **Done when:** every audited file that should carry a module doc has one, and
  stale queue claims about missing module docs are ready to be removed.

### `CZH-628` Fix remaining important entrypoint doc drift

- **Goal:** add concise `///` ownership docs where still missing on important
  FFI/editor-FFI/export entrypoints.
- **Constraint:** no semantic changes, no broad doc spam.
- **Done when:** the important entrypoints identified in `CZH-626` are covered
  and the docs match actual ownership.

### `CZH-629` Sync queue and authority notes to current truth

- **Goal:** remove stale audit-table drift and align queue/authority wording
  with the current code state.
- **Files:** at minimum `docs/todo/core/implementation.md`; update authority
  docs only if `CZH-626` identifies a real contradiction.
- **Done when:** queue and authority docs no longer lag accepted code state.

### `CZH-630` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S5_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-64`.
