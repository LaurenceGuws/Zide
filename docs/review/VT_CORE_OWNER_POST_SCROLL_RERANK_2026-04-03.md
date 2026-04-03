# VT Core Owner Post-Scroll Rerank

Date: 2026-04-03

## Purpose

Rerank the core owner-dependency front after the first scrolling slice.

## Current Judgment

Scrolling is no longer the default next contradiction.

Why:

- `TerminalCore` now owns the scroll decision for newline, wrap-newline, and
  reverse-index through explicit `ScrollAction`
- the remaining outer consumer is much narrower and more honest:
  - history push / scrollback consequences
  - kitty placement consequences

That remaining consumer is still worth watching, but it no longer looks like
the strongest maturity loss from this baseline.

## Next Stronger Contradiction

The next stronger owner-dependency contradiction is now parser feed.

Why:

- `TerminalCore.feedOutputBytesLocked(self, owner, bytes)` still terminates on
  parser execution through outer owner shape
- parser/protocol execution still reaches a broad session-shaped surface while
  consuming terminal semantics
- that is a more central loss to `TerminalCore` sufficiency than the remaining
  explicit scrolling consumer

## Decision

Park the scrolling front from this stronger baseline.

The next default owner-dependency front is:

- parser feed owner dependency
