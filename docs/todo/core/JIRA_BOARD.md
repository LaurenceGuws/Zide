# Jira Board (Architect Authority)

This file is the canonical ticket board for active core execution.

## Board Rules

- Ticket IDs are immutable (`CZH-###`).
- One ticket maps to one commit unless explicitly approved by Architect before execution.
- Engineer executes tickets in listed order unless a dependency says otherwise.
- Engineer does not reorder, merge, or split tickets without Architect approval.
- In dual mode, Architect is the only role allowed to move tickets into `review_gate` and `done`.
- In single mode, execution can move directly to `done` without a review gate.
- Active board state stays small; historical ticket lists belong in checkpoints or git history.

## Status Columns

- `todo`: scoped, ready, not started.
- `in_progress`: active execution ticket (max 1).
- `blocked`: waiting on architecture/product decision.
- `changes_required`: architect rejected the gate; follow-up batch owns correction.
- `review_gate`: dual-mode checkpoint reached; awaiting Architect review.
- `done`: completed and accepted for the active mode.

## Current Sprint

- Sprint ID: `CZH-S76`
- Previous Sprint: `CZH-S75` (completed in single mode at `CZH-GATE-134`)
- Super-gate: `CZH-GATE-135` (`CZH-B81`, in_progress)
- Ticket source: `docs/todo/core/CZH_S76_TICKETS.md`

## Ticket Order (`CZH-S76`)

1. `CZH-1245`
2. `CZH-1246`
3. `CZH-1247`
4. `CZH-1248`

## Current State

- `in_progress`: `CZH-1245`
- `todo`: `CZH-1246`, `CZH-1247`, `CZH-1248`
- `review_gate`: none
- `blocked`: none
- `changes_required`: none
- `done`: `CZH-1229`, `CZH-1230`, `CZH-1235`, `CZH-1236`, `CZH-1237`, `CZH-1238`, `CZH-1239`, `CZH-1240`, `CZH-1241`, `CZH-1242`, `CZH-1243`, `CZH-1244` (CZH-S75 completed in single mode; no dual-mode review gate)
