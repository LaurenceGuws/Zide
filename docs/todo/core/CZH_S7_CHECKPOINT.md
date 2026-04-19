# `CZH-S7` checkpoint — `CZH-GATE-66`

Date: 2026-04-19  
Sprint: `CZH-S7`  
Batch: `CZH-B12`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S7`
- Batch: `CZH-B12`
- Gate: `CZH-GATE-66` — **submitted for Architect review**
- Focus: explicit terminal surface-contract Zig seam (`surface_contract.zig`);
  behavior-neutral routing in `core_api`; no host ABI change.

## Scope summary

- **CZH-636:** touchpoint map + seam plan in `implementation.md`.
- **CZH-637:** `src/terminal/surface_contract.zig` + `tests_main` compile hook.
- **CZH-638:** `redrawState` / `needsRedraw` use seam helpers.
- **CZH-639:** `TERMINAL_SURFACE_CONTRACT.md` + queue landed-state notes.
- **CZH-640:** this checkpoint + ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-636 | `28711290` |
| CZH-637 | `8c0e65ae` |
| CZH-638 | `4d78a473` |
| CZH-639 | `fdc33518` |

`CZH-640` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S7_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-66` acceptance).
