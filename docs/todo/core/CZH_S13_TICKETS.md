# `CZH-S13` Tickets — long-loop FFI/surface consolidation pack

Sprint: `CZH-S13`  
Authority parent: accepted composite widget seam pack (`CZH-B17`)  
Super-gate: `CZH-GATE-72`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- No behavior changes in this sprint.
- No host ABI changes in this sprint.
- No early architect bounce: continue through `CZH-680` unless a real hard
  blocker appears.

## Ticket list

### `CZH-671` Audit FFI/surface seam + scoped hygiene targets

- **Goal:** freeze one longer-cut plan (FFI seam consolidation + hygiene sweep)
  before code edits.
- **Targets:** `src/terminal/ffi/core_api.zig`,
  `src/terminal/surface_contract.zig`,
  `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`.
- **Done when:** `implementation.md` records selected seam cuts and hygiene
  scope.

### `CZH-672` Add bounded FFI redraw-state helper wrappers

- **Goal:** extend `surface_contract.zig` with helper wrapper(s) that explicitly
  name redraw-state ownership used by FFI call sites.
- **Constraint:** helper-only and behavior-neutral.
- **Done when:** helper(s) compile and docs are concise.

### `CZH-673` Route core_api redraw call site(s) through wrappers

- **Goal:** wire `core_api` redraw-state predicate/fill sites through the new
  helper wrapper(s).
- **Constraint:** no ABI or behavior change.
- **Done when:** wiring is behavior-equivalent.

### `CZH-674` Add bounded present-ack helper wrapper(s)

- **Goal:** extend `surface_contract.zig` with explicit helper wrapper(s) for
  present-ack admissibility semantics at FFI boundary.
- **Constraint:** helper-only and behavior-neutral.
- **Done when:** helper(s) compile with ownership docs.

### `CZH-675` Route core_api present-ack call site(s) through wrappers

- **Goal:** wire `core_api` present-ack admissibility call site(s) through new
  wrapper(s).
- **Constraint:** no ABI or behavior change.
- **Done when:** wiring is behavior-equivalent.

### `CZH-676` Tighten seam docs at code boundary

- **Goal:** align module/function docs in touched Zig files to final ownership
  truth after `CZH-672`..`CZH-675`.
- **Done when:** no stale or duplicative wording remains.

### `CZH-677` Add focused FFI seam invariants tests (part 1)

- **Goal:** add unit tests for redraw/present-ack wrapper equivalence in
  `surface_contract.zig`.
- **Done when:** tests lock behavior against prior primitives.

### `CZH-678` Add focused FFI seam invariants tests (part 2)

- **Goal:** add/adjust target tests for `core_api` seam integration where
  present.
- **Done when:** seam integration assertions compile and pass.

### `CZH-679` Scoped probe/doc hygiene sweep + authority sync

- **Goal:** remove stale investigation-only probe/debug residue in touched files
  and sync `TERMINAL_SURFACE_CONTRACT.md` wording to landed code.
- **Done when:** queue note records removed/kept signals and authority docs are
  landed-only.

### `CZH-680` Validation packet + gate handoff

- Record ladder results in `docs/todo/core/implementation.md`.
- Submit checkpoint packet `docs/todo/core/CZH_S13_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-72`.
