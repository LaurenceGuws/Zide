# CZH-971 Boundary Transport Collapse Audit Map — Helper Surface Narrowing

**Ticket:** `CZH-971`  
**Sprint:** `CZH-S43`  
**Batch:** `CZH-B48`  
**Gate:** `CZH-GATE-102`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit + cut map only (no behavior or ABI change)

## Purpose

Audit remaining boundary result-transport duplication and helper-surface overlap after
`CZH-B47`, then define the ordered cut map for `CZH-972`..`CZH-980`.

## Hard constraints

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback framing.
- No stale debug/probe residue in touched paths.
- Source comments remain present-tense architecture only.

## Remaining duplication inventory

### Refresh transport

- `runRefreshBoundaryPresentationResult(...)` in widget layer still acts as a dedicated
  refresh boundary transport hop over terminal-owned fold composition.
- `executeRefreshPresentFlow(...)` terminal helper already expects a direct
  `TerminalPresentResult` from `runPresentation` hook.

**Collapse target:** keep one refresh boundary transport route that exits as
`TerminalPresentResult` directly, without wrapper-only refresh transport hops.

### Reuse transport

- Reuse path already converges at `foldReuseAttemptResultToPresent(...)` and returns
  `TerminalPresentResult` from `tryFastPresentExisting(...)`.
- Remaining duplication is helper-surface terminology and wrapper-style naming around
  repeated fold entry wording in docs/tests.

**Collapse target:** preserve one canonical reuse fold route and remove redundant
helper-surface wording/shape overlap.

### Direct transport

- Widget direct path still carries an intermediate transport struct
  `DirectPresentResult { bg_ms, glyph_ms, kitty_ms }` that is immediately remapped into
  `TerminalPresentTiming` before direct fold composition.
- Terminal layer already owns canonical direct fold entry
  `presentResultFromDirectPresentOutcomeState(...)` over `TerminalPresentTiming`.

**Collapse target:** remove direct intermediate transport struct hop and return
canonical timing transport directly from direct execution path.

## Helper-surface narrowing targets

1. Refresh: narrow wrapper-only boundary function surface to one terminal-result route.
2. Reuse: keep only canonical reuse fold helper as the boundary fold surface.
3. Direct: remove duplicate timing carrier wrapper surface around direct flow.

## Execution cut map (`CZH-972`..`CZH-980`)

1. `CZH-972` — authority tightening for collapsed transport and narrowed helper surfaces.
2. `CZH-973` — refresh transport collapse cut.
3. `CZH-974` — reuse transport collapse cut.
4. `CZH-975` — direct-present transport collapse cut.
5. `CZH-976` — helper-surface narrowing (duplicate aliases/wrappers removed).
6. `CZH-977` — widget/runtime boundary glue cleanup after collapse.
7. `CZH-978` — helper-level invariants for collapsed transport routes.
8. `CZH-979` — integration invariants and touched-file hygiene sweep.
9. `CZH-980` — full ladder + checkpoint + gate handoff docs.

## Non-goals

- No renderer/backend architecture reshaping.
- No terminal semantic changes.
- No FFI export changes.

## Audit conclusion

`CZH-B47` narrowed refresh/reuse carriers to folded host-facing transport. `CZH-B48`
now removes the remaining wrapper hops and duplicate helper surfaces so refresh,
reuse, and direct boundaries each expose one canonical transport route.
