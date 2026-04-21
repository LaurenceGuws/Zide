# Core Engineer Entrypoint

Use this file only for dual-agent mode. Patch-sized work runs in single mode
from `docs/AGENT_HANDOFF.md` and `docs/todo/core/ACTIVE_QUEUE.md`.

Read in this exact order:

1. `docs/AGENT_HANDOFF.md`
2. `docs/todo/core/ACTIVE_QUEUE.md`
3. `docs/todo/core/CZH_S76_TICKETS.md`
4. `app_architecture/ENGINEERING.md`
5. source files named by the active queue

## Current Active Batch

- Focus: Android-to-core consolidation phase 2.
- Queue: `docs/todo/core/ACTIVE_QUEUE.md`
- Detail: `docs/todo/core/CZH_S76_TICKETS.md`

## Hard Rules

- Code/test movement is mandatory for every ticket except an explicitly labelled `doc-only` ticket.
- Do not create documentation-only commits for implementation tickets.
- Do not update archived ledgers or revive `JIRA_BOARD.md` columns.
- No behavior or ABI changes unless the ticket explicitly identifies a correctness bug.
- No compatibility shims, fallback branches, or preservation-only seams.
- Classify every touched logging/probe/counter/capture artifact as correctness contract, operator telemetry, or probe/debug capture; remove anything that does not fit.
- Product hot paths must not update debug capture state or execute investigation logging by default.
- Tests and temporary inline debugging may use debug helpers; real app paths may not retain investigation scaffolding.
- Keep naming/topology changes scoped to ticket boundaries; no broad folder reshuffle.

## Engineer Cadence

- Execute active queue items in order.
- Do not start an item unless it names target files and an exit check.
- Prefer one logical change per commit; combine tightly coupled code changes when splitting would create churn or broken intermediates.
- Every commit subject must include at least one strategic goal tag (`G1-HYGIENE`, `G2-TOPOLOGY`, `G3-CONSOLIDATION`, `G4-VT`).
- Keep commits code-first and reviewable.
- If the next ticket appears to require mostly markdown, stop and ask Architect for re-scope.

## Stop Conditions

Stop and report instead of improvising when:

- the active item does not name concrete target files
- the intended change turns into documentation-only work
- validation fails and the cause is outside the active item
- a behavior or ABI change appears necessary
- the work would require broad folder reshuffling or compatibility shims

## Validation Ladder

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- Bounded terminal startup smoke when presentation/runtime paths are touched.
- Android deploy/log smoke only when Android or Android-proving shared seams are touched.

## Required Response Format

Use this format only in dual-agent mode:

- `LABELS`
- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by Architect review needed: true|false`
