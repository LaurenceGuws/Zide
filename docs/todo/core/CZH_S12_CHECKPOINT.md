# `CZH-S12` checkpoint — `CZH-GATE-71`

Date: 2026-04-19  
Sprint: `CZH-S12`  
Batch: `CZH-B17`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S12`
- Batch: `CZH-B17`
- Gate: `CZH-GATE-71` — **submitted for Architect review**
- Focus: composite publication/clear pair seam (`publicationClearPairMismatchesFromLastSurfaceRender`,
  `publicationClearPairMatchesLastSurfaceRender`) for present-plan and
  `presentationUpdateDelta`; scoped probe sweep; no ABI or behavior drift.

## Scope summary

- **CZH-661:** audit + hygiene scope confirmation.
- **CZH-662:** composite pair helpers in `surface_contract.zig`.
- **CZH-663:** present-plan `generation_matches_presented` via composite match.
- **CZH-664:** `presentationUpdateDelta` via composite mismatches.
- **CZH-665:** seam doc alignment at touched boundaries.
- **CZH-666** / **CZH-667:** invariant tests (module + widget surface state).
- **CZH-668:** probe sweep note (no stale residue removed).
- **CZH-669:** `TERMINAL_SURFACE_CONTRACT.md` + queue landed summary.
- **CZH-670:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-661 | `cb1949c1` |
| CZH-662 | `d9b85611` |
| CZH-663 | `210390d7` |
| CZH-664 | `e570eadf` |
| CZH-665 | `68b2d9af` |
| CZH-666 | `78acf8d3` |
| CZH-667 | `89d864ae` |
| CZH-668 | `913362be` |
| CZH-669 | `4e276f06` |

`CZH-670` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S12_CHECKPOINT.md`).

## VALIDATION (engineer run, 2026-04-19)

- `zig build` — PASS  
- `zig build test` — PASS  
- `zig build -Dmode=terminal` — PASS  
- `zig build -Dmode=editor` — PASS  
- `zig build test-config` — PASS  
- `zig build test-editor` — PASS  
- `zig build test-terminal-replay-all` — PASS  

Android Gradle guard — **SKIP** (lane paused).

## Blocked by Architect review needed

- **true** (for `CZH-GATE-71` acceptance).
