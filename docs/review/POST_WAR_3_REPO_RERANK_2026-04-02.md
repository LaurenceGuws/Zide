# Post War 3 Repo Rerank 2026-04-02

## Purpose

Choose the next architecture war after closing Terminal War 3.

## Current Read

Terminal War 3 materially improved the terminal stack:

- publication is much flatter
- runtime is much flatter
- aggregate session shape is cleaner
- public root identity is cleaner

The remaining terminal gap is real but ambiguous:

- `TerminalCore` may still deserve a stronger owning role than "dominant field
  inside `TerminalSession`"

That is now a deliberate design question, not an obvious implementation-first
campaign.

## Cross-Lane Ranking

From the new baseline, the strongest immediate architecture battlefield is now:

1. Renderer / scene / publication convergence
2. Deeper terminal object-model design
3. Tactical correctness lanes only with live repros

## Why Renderer Wins Now

Renderer is no longer embarrassing at first glance, but it still carries a more
actionable remaining question than terminal does:

- can native scene assembly, subsystem publication, and renderer composition be
  made to read like one generic scene/publication model instead of a cleaner
  transitional mix?

That question is:

- real
- already documented
- implementation-reachable
- less ambiguous than a deeper `TerminalCore` sufficiency redesign

## Decision

Do not open Terminal War 4 yet.

The next war should pivot to renderer / scene / publication convergence from
the new terminal baseline.
