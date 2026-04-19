# `CZH-B6` checkpoint — `CZH-GATE-60`

Date: 2026-04-19 (updated after `CZH-B6-corrective`)  
Sprint: `CZH-S1`  
Engineer → Architect handoff packet.

## LABELS

- Lane: `core_czh`
- Sprint: `CZH-S1`
- Batch: `CZH-B6` / **`CZH-B6-corrective`** (authority alignment; no code)
- Gate: `CZH-GATE-60` — **submitted for Architect review** (**resubmitted** after
  corrective doc pass)
- Focus delivered: freeze the shared Zig split with **explicit separation** of:
  **VT core FFI** (publication / query / redraw / events / metadata truth) vs
  **optional BYO-PTY host seam** (session / runtime / input / transport), plus
  **editor backend FFI** and **terminal surface contract** (shared GPU
  texture/resource attachment; Zide owns dirty/generation/content updates; host
  owns binding/presentation).

## Scope summary

- **Four-layer messaging** aligned across queue, board, entrypoint, and tickets
  (`CZH-601`).
- **Terminal FFI file map** in `TERMINAL_SUBSYSTEM_LAYERS.md` (`CZH-602`) —
  **corrected:** target split is normative; `host_api` under `ffi/` is current
  placement, not “one VT core FFI story” with `core_api`.
- **Editor FFI authority** in `app_architecture/editor/FFI_DESIGN.md` (`CZH-603`).
- **Terminal surface contract** in `TERMINAL_SURFACE_CONTRACT.md` (`CZH-604`) —
  **corrected:** centers **shared GPU texture/resource attachment** and Zide
  generation/dirty truth; does not freeze native window/swapchain as the
  abstraction; Android one proving host only.
- **Cross-layer inventory + non-goals** in `docs/todo/core/implementation.md`
  (`CZH-605`) — **corrected** inventory rows for VT core vs BYO-PTY.
- **Hard-rule audits** (`CZH-606`..`CZH-608`) unchanged in substance; scope
  labels in queue match the split above.
- **Next sprint** ticketed: `docs/todo/core/CZH_S2_TICKETS.md` (`CZH-609`) — **do
  not start** until Architect accepts `CZH-GATE-60`.
- **Checkpoint packaging** (`CZH-610`).

## `CZH-B6-corrective` (2026-04-19)

Doc-only follow-up so frozen authority matches the architect’s target before gate
acceptance:

- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — VT core vs BYO-PTY
  definitions, file table, smell notes (no merged “single FFI story”).
- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md` — shared GPU resource
  path, ownership table, non-goals.
- `docs/todo/core/implementation.md` — four-layer bullets, `CZH-602`/`CZH-604`
 /`CZH-605` records.
- **`CZH-GATE-60` resubmitted** with this checkpoint updated; **no product code
  changes.**

## #DONE

- `CZH-601` .. `CZH-610` (original sprint).
- `CZH-B6-corrective` authority alignment (this document + linked files).

## #OUTSTANDING

- Architect acceptance of `CZH-GATE-60` (batch `CZH-B6`).
- `CZH-S2` (`CZH-611`..`CZH-615`) — **not** started; blocked on gate acceptance
  per board rules.

## COMMITS (sprint order)

| Ticket | Commit |
| --- | --- |
| CZH-601 | `3b772c77` |
| CZH-602 | `15c51c8d` |
| CZH-603 | `a43610d8` |
| CZH-604 | `04153fa3` |
| CZH-605 | `44ebe637` |
| CZH-606 | `a04c9bc4` |
| CZH-607 | `89cb2d5b` |
| CZH-608 | `015aa139` |
| CZH-609 | `15df5921` |

`CZH-610` is the commit that introduces the prior checkpoint and gate state.

**`CZH-B6-corrective` doc commits:** see `git log` after `CZH-610` for
`docs(czh):` / authority updates (subsystem layers, surface contract,
implementation queue, checkpoint/board/handoff).

## VALIDATION (engineer run, corrective pass, 2026-04-19)

- `zig build` — PASS  
- `zig build test` — PASS  
- `zig build -Dmode=terminal` — PASS  
- `zig build -Dmode=editor` — PASS  

(Extended ladder from original checkpoint unchanged in requirement; re-run at
Architect discretion.)

Android Gradle guard — **SKIP** (lane paused; no Android seam touched).

## Authority pointers

- Board: `docs/todo/core/JIRA_BOARD.md`
- Sprint tickets (closed): `docs/todo/core/CZH_B6_TICKETS.md`
- Next sprint (queued, not started): `docs/todo/core/CZH_S2_TICKETS.md`
- Queue: `docs/todo/core/implementation.md`

## Blocked by Architect review needed

- **true** (for gate acceptance and moving `CZH-B6` from `architect_review_pending`
  to `accepted`).
