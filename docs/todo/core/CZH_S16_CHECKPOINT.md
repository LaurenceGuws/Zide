# `CZH-S16` checkpoint — `CZH-GATE-75`

Date: 2026-04-19  
Sprint: `CZH-S16`  
Batch: `CZH-B21`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S16`
- Batch: `CZH-B21`
- Gate: `CZH-GATE-75` — **submitted for Architect review**
- Focus: generation seam (`surface_contract`) vs attachment seam
  (`surface_attachment_contract`) convergence at widget/presentation call sites;
  tests/docs; no ABI churn.

## Scope summary

- **CZH-701:** seam ownership audit + `CZH-709` hygiene scope in queue.
- **CZH-702:** module/field docs for pipeline leg vs full attachment.
- **CZH-703** / **CZH-704:** `planUpdate` routes generation primitives + `presentableReady()` pipeline leg.
- **CZH-705:** `presentationUpdateDelta.presentable_ready` via `presentableReady()`.
- **CZH-706:** `terminal_widget_draw` module seam doc.
- **CZH-707** / **CZH-708:** contract + widget integration tests.
- **CZH-709:** probe sweep note + `TERMINAL_SURFACE_CONTRACT.md` vocabulary.
- **CZH-710:** checkpoint + ladder (this file).

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-701 | `ade57c19` |
| CZH-702 | `82c151e1` |
| CZH-703 | `1bc19081` |
| CZH-704 | `5c973f96` |
| CZH-705 | `a0870ccd` |
| CZH-706 | `3a610823` |
| CZH-707 | `212d6942` |
| CZH-708 | `4e071fae` |
| CZH-709 | `b3367d7f` |

`CZH-710` is the commit that adds this checkpoint and queue/board handoff (`git log -1 -- docs/todo/core/CZH_S16_CHECKPOINT.md`).

## VALIDATION (engineer run)

Recorded in `docs/todo/core/implementation.md` under `CZH-B21` engineer validation (`CZH-710`).

Android Gradle guard — **SKIP** (lane paused).

## Blocked by Architect review needed

- **true** (for `CZH-GATE-75` acceptance).
