# `CZH-S5` checkpoint — `CZH-GATE-64`

Date: 2026-04-19  
Sprint: `CZH-S5`  
Batch: `CZH-B10`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S5`
- Batch: `CZH-B10`
- Gate: `CZH-GATE-64` — **submitted for Architect review**
- Focus: FFI/export doc-alignment closure — queue audits, `CZH-608` table, and
  code (`editor` bridge, `terminal_ffi_exports`, `core_api`) describe the same
  ownership; no behavior or file moves.

## Scope summary

- **CZH-626:** drift audit recorded in `implementation.md` (`CZH-B10`).
- **CZH-627:** `terminal_ffi_exports.zig` module `//!` (symbol root vs `c_api`).
- **CZH-628:** `///` on editor `create`/`destroy`; `core_api` publication/query
  exports per audit list.
- **CZH-629:** `CZH-608` table + doc-alignment queue synced to post-`CZH-S5` truth.
- **CZH-630:** this checkpoint + validation ladder record.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-626 | `850561fb` |
| CZH-627 | `b63d3c90` |
| CZH-628 | `d632c93d` |
| CZH-629 | `605d081e` |

`CZH-630` is the commit that adds this checkpoint (`git log -1 -- docs/todo/core/CZH_S5_CHECKPOINT.md`).

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

- **true** (for `CZH-GATE-64` acceptance).
