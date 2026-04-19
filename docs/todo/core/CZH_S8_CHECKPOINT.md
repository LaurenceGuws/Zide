# `CZH-S8` checkpoint — `CZH-GATE-67`

Date: 2026-04-19  
Sprint: `CZH-S8`  
Batch: `CZH-B13`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S8`
- Batch: `CZH-B13`
- Gate: `CZH-GATE-67` — **submitted for Architect review**
- Focus: expand `surface_contract` to **`present_ack`** admissibility; no ABI or
  behavior drift.

## Scope summary

- **CZH-641:** audit — `presentAck` as next bounded crossing (`implementation.md`).
- **CZH-642:** `presentAckGenerationAdmissible` in `surface_contract.zig`.
- **CZH-643:** `core_api.presentAck` routes through helper.
- **CZH-644:** predicate unit tests + `TERMINAL_SURFACE_CONTRACT.md` + queue landed
  note.
- **CZH-645:** this checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-641 | `c8f6a41e` |
| CZH-642 | `8657ff26` |
| CZH-643 | `f8c5d492` |
| CZH-644 | `7c036b79` |

`CZH-645` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S8_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-67` acceptance).
