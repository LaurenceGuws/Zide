# `CZH-B6` Tickets

Sprint: `CZH-S1`  
Super-gate: `CZH-GATE-60`

## Execution Rules

- Execute tickets in order.
- One ticket per commit.
- Update `docs/todo/core/JIRA_BOARD.md` as ticket status changes.
- Stop only at `CZH-GATE-60` or a real hard blocker.
- No code behavior change in this sprint unless a ticket says otherwise. This is
  an architecture-freeze and audit sprint.

## Ticket List

### `CZH-601` Flatten the core lane around the real split

Goal:

- replace the vague hygiene-first framing with the explicit four-layer focus

Required outputs:

- `docs/todo/core/implementation.md`
- `docs/todo/core/JIRA_BOARD.md`
- `docs/todo/core/ENGINEER_ENTRYPOINT.md`
- `docs/AGENT_HANDOFF.md`

Done when:

- the queue, board, handoff, and engineer entrypoint all point at `CZH-B6`
- the four target layers are named consistently

### `CZH-602` Audit current terminal FFI ownership

Goal:

- classify current terminal FFI files into:
  - VT core FFI
  - optional PTY/session host seam
  - bridge/facade glue
  - current smell/misalignment

Required outputs:

- update the relevant terminal architecture doc(s)
- record explicit file list and ownership judgments in `implementation.md`

Done when:

- there is an explicit current-state file map for `src/terminal/ffi/**` and the
  closely-coupled runtime/session owners it depends on

### `CZH-603` Freeze editor backend FFI authority

Goal:

- tighten the editor FFI contract to the same level of explicitness expected
  from terminal FFI

Required outputs:

- update `app_architecture/editor/FFI_DESIGN.md`
- record explicit owner/non-goal notes in `implementation.md`

Done when:

- the editor FFI boundary is explicitly scoped against app/native routing and
  future host adoption

### `CZH-604` Define the terminal surface contract

Goal:

- define the shared host-initialized terminal surface layer proven by Android,
  but write it as a host-agnostic contract

Required outputs:

- update or add the relevant terminal/render authority doc(s)
- define:
  - what resource the host passes in
  - what Zide owns
  - what the host owns
  - what dirty tracking/publication contract exists

Done when:

- Android is clearly just one host implementation of the contract, not the
  contract itself

### `CZH-605` Cross-layer file inventory and non-goals

Goal:

- classify current files into target layers and freeze what this sprint will
  not solve

Required outputs:

- file inventory table
- explicit non-goals / deferred items

Done when:

- there is a clear keep/move/defer map for the first implementation sprint

### `CZH-606` Hard-rule audit: probe/debug residue

Goal:

- audit the `CZH-B6` layer set against the rule that main-branch product paths
  do not keep ad hoc probe/debug residue

Required outputs:

- file + symbol + classification table
- explicit removal queue for later implementation sprint

Done when:

- the engineer has a bounded list of probe/debug removals tied to the new layer map

### `CZH-607` Hard-rule audit: compatibility and fallback residue

Goal:

- audit the same layer set for compatibility shims, fallback paths, and legacy
  preservation leftovers that no longer deserve to exist

Required outputs:

- file + symbol + reason + recommended removal/collapse action

Done when:

- the later implementation sprint can remove/collapse residue without
  archaeology

### `CZH-608` Hard-rule audit: doc strings and locked functions

Goal:

- audit whether touched files have module doc strings and whether important
  functions have doc strings that match their actual responsibility

Required outputs:

- per-file doc string status
- important function doc string drift list
- keep/fix/remove recommendations

Done when:

- the first implementation sprint has an explicit doc-alignment queue rather
  than vague cleanup pressure

### `CZH-609` Shape the first implementation sprint

Goal:

- turn the audited split into the next execution sprint with bounded tickets

Required outputs:

- next sprint ticket file
- updated board state
- updated implementation queue

Done when:

- the next execution sprint is concrete enough that the engineer can run it
  without architecture drift

### `CZH-610` Finalize checkpoint and review gate

Goal:

- stop the sprint cleanly at the architect gate

Required outputs:

- `docs/todo/core/CZH_B6_CHECKPOINT.md`
- queue + handoff + engineer entrypoint synced to review gate

Done when:

- `CZH-GATE-60` is submitted for Architect review
