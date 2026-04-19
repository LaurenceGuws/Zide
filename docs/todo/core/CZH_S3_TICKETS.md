# `CZH-S3` Tickets — make BYO-PTY packaging explicit

Sprint: `CZH-S3`  
Authority parent: accepted split freeze (`CZH-B6`) + first implementation sprint (`CZH-B7`)  
Super-gate: `CZH-GATE-62`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes unless a ticket explicitly says so.
- No C ABI churn in this sprint.

## Ticket list

### `CZH-616` Audit code touchpoints for BYO-PTY packaging move

- **Goal:** produce the exact file/import/export list needed to make the
  optional BYO-PTY seam explicit in code packaging.
- **Scope:** `src/terminal/ffi/**`, `src/terminal_ffi_exports.zig`, and directly
  coupled session/runtime owners only.
- **Done when:** `implementation.md` records the concrete touchpoint map and any
  atomic-move requirement.

### `CZH-617` Move or rename the BYO-PTY Zig API module to explicit packaging

- **Goal:** stop `host_api.zig` from reading like generic terminal core FFI.
- **Constraint:** no C ABI change; bridge/export surface remains stable.
- **Allowed outcomes:** file move, file rename, or new explicitly named module
  with direct adoption if that is the cleanest single-path cut.
- **Done when:** code packaging reflects the split, not just the docs.

### `CZH-618` Align bridge/import/export ownership names after packaging cut

- **Goal:** make `bridge.zig`, `c_api.zig`, and any local import names read
  honestly after `CZH-617`.
- **Constraint:** exported symbol names stay stable unless explicitly documented
  and proven unnecessary to preserve.
- **Done when:** local ownership names stop implying “one FFI blob.”

### `CZH-619` Update authority docs for the real packaging state

- **Goal:** sync architecture docs and queue notes to the post-move packaging.
- **Files:** at minimum `TERMINAL_SUBSYSTEM_LAYERS.md`,
  `docs/todo/core/implementation.md`, and any touched handoff references.
- **Done when:** docs describe the new actual packaging, not the old smell.

### `CZH-620` Validation packet + gate handoff

- Record ladder results in `implementation.md`.
- Submit `docs/todo/core/CZH_S3_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-62`.
