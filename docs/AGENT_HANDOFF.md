# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: **Core Zig freeze + hygiene**
- Campaign: **Core Zig Stability/Hygiene** (`CZH`)
- Active macro batch (`in_progress`, super-gate `CZH-GATE-127`): `CZH-B73` in
  `docs/todo/core/implementation.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S51_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S52_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S53_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S54_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S55_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S56_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S57_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S58_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S59_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S60_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S61_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S62_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S63_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S64_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S65_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S66_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S67_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S50_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S49_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S48_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S47_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S46_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S45_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S44_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S43_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S42_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S41_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S40_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S39_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S38_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S37_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S36_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S34_CHECKPOINT.md`
- Accepted sprint validation: `docs/todo/core/CZH_S33_VALIDATION.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S32_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S31_CHECKPOINT.md`
- Rejected sprint checkpoint: `docs/todo/core/CZH_S30_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S29_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S28_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S27_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S26_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S25_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S24_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S23_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S22_CHECKPOINT.md`
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
- Accepted sprint checkpoint: `docs/todo/core/CZH_S12_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S13_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S14_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S15_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S16_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S17_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S18_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S19_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S20_CHECKPOINT.md`
- Accepted sprint checkpoint: `docs/todo/core/CZH_S21_CHECKPOINT.md`
- Active sprint board: `docs/todo/core/JIRA_BOARD.md`
- Active ticket source: `docs/todo/core/CZH_S68_TICKETS.md`
- Android lane status: **paused by product direction** except critical
  regressions/blockers for current users.
- Connected Android device for this checkpoint: `RF8M74JDWEK`.
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
6. keep source comments present-tense: ownership, invariants, and constraints
   only; ticket/progress history belongs in `docs/todo/`

Current batch status (`CZH-B73`, in progress toward `CZH-GATE-127`):

- target: harden enforcement matrix determinism for stable claim-to-lock mappings
- preserve sealed canonical surface and no-bypass guarantees
- preserve behavior and host ABI while reducing reviewer drift from ordering ambiguity

## First Read Order

1. `docs/todo/core/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/core/implementation.md`
3. `docs/todo/core/JIRA_BOARD.md`
4. `docs/todo/core/CZH_S60_TICKETS.md`
5. `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
6. `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md`
7. `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
8. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
9. `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

## Execution Contract

- Execute only the active macro batch marked in `docs/todo/core/implementation.md`
  (`in_progress` or `architect_review_pending` per batch state).
- Engineer executes the current sprint tickets in `docs/todo/core/JIRA_BOARD.md`
  and active sprint ticket file referenced in `docs/todo/core/JIRA_BOARD.md` in listed order.
- Engineer batching target: **8–14 validated commits** per macro batch unless a
  real hard stop occurs.
- Architect review cadence: avoid interim review loops; review once at the
  super-gate unless blocked.
- Keep changes single-path. Behavior is frozen by default, but startup/runtime
  regressions are correctness fixes and must be repaired directly.
- Keep Android lane frozen except for blocker-class regressions.
- Current FFI/caller placement is not a blocker. If fixing the runtime order
  means moving callers or state ownership, do it cleanly and update Android.
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
