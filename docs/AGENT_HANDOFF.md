# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: **Core Zig freeze + hygiene**
- Campaign: **Core Zig Stability/Hygiene** (`CZH`)
- Active macro batch (`architect_review_pending` at `CZH-GATE-71`): `CZH-B17` in
  `docs/todo/core/implementation.md`
- Accepted freeze checkpoint: `docs/todo/core/CZH_B6_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S2_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S3_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S4_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S5_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S6_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S7_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S8_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S9_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S10_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S11_CHECKPOINT.md`
- Pending sprint checkpoint (Architect): `docs/todo/core/CZH_S12_CHECKPOINT.md`
- Active sprint board: `docs/todo/core/JIRA_BOARD.md`
- Active ticket source: `docs/todo/core/CZH_S12_TICKETS.md`
- Android lane status: **paused by product direction** except critical
  regressions/blockers for current users.
- Active queue authority: `docs/todo/core/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/core/ENGINEER_ENTRYPOINT.md`

## Why This Shift

Android harness/GLES is now good enough to pause feature pressure and move
attention back to core quality.

Current top priorities:

1. freeze the shared split before more cleanup:
   - VT core FFI
   - optional bring-your-own-PTY host seam
   - editor backend FFI
   - terminal surface contract
2. keep the core stress ladder green while architecture authority lands
3. enforce strict probe/debug hygiene on main branch product paths
4. remove compatibility/fallback/legacy residue instead of carrying it forward
5. scrutinize file/module doc strings and important function docs for alignment
   with actual ownership and behavior

Current batch intent (`CZH-B17`, submitted at `CZH-GATE-71`):

- composite publication/clear pair seam for present-plan and surface-state delta
- scoped probe sweep recorded; Architect review pending on checkpoint packet

## First Read Order

1. `docs/todo/core/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/core/implementation.md`
3. `docs/todo/core/JIRA_BOARD.md`
4. `docs/todo/core/CZH_S12_TICKETS.md`
5. `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
6. `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md`
7. `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
8. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
9. `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

## Execution Contract

- Execute only the active macro batch marked in `docs/todo/core/implementation.md`
  (`in_progress` or `architect_review_pending` per batch state).
- Engineer executes the current sprint tickets in `docs/todo/core/JIRA_BOARD.md`
  and `docs/todo/core/CZH_S12_TICKETS.md` in listed order.
- Engineer batching target: **8–14 validated commits** per macro batch unless a
  real hard stop occurs.
- Architect review cadence: avoid interim review loops; review once at the
  super-gate unless blocked.
- Keep changes single-path and behavior-stable unless the batch explicitly
  scopes behavior change.
- Keep Android lane frozen except for blocker-class regressions.
- Use human-readable update labels and role-specific blocked flags:
  - Architect: `Blocked by humain review needed: true|false`
  - Engineer: `Blocked by Archtect review needed: true|false`

## Hard Rule: Probe/Debug Hygiene

Main-branch product code must not accumulate ad hoc debug probe residue.

- Logging infrastructure may exist in the project.
- Investigation-only logger callers/checks in hot/product code must be removed
  when the probe is no longer the active focus.
- Do not keep copied logger structs / scattered `log enabled` checks as
  historical residue.
- If a probe is still needed short-term, keep it explicit and removable;
  closing the batch requires cleanup.

## Android Pause Contract

- `APX` work is paused for now.
- Reopen Android only for:
  - user-blocking regressions
  - cross-repo integration blockers required by active core batches
  - explicitly approved product reopen

## Historical Notes

- Android refocus authority remains in:
  `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
- Android queue history remains in:
  `docs/todo/android/implementation.md`
- Pre-refocus Android logs remain in:
  `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`
