# VT Host Contract Post-Snapshot Rerank

Date: 2026-04-03

## Purpose

Re-rank host-contract normalization after the metadata/activity split and the
snapshot-versus-metadata duplication cut.

## Current Judgment

Host-contract normalization is materially healthier now.

The host edge now teaches clearer categories:

- snapshot: publication truth
- metadata: terminal metadata truth
- activity: semantic activity truth
- runtime getters: liveness / exit status

That means the old broad host-normalization contradiction is no longer the
default next front.

## What Changed

The two strongest mixed stories are gone:

1. metadata no longer mixes terminal truth, runtime state, and semantic
   activity
2. snapshot no longer duplicates title/cwd that metadata already owns

## Remaining Host-Edge Risk

The remaining host risk is narrower now.

If host normalization continues, the strongest likely pocket is:

- specialized latest-state surfaces that still overlap in purpose without
  being as explicit as the new metadata/activity/runtime split

The strongest examples are:

- `close_confirm_signals(...)`
- `is_alive(...)`
- `child_exit_status(...)`
- `activity_acquire(...)`

But this is not yet clearly a stronger contradiction than broader
`TerminalCore` maturity pressure.

## Decision

Host normalization should pause by default from this baseline.

The next VT front should reopen only if:

- one narrower host-edge overlap becomes clearly stronger than the remaining
  `TerminalCore` / protocol-execution maturity questions

Otherwise the next pressure is broader again:

- `TerminalCore` sufficiency
- overall library-object maturity
