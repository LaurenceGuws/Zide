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

- Sprint ID: `CZH-S5`
- Objective: close the remaining FFI/export doc-alignment drift so queue
  audits, authority docs, and code all describe the same ownership reality
- Commit budget before checkpoint: `5`
- Super-gate: `CZH-GATE-64`

## Ticket Order (`CZH-S5`)

1. `CZH-626`
2. `CZH-627`
3. `CZH-628`
4. `CZH-629`
5. `CZH-630`

## Current State

- `in_progress`: `CZH-627`
- `todo`: `CZH-628`, `CZH-629`, `CZH-630`
- `blocked`: none
- `review_gate`: none
- `done`: `CZH-B1`, `CZH-B2`, `CZH-B3`, `CZH-B4`, `CZH-B5` (accepted as a narrow hygiene slice), `CZH-B6` (accepted), `CZH-B7` (accepted), `CZH-B8` (accepted), `CZH-B9` (accepted), `CZH-601`, `CZH-602`, `CZH-603`, `CZH-604`, `CZH-605`, `CZH-606`, `CZH-607`, `CZH-608`, `CZH-609`, `CZH-610`, `CZH-611`, `CZH-612`, `CZH-613`, `CZH-614`, `CZH-615`, `CZH-616`, `CZH-617`, `CZH-618`, `CZH-619`, `CZH-620`, `CZH-621`, `CZH-622`, `CZH-623`, `CZH-624`, `CZH-625`, `CZH-626`
