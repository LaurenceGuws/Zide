# VT Post Poll Publication Rerank

Date: 2026-04-04

## Purpose

Rerank the surviving parser-feed execution faces after the poll publication
contract and the removal of dead runtime compatibility residue from
`ProtocolExecution`.

## Current Judgment

The old runtime compatibility lie is materially gone.

`ProtocolExecution` no longer carries `session.runtime` as a generic session
face just because protocol code used to assume it.

What remains on the runtime side is now the explicit write/wake contract only:

- PTY/external transport write access
- writer mutex
- IO wake signaling

That is much closer to honest irreducible runtime boundary than the old mixed
runtime residue.

## Publication Rerank

Publication has now lost four coherent contracts on the execution surface:

1. synchronized updates
2. parsed-output publication
3. pending-refresh / poll publication cadence
4. the leftover parsed-output idle/poll residue

That makes the remaining publication question narrower again:

- either one genuinely new publication contract still exists
- or publication is no longer the default next execution-face contradiction

## Decision

The next honest move is a fresh execution-face rerank from this baseline.

Do not assume publication still wins by inertia.

If no new coherent publication contract can be named quickly, the default next
pressure should move off execution-face cleanup and back to the broader
`TerminalCore` sufficiency question.
