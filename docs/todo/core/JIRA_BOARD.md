# Jira Board (Architect Authority)

This file is the canonical ticket board for active core execution.

## Board Rules

- Ticket IDs are immutable (`CZH-###`).
- One ticket maps to one commit unless explicitly approved by Architect before execution.
- Engineer executes tickets in listed order unless a dependency says otherwise.
- Engineer does not reorder, merge, or split tickets without Architect approval.
- Architect is the only role allowed to move tickets into `review_gate` and `done`.
- Active board state stays small; historical ticket lists belong in checkpoints or git history.

## Status Columns

- `todo`: scoped, ready, not started.
- `in_progress`: active execution ticket (max 1).
- `blocked`: waiting on architecture/product decision.
- `changes_required`: architect rejected the gate; follow-up batch owns correction.
- `review_gate`: checkpoint reached; awaiting Architect review.
- `done`: Architect accepted ticket outcome.

## Current Sprint

- Sprint ID: `CZH-S74`
- Previous Sprint: `CZH-S73` (accepted baseline closure at `CZH-GATE-132`)
- Super-gate: `CZH-GATE-133` (`CZH-B79`, in_progress)
- Ticket source: `docs/todo/core/CZH_S74_TICKETS.md`

## Ticket Order (`CZH-S74`)

1. `CZH-1235`
2. `CZH-1236`
3. `CZH-1237`
4. `CZH-1238`
5. `CZH-1239`
6. `CZH-1240`

## Current State

- `in_progress`: none
- `todo`: none
- `review_gate`: `CZH-1236`, `CZH-1237`, `CZH-1238`, `CZH-1239`, `CZH-1240` (CZH-S74 naming and topology normalization batch ready for architect review)
- `blocked`: none
- `changes_required`: none
- `done`: `CZH-1229`, `CZH-1230`, `CZH-1235` (CZH-S74 execution complete; validation ladder passed)
