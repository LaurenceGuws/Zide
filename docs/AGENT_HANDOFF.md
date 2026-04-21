# Handoff

Session entrypoint only. Keep this file short and current.

## Current Truth

- Default mode: **single operation** unless the user explicitly requests dual-agent operation.
- Mode policy: dual-agent mode is for sprint-scale batches; patch-sized cuts run in single operation mode.
- Product lane: **Core Zig freeze + hygiene**.
- Campaign: **Core Zig Stability/Hygiene** (`CZH`).
- Active queue: `docs/todo/core/ACTIVE_QUEUE.md`.
- Active detail, if needed: `docs/todo/core/CZH_S76_TICKETS.md`.
- Legacy progress ledgers are archived and are not part of normal read order.

## Active Focus

Continue Android-to-core consolidation by removing residual Android-specialized lifecycle ownership and thinning bridge code to platform-shell responsibilities.

## Strategic Goals

Use this order as the long-term navigation map:

1. `G1-HYGIENE` - hot-path hygiene and stable performance baseline
2. `G2-TOPOLOGY` - naming and module-topology normalization for extraction
3. `G3-CONSOLIDATION` - fold Android progress into shared core maturity
4. `G4-VT` - return to VT core correctness

Commit-tag rule:

- Every commit must include at least one goal tag in the commit subject.
- Commits without a goal tag are not allowed.

## First Read Order

1. `docs/todo/core/ACTIVE_QUEUE.md`
2. `docs/todo/core/CZH_S76_TICKETS.md`
3. `docs/WORKFLOW.md`
4. `app_architecture/ENGINEERING.md`
5. `app_architecture/platform/android/ANDROID_RENDER_THREAD_CONTRACT.md`
6. relevant source files named by the active queue

## Anti-Drift Rules

- Active docs must stay small; do not revive the old 5000-line progress ledger.
- The active queue is the delegation board: each item needs target files and an exit check.
- Product code or tests must move for implementation work.
- Documentation updates are secondary: update only handoff, active queue, or durable architecture authority.
- Do not use dual-agent review wording in single-agent work.
- If a task cannot name a concrete product path and result, stop and re-scope.

## Validation Baseline

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- bounded terminal startup smoke when presentation/runtime paths are touched
- Android deploy/log smoke only when Android or shared Android-proving seams are touched

## Android Pause Contract

Android feature work remains paused except for blocker regressions and shared-seam validation required by the active core hygiene batch. Android evidence should be consolidated into shared core contracts only when the active phase reaches Android consolidation.
