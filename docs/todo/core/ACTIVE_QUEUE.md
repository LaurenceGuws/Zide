# Core Active Queue

This is the only active progress tracker for the current core lane.

Keep this file short and executable. It should let a fresh agent answer:

- what problem are we solving?
- what is the next work item?
- what files are likely involved?
- what is explicitly out of scope?
- what validation proves the work?

Historical evidence belongs in commit messages, checkpoint files, or archive
files, not here.

## Current Focus

- Mode: `single` by default.
- Lane: Android-to-core consolidation, phase 2.
- Optional tracking IDs: `CZH-B81` / `CZH-S76`
- Active work source: `docs/todo/core/CZH_S76_TICKETS.md`
- Current step: `CZH-1245`

## Goal Tags

Use these mandatory goal tags in commit subjects:

- `G1-HYGIENE`: hot-path hygiene and performance baseline discipline
- `G2-TOPOLOGY`: naming and module-topology normalization
- `G3-CONSOLIDATION`: Android-to-core consolidation
- `G4-VT`: VT core correctness

Current primary goal: `G3-CONSOLIDATION`.

Commit subject format:

- `<goal-tag> <ticket-or-scope>: <summary>`
- Example: `G3-CONSOLIDATION CZH-1245: remove residual android lifecycle wrapper callsites`

Rule: no untagged commits.

## Product Intent

Android work should strengthen shared runtime and renderer contracts instead of
becoming a stronger platform-only special case. The current pass removes
remaining platform-specific ownership around lifecycle and presentation behavior.

## Board

Status meanings:

- `ready`: scoped and executable
- `doing`: current item, max one
- `blocked`: needs human or architecture decision
- `done`: completed in the active slice

| ID | Status | Intent | Primary files | Exit |
| --- | --- | --- | --- | --- |
| `CZH-1245` | `doing` | Remove or justify residual Android lifecycle wrappers. | `src/platform/android_host.zig`, `src/platform/sdl_android_host.zig`, `src/platform/host_lifecycle_runtime.zig` | Direct users route through the shared owner, or wrapper ownership is explicitly justified. |
| `CZH-1246` | `ready` | Normalize shared lifecycle API names so they describe owned behavior, not caller context. | `src/platform/host_lifecycle_runtime.zig`, migrated callsites | Shared API names are owner-driven and tests pass. |
| `CZH-1247` | `ready` | Thin one platform-agnostic responsibility out of `android_runtime_bridge.zig`. | `src/platform/android_runtime_bridge.zig`, selected shared owner | Bridge loses one non-platform responsibility without behavior or ABI drift. |
| `CZH-1248` | `ready` | Validate and leave the next queue state clear. | active queue, handoff if next focus changes | Validation recorded briefly; no historical ledger update. |

## Work Item Rules

- A work item must name target files before implementation starts.
- A work item must have an exit condition that can be checked from code, tests,
  or local validation.
- If an item becomes mostly documentation, stop and re-scope.
- If an item is too large to review, split it by code ownership, not by
  paperwork.
- If two edits are inseparable without churn or a broken intermediate, combine
  them and say why in the commit message.

## Guardrails

- Product code or tests must move for implementation work.
- Do not create doc-only progress tickets unless the user explicitly asks for a
  planning artifact.
- Do not update historical ledgers as routine progress.
- Do not use dual-agent review language in single-agent work.
- Keep Android feature expansion paused unless it directly proves or protects a
  shared core contract.

## Drift RCA

The previous workflow drifted because:

- progress docs became a substitute for product movement
- the active ledger grew until it was too expensive to read
- ticket accounting became more important than code ownership
- dual-agent review language leaked into single-agent work
- doc-only batches were allowed after the contract was already clear

Current countermeasures:

- one short active queue
- commit messages as normal evidence
- archives for history
- explicit file targets and exit checks per work item
- code/test movement required for implementation work

## Validation

Required before closing this slice:

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`

Run Android deploy/log smoke only when the change touches Android runtime,
bridge, Java/Kotlin host code, or shared Android-proving behavior.

## Archive

- Legacy core implementation ledger:
  `docs/todo/core/archive/implementation_legacy_through_CZH_S76.md`
- Legacy Jira-style board:
  `docs/todo/core/archive/JIRA_BOARD_legacy_through_CZH_S76.md`
