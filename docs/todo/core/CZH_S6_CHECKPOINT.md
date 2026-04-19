# `CZH-S6` checkpoint — `CZH-GATE-65`

Date: 2026-04-19  
Sprint: `CZH-S6`  
Batch: `CZH-B11`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S6`
- Batch: `CZH-B11`
- Gate: `CZH-GATE-65` — **submitted for Architect review**
- Focus: remove `destroy_debug_pause_ms_for_tests` and test sleep from product
  `core_api.destroy`; preserve production teardown; tests use `shared` + atomic
  `destroying` observation only in harness code.

## Scope summary

- **CZH-631:** audit + replacement plan in `implementation.md`.
- **CZH-632:** delete product global and sleep from `core_api.zig`.
- **CZH-633:** `tests/terminal_ffi_smoke_tests.zig` — spin until `destroying`
  after spawning destroy; no `core_api` debug import.
- **CZH-634:** `CZH-606` / `CZH-608` / historical acceptance lines synced.
- **CZH-635:** checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-631 | `3c27f8f0` |
| CZH-632 | `55aa37f8` |
| CZH-633 | `430281f0` |
| CZH-634 | `901e2c44` |

`CZH-635` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S6_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-65` acceptance).
