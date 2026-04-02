# Terminal War 2 Post-Omission Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the reopened present-omission bug hunt was found to be
stale.

The bug-hunt wave still landed useful hardening:

- focused terminal mode now emits the same present summary logs
- sync-update retained-surface reuse now proves retained-surface availability
  before early return
- partial retained-surface update aborts fall back to the previous retained
  surface instead of returning blank
- stale retained-surface readiness is cleared when the target is absent

But the user confirmed the original disappearing-terminal idle-frame bug had
already been resolved before this lane was reopened.

That means War 2 should not continue to orbit this bug by momentum.

## Current Read

The present omission lane should now be treated as closed unless a fresh live
repro proves otherwise.

So the top-level question becomes:

- what is the strongest remaining terminal quality gap after
  - the present-invariant wave
  - the post-present publication-boundary wave
  - the host-aggregation wave
  - the first widget/retained-render wave
  - the first parser/text wave
  - and the stale omission bug cleanup

## What This Means

The next terminal move should come from a fresh top-level rerank, not from:

- more present-omission hunting
- more widget-draw surgery by momentum
- reopening already flattened War 2 micro-lanes

## Best Next Question

Against the live code and the strongest local references:

- what still looks second-rate at first glance in the terminal stack?

More concretely:

- engine/publication/native host clarity
- retained-render/widget clarity
- parser/protocol/semantic boundary quality
- any correctness lane with a still-live repro

## Bottom Line

The omission bug no longer deserves to drive War 2.

War 2 should now be reranked from the top again.
