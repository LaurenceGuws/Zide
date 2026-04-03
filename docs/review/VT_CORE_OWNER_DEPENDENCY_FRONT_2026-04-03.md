# VT Core Owner Dependency Front

Date: 2026-04-03

## Purpose

Name the next exact `TerminalCore` sufficiency contradiction after the host
contract normalization wave.

## Current Judgment

The next active contradiction is owner-shaped completion around core
semantics.

`TerminalCore` is much stronger than before, but major terminal behaviors still
depend on an outer `owner` context to become complete:

- parser feed/application
- scroll/newline/reverse-index behavior
- erase/reset-adjacent side effects
- kitty/screen scroll consequences

## Why This Beats Other Candidates

It beats:

- reopening host normalization immediately
- reopening shell cleanup immediately
- farming another local helper file for scraps

Because the host edge is materially clearer now, while core semantics still
show this pattern:

- `TerminalCore` decides some of the behavior
- but outer owner context is still needed to finish the operation

That still weakens first-glance maturity against Ghostty/WezTerm pressure.

## Exact Contradiction

The live examples are visible directly in
[terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- `feedOutputBytesLocked(self, owner, ...)`
- `resizeLocked(_, owner, ...)`
- `eraseDisplayLocked(self, owner, ...)`
- `newlineLocked(self, owner)`
- `wrapNewlineLocked(self, owner)`
- `reverseIndexLocked(self, owner)`
- `resetState(self, owner)`

Those operations do not all fail the maturity bar equally.

But together they show the same deeper problem:

- terminal semantics still rely on outer owner shape for parser execution,
  scrolling side effects, selection clearing, kitty consequences, or reset
  completion

## Strongest Subfronts

From the current baseline, the likely kill-order is:

1. scrolling-side owner dependency
2. parser feed owner dependency
3. reset / kitty owner dependency

Why this order:

- scrolling is broad, central terminal behavior and still visibly owner-shaped
- parser feed is likely the deeper technical blocker, but also the riskier cut
- reset/kitty may shrink naturally once the earlier two become clearer

## Required Bar

The next move must not be:

- cosmetic removal of `owner` parameters while hiding the same dependency
- broad helper extraction with no ownership change
- one more local protocol cleanup that leaves core completion shaped the same

The next move must be:

- one whole semantic slice that reduces a real outer-owner dependency

## Decision

The next default VT front should be core owner dependency, starting with
scrolling-side owner dependence unless a deeper parser slice proves cleaner
immediately.

## Progress

The first owner-dependency slice is now landed.

What changed:

- `TerminalCore` newline/wrap-newline/reverse-index no longer take outer
  `owner` just to decide their scroll consequence
- they now return explicit `ScrollAction`
- outer scrolling code consumes that action explicitly

What this improves:

- core now owns more of the semantic decision
- outer owner shape is more clearly side-effect consumption, not hidden
  completion

What remains open:

- the scroll consumer still owns kitty/history side effects
- so scrolling is improved, not finished
