# `CZH-S15` checkpoint — `CZH-GATE-74`

Date: 2026-04-19  
Sprint: `CZH-S15`  
Batch: `CZH-B20`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S15`
- Batch: `CZH-B20`
- Gate: `CZH-GATE-74` — **submitted for Architect review**
- Focus: `surface_attachment_contract` host attachment pairing; widget surface
  state routes `notePresentableAvailability`; docs/tests; no ABI churn.

## Scope summary

- **CZH-691:** audit + hygiene scope.
- **CZH-692** / **CZH-693:** `surface_attachment_contract` primitive + composite.
- **CZH-694:** presentation runtime + `surface_contract` doc cross-links.
- **CZH-695:** `terminal_widget_surface_state` wiring + `readSharedSurfaceAttachmentReady`.
- **CZH-696:** `terminal_widget_draw` test link.
- **CZH-697** / **CZH-698:** invariant tests.
- **CZH-699:** `TERMINAL_SURFACE_CONTRACT.md` + queue landed/sweep.
- **CZH-700:** checkpoint + ladder.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-691 | `66f0c359` |
| CZH-692 | `232c9da1` |
| CZH-693 | `2383908c` |
| CZH-694 | `a3b94513` |
| CZH-695 | `ed7dffa2` |
| CZH-696 | `68001a0f` |
| CZH-697 | `52f2fccf` |
| CZH-698 | `8cbef312` |
| CZH-699 | `140af167` |

`CZH-700` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S15_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-74` acceptance).
