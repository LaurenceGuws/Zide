# `CZH-S32` Tickets — VT-core maturity follow-through and caller mobility

Sprint: `CZH-S32`  
Authority parent: accepted `CZH-B36` runtime correction  
Super-gate: `CZH-GATE-91`

## Execution rules

- Execute in order unless a ticket declares a hard dependency.
- One ticket per commit unless marked `atomic-pair`.
- Behavior freeze by default; caller ownership movement is architectural
  reshaping, not feature behavior expansion.
- No host ABI/C export changes in this sprint.
- Current file/caller placement is not frozen: move callers/state ownership when
  that improves the mature split.
- Keep changes single-path; no fallback compatibility branches.
- Source comments in touched product files must remain present-tense ownership,
  invariants, and constraints only.
- Linux + connected Android (`RF8M74JDWEK`) are active validation platforms.
- Windows/macOS are non-blocking unless their platform-owned code is touched.

## Ticket list

### `CZH-861` Maturity audit + movement scope lock
- Map remaining caller-placement constraints that block the intended mature split
  between VT core FFI, BYO-PTY, editor backend FFI, and terminal presentation/runtime.
- Record exact move targets and `CZH-869` hygiene scope.

### `CZH-862` Contract doc tightening for caller mobility (`doc-only`)
- Tighten authority wording so ownership meaning is detached from current file placement.

### `CZH-863` Caller mobility cut A
- Land first concrete caller/state ownership move in selected runtime/presentation scope.

### `CZH-864` Caller mobility cut B
- Land second concrete caller/state ownership move with matching invariants.

### `CZH-865` VT-core boundary follow-through
- Ensure touched call paths preserve VT core vs host responsibility boundaries.

### `CZH-866` Android pressure follow-through
- Ensure Android-facing shared paths still compile/run after ownership moves.
- Keep Android as proving host pressure, not architecture lock.

### `CZH-867` Helper-level invariants
- Add helper tests that lock the moved caller/state ownership contract.

### `CZH-868` Integration invariants
- Add integration tests that lock behavior across moved ownership boundaries.

### `CZH-869` Scoped probe/doc hygiene + authority sync
- Remove stale probe/debug residue in touched product paths.
- Remove ticket/progress wording from touched source comments.
- Sync authority docs where wording changed.

### `CZH-870` Validation packet + gate handoff
- Record full ladder in `docs/todo/core/implementation.md`.
- Submit `docs/todo/core/CZH_S32_CHECKPOINT.md`.
- Move board to `review_gate` at `CZH-GATE-91`.
