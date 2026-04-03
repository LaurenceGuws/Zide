# VT Core Scrolling Owner Design

Date: 2026-04-03

## Purpose

Define the first design bar inside the core owner-dependency front.

The target is scrolling-side owner dependency.

## Current Judgment

Scrolling is the first whole semantic slice worth attacking, but it is not a
safe blind refactor.

Why:

- scroll/newline/reverse-index behavior is central terminal semantics
- the current implementation still depends on outer owner shape
- but the dependency is not fake in only one way

It currently mixes:

- core screen/history mutation
- kitty placement mutation
- host cell metrics used for kitty dirty-region marking

## Live Mixed Line

Today these flows still terminate through owner-shaped helpers:

- `TerminalCore.newlineLocked(...)`
- `TerminalCore.wrapNewlineLocked(...)`
- `TerminalCore.reverseIndexLocked(...)`
- `scrolling.zig`

And `scrolling.zig` still reaches through outer owner shape for:

- kitty state
- kitty placement dirty marking
- host cell width/height

## Real Split

The honest split is not:

- "remove `owner` from scrolling signatures and call it solved"

The honest split is:

1. core owns scroll semantics and history effects
2. kitty placement effects become explicit side effects or explicit
   core-adjacent consumers
3. host cell metrics stay outside core truth unless they are passed as
   explicit inputs for kitty dirty marking

## Bar For Code

The first real code slice should only happen if it does one of these:

- makes scroll/history semantics run on core without hidden outer completion
- or separates kitty dirty/placement consequences into an explicit side-effect
  boundary

It should not:

- just thread `*TerminalCore` everywhere while still smuggling host metrics and
  kitty side effects through the same implicit path

## Decision

Scrolling stays the first owner-dependency target, but only as a design-first
front.

If a clean explicit side-effect shape does not emerge quickly, the next
subfront should fall back to parser feed owner dependency instead of forcing
scrolling by momentum.

## Progress

The first explicit side-effect cut is now landed.

What changed:

- `TerminalCore` now returns explicit scroll actions for:
  - newline
  - wrap-newline
  - reverse-index
- scrolling-side effects are consumed outside core through
  `scrolling.consumeScrollAction(...)`

Why this counts:

- this is not a cosmetic parameter removal
- it moves the semantic decision itself inward

What remains:

- kitty placement consequences and history scroll effects are still consumed in
  the outer scrolling path
- the next question is whether that remaining consumer is now honest enough or
  still hides another real owner dependency
