# VT Host Snapshot Metadata Duplication

Date: 2026-04-03

## Purpose

Name the next exact host-contract normalization contradiction after the
metadata/activity split.

## Current Judgment

The next host-edge weakness is duplicated terminal metadata across two public
surfaces:

- `snapshot_acquire(...)`
- `metadata_acquire(...)`

Both can still answer title/cwd.

That weakens the normalized VT story because it teaches two public ways to
think about the same terminal truth.

## Why This Matters

This is not about shaving bytes.

It is about making the host contract boring and deliberate:

- snapshot should read as viewport publication truth
- metadata should read as terminal metadata truth

When title/cwd exist on both surfaces, hosts have to learn an unnecessary
duplicate story.

## Exact Contradiction

Snapshot still carries:

- `title_ptr/title_len`
- `cwd_ptr/cwd_len`

even though terminal metadata is now already explicit and narrower than before.

That means the contract still says:

- title/cwd are part of snapshot publication
- and title/cwd are part of terminal metadata

That is the next normalization lie.

## Required Bar

The next move should not be:

- broad snapshot redesign
- generic ABI churn
- helper-only cleanup behind the same duplicated public story

The next move should be:

- decide whether title/cwd belong only to terminal metadata
- if yes, remove them from snapshot directly in one coherent slice

## Decision

The next host-contract front should be snapshot-versus-metadata duplication
unless a stronger broader `TerminalCore` contradiction appears immediately.
