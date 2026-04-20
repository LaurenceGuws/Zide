# CZH-S43 Checkpoint — Boundary Result Transport Collapse + Helper Surface Narrowing

**Sprint:** CZH-S43  
**Batch:** CZH-B48  
**Gate:** CZH-GATE-102  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-971` through `CZH-980` were executed in strict order with one ticket per commit.  
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no stale probe/debug residue in touched product paths
- source comments remained present-tense architecture statements only

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-971 | `f280a91b` | Boundary transport collapse audit + cut map |
| CZH-972 | `14408aed` | Authority tightening (doc-only) |
| CZH-973 | `2e728524` | Refresh transport collapse cut |
| CZH-974 | `dacfbdbb` | Reuse transport collapse cut |
| CZH-975 | `2aff0e27` | Direct-present transport collapse cut |
| CZH-976 | `8fea1a71` | Helper surface narrowing |
| CZH-977 | `b71b2f49` | Widget/runtime boundary cleanup after collapse |
| CZH-978 | `5b4e8c3a` | Helper-level invariants for collapsed transport |
| CZH-979 | `0cb40960` | Integration invariants + hygiene sweep |
| CZH-980 | (this commit) | Validation packet + gate handoff |

## Validation

### Required ladder

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `timeout 3s zig build run -- --mode terminal` — **PASS** (bounded smoke; startup banner observed; timeout exit expected for bounded run)
- `python3 ops/android_terminal_host.py deploy` — **PASS**
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — **PASS** (no AndroidRuntime errors)

## Key Changes (Behavior-Neutral)

- Added explicit collapse audit + cut authority:
  - `docs/todo/core/CZH_971_TRANSPORT_COLLAPSE_AUDIT_MAP.md`
- Tightened architecture authority to collapsed transport/narrowed helper surfaces:
  - `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- Collapsed refresh transport wrapper hop into canonical refresh flow return.
- Collapsed reuse transport to one canonical folded-result exit route.
- Collapsed direct transport by removing intermediate direct timing wrapper struct.
- Narrowed helper surface by removing duplicate timing helper alias surface and local widget fold aliases.
- Added helper and integration invariants to lock collapsed transport surface and no-wrapper boundaries.

## Board / Gate Notes

- Sprint moved to `review_gate` at `CZH-GATE-102` in `docs/todo/core/JIRA_BOARD.md`.
- Architect remains owner for movement from `review_gate` to `done`.

## Files touched in this sprint window

- `docs/todo/core/CZH_971_TRANSPORT_COLLAPSE_AUDIT_MAP.md`
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
- `docs/todo/core/implementation.md`
- `docs/todo/core/JIRA_BOARD.md`
