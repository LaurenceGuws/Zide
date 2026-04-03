# VT Host Contract Normalization

Date: 2026-04-03

## Purpose

Name the next broader VT scrutiny contradiction after the protocol-owner front
hit its stop-marker.

The question is:

- what now most directly keeps Zide behind Ghostty/WezTerm on VT maturity if
  the obvious local semantic centers are mostly gone?

## Current Judgment

The next contradiction is host-contract normalization.

Not because the contract is too broad in raw capability count.

But because the host edge still teaches too many categories through mixed
shell-shaped entrypoints instead of one unmistakably normalized story.

## Why This Beats Other Candidates

It beats:

- reopening shell survival
- reopening protocol-owner cleanup
- reopening reset
- vague "core still feels a bit heavy"

Because the core is much stronger now, but the host edge still answers too many
different questions through:

- `src/terminal/ffi/core_api.zig`
- `src/terminal/ffi/host_api.zig`
- `src/terminal/core/session/host_queries.zig`

That means the remaining maturity gap is now more likely contract quality than
inner ownership confusion.

## The Exact Contradiction

The host-facing VT contract is rich, but still not boring enough.

It still mixes:

- immutable terminal truth
- terminal-semantic mutation
- runtime transport/liveness
- reporting
- publication/export snapshots

across multiple entrypoint styles that still route through the shell in a way
that is often honest but not yet obviously normalized.

That is a maturity loss even if the behavior is correct.

## Why This Matters Against Peers

Ghostty pressures a narrower, clearer public story.

WezTerm pressures a terminal object that feels settled and deliberate.

Zide can still afford a richer contract than both, but only if the categories
stay unmistakable.

Right now the remaining risk is:

- not that the host contract lacks power
- but that it still feels historically accumulated instead of fully normalized

## Strongest Local Suspects

The strongest local suspects are:

1. mixed shell-facing FFI entrypoints in `host_api.zig`
2. read/query aggregation versus immutable core truth in `host_queries.zig`
3. snapshot/export and metadata edges in `core_api.zig`

## The Required Bar

The next move must not be:

- "make the ABI smaller"
- "copy Ghostty's narrow public header"
- "delete shell mentions cosmetically"

The required bar is:

- name one exact host-contract weakness
- show why it still weakens the normalized VT story
- only then cut code

## Decision

The next active VT front should be host-contract normalization unless a stronger
broader `TerminalCore` contradiction appears immediately from the same baseline.

## Progress

The first normalization slice is now landed.

What changed:

- terminal metadata and runtime metadata are no longer bundled together at the
  host query layer
- FFI metadata assembly now combines explicit categories instead of treating
  them as one pre-mixed blob

What this improves:

- the host edge now teaches a clearer distinction between:
  - immutable terminal truth
  - runtime status
  - activity state

That is the right kind of normalization progress: category clarity first,
public ABI churn second if still needed.

- the second normalization slice is now landed too
- `metadataAcquire(...)` is terminal-only now
- semantic activity moved to its own `activityAcquire(...)` surface
- runtime liveness/exit status remain on explicit runtime getters instead of
  being re-bundled through terminal metadata

That means the host edge now teaches three clearer categories directly:

- terminal metadata
- runtime status
- semantic activity

The next likely normalization weakness is now narrower:

- snapshot still duplicates title/cwd that already belong to terminal metadata
