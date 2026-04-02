# VT War 4 Keychar Decision

Date: 2026-04-03

## Purpose

Decide whether the new key/char design work is strong enough to reopen War 4
for code.

## Decision

Do not reopen War 4 for code from this baseline.

## Why

The key/char lane did produce a real design target:

- semantic dispatch before writer encoding

And it produced a plausible result family:

- key intent
- char intent
- keypad intent
- suppression
- local fallback intent

But the live code still fails the stricter bar for a clean War 4 move.

## The Blocking Ambiguity

The blocker is local fallback behavior, especially ANSI mode `12` local echo.

From the live code:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  chooses local char echo specifically when no writer exists
- the fallback is terminal-ish in effect because it mutates terminal content
- but it is still selected on a transport/runtime condition

That means the line is still not crisp enough:

- if core owns that fallback decision, transport absence leaks into core
  semantics
- if shell owns that fallback decision, the remaining move becomes smaller and
  less obviously a meaningful War 4 ownership win

## What This Means

The current key/char path is not like the two successful War 4 wins:

- output feed / apply
- resize / report contract

Those moved one clearly terminal-semantic verb onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
while leaving locking/publication/transport outside.

The key/char lane does not yet offer that same clarity.

## Current Judgment

War 4 is still legitimately closed.

The key/char work improved the design picture, but it did not expose a code cut
clean enough to meet the bar.

If this lane is reopened later, it should be because one of these becomes
explicit and defensible:

- local fallback can be modeled as shell execution over a fully terminal-owned
  semantic result
- or local fallback is deliberately declared outside the War 4 ownership goal,
  leaving one remaining semantic slice that is still large enough to matter

## Bottom Line

The honest answer is:

- key/char semantic dispatch is the only plausible next lane
- but it is still not clean enough to justify code
- War 4 should remain closed from the current baseline
