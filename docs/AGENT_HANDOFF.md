# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: **Core Zig freeze + hygiene**
- Campaign: **Core Zig Stability/Hygiene** (`CZH`)
- Active macro batch (`in_progress`): `CZH-B2` in
  `docs/todo/core/implementation.md`
- Android lane status: **paused by product direction** except critical
  regressions/blockers for current users.
- Active queue authority: `docs/todo/core/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/core/ENGINEER_ENTRYPOINT.md`

## Why This Shift

Android harness/GLES is now good enough to pause feature pressure and move
attention back to core quality.

Current top priorities:

1. stability under user stress workloads while cleanup lands
2. strict probe/debug hygiene on main branch product paths
3. naming convention cleanup aligned to real ownership
4. clean normalization of Android-driven FFI/rendering advances into shared
   product seams

Current batch intent (`CZH-B2`):

- unblock replay-harness compile drift and run stress extension baselines
- execute scoped probe/debug caller purge and naming hygiene in touched seams
- preserve frozen behavior and single-path ownership contracts

## First Read Order

1. `docs/todo/core/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/core/implementation.md`
3. `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
4. `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md`
5. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
6. `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

## Execution Contract

- Execute only the active macro batch marked in `docs/todo/core/implementation.md`
  (`in_progress` or `architect_review_pending` per batch state).
- Engineer batching target: **5–10 validated commits** per macro batch unless a
  real hard stop occurs.
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
