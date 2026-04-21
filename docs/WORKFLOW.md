# Workflow

This file defines how agents use repo docs without turning progress tracking
into the work.

## Operating Modes

Default to single-agent mode.

Use dual-agent mode only when the user explicitly wants Architect plus Engineer
sessions for a sprint-scale batch. Patch-sized work stays single-agent.

Single-agent mode:

- read `docs/AGENT_HANDOFF.md`
- read the active queue it names
- inspect the relevant code and architecture docs
- make the code/test change
- validate locally
- update only the docs needed for future focus or durable technical authority

Dual-agent mode:

- Architect sets direction, scope, and acceptance
- Engineer executes the batch and reports completed work, outstanding work,
  commits, and validation
- Architect reviews only at the batch boundary
- dual-mode review language does not apply to single-agent work

## Active Docs

Active docs must be small enough to read at session start.

- `docs/AGENT_HANDOFF.md`: current focus, read order, and hard constraints.
- `docs/todo/core/ACTIVE_QUEUE.md`: current core board and next work.
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`: dual-agent engineer prompt only.
- `app_architecture/`: durable technical authority.
- `docs/review/` and `docs/todo/**/archive/`: historical evidence.

Do not use active docs as a running diary. Commit messages are the normal record
that work happened.

## Work Board

The active queue is a small Jira-like board, not a history file.

Each active item needs:

- ID
- status: `ready`, `doing`, `blocked`, or `done`
- intent
- primary files
- exit check

Rules:

- keep at most one item in `doing`
- keep only the current slice and immediate next items in the active board
- move completed history to commit messages or a short checkpoint, not a ledger
- prefer file ownership and exit checks over abstract labels
- a cheaper Engineer agent must be able to execute the item without re-planning
  the whole lane

## Progress Rules

- Product code or tests must move for implementation work.
- A doc-only progress commit needs an explicit reason.
- Do not append routine validation ladders, ticket archaeology, or commit lists
  to `implementation.md`.
- Use a short checkpoint file only when a human needs a durable summary.
- Update `app_architecture/` only when future code needs a technical rule,
  invariant, or design reason.
- If a docs update does not change future behavior, focus, or handoff clarity,
  skip it.

## Commit Tagging

Commit subjects must include at least one strategic goal tag:

- `G1-HYGIENE`
- `G2-TOPOLOGY`
- `G3-CONSOLIDATION`
- `G4-VT`

Untagged commits are not allowed.

Recommended subject shape:

- `<goal-tag> <ticket-or-scope>: <summary>`

When one commit advances multiple goals, include multiple tags:

- `<goal-tag>+<goal-tag> <ticket-or-scope>: <summary>`

## Drift RCA

The previous system failed because the tracking system became the product:

- the core implementation ledger grew past 5000 lines and was touched too often
- ticket accounting started to replace engineering judgment
- docs-only batches continued after they stopped unlocking code decisions
- dual-agent review wording leaked into single-agent work
- active docs mixed current focus, historical evidence, and architecture
  authority

Countermeasures:

- one short active board per lane
- history archived outside the active path
- code/test movement required for implementation work
- durable rules go in `app_architecture/`
- temporary coordination stays in handoff, active queue, or agent messages
- single-agent and dual-agent modes stay separate

## Planning Rules

For broad refactors, performance work, or architecture cleanup:

1. audit enough to name concrete code targets
2. identify non-goals before coding
3. implement the next useful slice
4. validate
5. update the active queue only if the next step changed

If the audit finds no executable target, stop and say that. Do not invent a
cleanup ticket to satisfy the queue.

## Quality Rules

- Preserve behavior by default during cleanup.
- Avoid compatibility shims and preservation-only fallbacks.
- Keep diffs reviewable and buildable.
- Prefer one logical change per commit.
- Combine tightly coupled code changes when splitting would create churn or a
  broken intermediate state.
- Do not introduce CI; validation is local.

## Debug And Telemetry

Investigation code is temporary by default.

Before closing a task, classify every added log, counter, sample, debug field,
env flag, probe path, and capture hook:

- correctness contract: required for product behavior
- operator telemetry: useful when gated with near-zero disabled cost
- probe/debug capture: explicitly armed investigation support

Delete anything that does not fit one of those categories. If behavior depends
on a field, do not name it debug, trace, or probe.

## Platform Pressure

Treat Android pressure as a shared-contract signal unless the issue is truly
Android-owned.

- shared-contract examples: lifecycle semantics, render scheduling, surface
  availability, present/invalidation rules, font/atlas cost
- platform-owned examples: Activity callbacks, Java/Kotlin UI ownership, JNI
  handoff shape, Android storage/userland details
