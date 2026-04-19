# Jira Board (Architect Authority)

This file is the canonical ticket board for active core execution.

## Board Rules

- Ticket IDs are immutable (`CZH-###`).
- One ticket maps to one commit unless explicitly marked `atomic-pair`.
- Engineer executes tickets in listed order unless a dependency says otherwise.
- Engineer does not reorder, merge, or split tickets without Architect approval.
- Architect is the only role allowed to move tickets into `review_gate` and `done`.

## Status Columns

- `todo`: scoped, ready, not started.
- `in_progress`: active execution ticket (max 1).
- `blocked`: waiting on architecture/product decision.
- `review_gate`: checkpoint reached; awaiting Architect review.
- `done`: Architect accepted ticket outcome.

## Current Sprint

- Sprint ID: `CZH-S1`
- Objective: freeze the core host/core/editor/surface split before more cleanup
- Commit budget before checkpoint: `10`
- Super-gate: `CZH-GATE-60`

## Ticket Order (`CZH-S1`)

1. `CZH-601`
2. `CZH-602`
3. `CZH-603`
4. `CZH-604`
5. `CZH-605`
6. `CZH-606`
7. `CZH-607`
8. `CZH-608`
9. `CZH-609`
10. `CZH-610`

## Current State

- `in_progress`: `CZH-603`
- `todo`: `CZH-604`, `CZH-605`, `CZH-606`, `CZH-607`, `CZH-608`, `CZH-609`, `CZH-610`
- `blocked`: none
- `review_gate`: none
- `done`: `CZH-B1`, `CZH-B2`, `CZH-B3`, `CZH-B4`, `CZH-B5` (accepted as a narrow hygiene slice), `CZH-601`, `CZH-602`
