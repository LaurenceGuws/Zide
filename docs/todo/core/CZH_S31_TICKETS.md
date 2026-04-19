# `CZH-S31` Tickets — runtime startup correctness and source-comment hygiene

Sprint: `CZH-S31`  
Authority parent: `CZH-B35` changes required at `CZH-GATE-89`  
Super-gate: `CZH-GATE-90`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze by default; the startup assertion failure is a scoped
  correctness fix.
- No host ABI/C export changes in this sprint.
- Current FFI/caller shape is not frozen. Move callers or state ownership if the
  mature split requires it.
- Source comments must describe current ownership, invariants, and constraints.
  Do not leave ticket IDs, sprint names, or progress history in product source.
- Windows/macOS validation is non-blocking unless their platform-owned code is
  touched.
- Connected Android device: `RF8M74JDWEK`.

## Ticket list

### `CZH-851` Runtime blocker audit + scope lock
- Map the actual initialization order for `terminal_presentable_pipeline_ready`,
  `host_surface_target_available`, and `shared_surface_attachment_ready`.
- Record exact edit targets and source-comment cleanup scope.

### `CZH-852` Fix presentation leg initialization contract
- Repair the startup assertion failure by aligning assertions/state ownership
  with real runtime order.
- Keep the fix single-path; no fallback or compatibility path.

### `CZH-853` Runtime fold/read path follow-through
- Audit the caller path from refresh through result fold after the fix.
- Remove any redundant derivation introduced by the correction.

### `CZH-854` Source-comment cleanup in touched runtime files
- Remove ticket/sprint/progress history from touched product source comments.
- Keep concise present-tense ownership/invariant comments only.

### `CZH-855` Linux startup smoke
- Run the normal build ladder subset needed before runtime smoke.
- Run a bounded terminal GUI startup smoke: launch, verify it passes the prior
  assertion point, then terminate so no GUI process is left open.

### `CZH-856` Android device validation
- Confirm `adb devices` sees `RF8M74JDWEK`.
- Run Android compile/deploy/start/logcat smoke for the touched shared paths.

### `CZH-857` Helper-level invariants
- Add or adjust helper-level tests that lock the corrected initialization/order
  contract.

### `CZH-858` Integration invariants
- Add or adjust integration tests that cover the corrected startup/read/fold
  behavior without depending on platform GUI lifetime.

### `CZH-859` Scoped probe/doc hygiene + authority sync
- Confirm no stale probe/debug residue remains in touched product paths.
- Sync `TERMINAL_SURFACE_CONTRACT.md` / native host authority only where the fix
  changes wording.

### `CZH-860` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S31_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-90`.
