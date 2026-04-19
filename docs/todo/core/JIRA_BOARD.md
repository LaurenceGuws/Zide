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

- Sprint ID: `CZH-S8`
- Objective: expand surface-contract seam usage to one additional bounded path
  while keeping behavior and ABI stable
- Commit budget before checkpoint: `5`
- Super-gate: `CZH-GATE-67`

## Ticket Order (`CZH-S8`)

1. `CZH-641`
2. `CZH-642`
3. `CZH-643`
4. `CZH-644`
5. `CZH-645`

## Current State

- `in_progress`: `CZH-641`
- `todo`: `CZH-642`, `CZH-643`, `CZH-644`, `CZH-645`
- `blocked`: none
- `review_gate`: none
- `done`: `CZH-B1`, `CZH-B2`, `CZH-B3`, `CZH-B4`, `CZH-B5` (accepted as a narrow hygiene slice), `CZH-B6` (accepted), `CZH-B7` (accepted), `CZH-B8` (accepted), `CZH-B9` (accepted), `CZH-B10` (accepted), `CZH-B11` (accepted), `CZH-B12` (accepted), `CZH-601`, `CZH-602`, `CZH-603`, `CZH-604`, `CZH-605`, `CZH-606`, `CZH-607`, `CZH-608`, `CZH-609`, `CZH-610`, `CZH-611`, `CZH-612`, `CZH-613`, `CZH-614`, `CZH-615`, `CZH-616`, `CZH-617`, `CZH-618`, `CZH-619`, `CZH-620`, `CZH-621`, `CZH-622`, `CZH-623`, `CZH-624`, `CZH-625`, `CZH-626`, `CZH-627`, `CZH-628`, `CZH-629`, `CZH-630`, `CZH-631`, `CZH-632`, `CZH-633`, `CZH-634`, `CZH-635`, `CZH-636`, `CZH-637`, `CZH-638`, `CZH-639`, `CZH-640`
