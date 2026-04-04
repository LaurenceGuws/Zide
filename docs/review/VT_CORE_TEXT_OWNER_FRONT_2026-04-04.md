# VT Core Text Owner Front

Date: 2026-04-04

## Purpose

Name and cut the remaining printable text slab that still made text execution
read like protocol-owned completion instead of
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
truth.

## Current Judgment

The next live `TerminalCore` sufficiency contradiction was text owner gravity.

The bad story was:

- printable codepoint and ASCII handling still lived in
  [terminal_core_text.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_text.zig)
  instead of on `TerminalCore`
- that helper still depended on protocol-owned completion for:
  - wrap-newline scroll consequences
  - insert-char mutation
- so even after older parser cleanup, printable text still did not read as a
  direct terminal-owned behavior

## Exact Line

The pressure was concentrated in:

- [terminal_core_text.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_text.zig)
- [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)
- local echo in [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)

## Required Bar

The move must not be:

- another wrapper move that still leaves text completion on the protocol side

It must:

- move printable text semantics onto `TerminalCore`
- keep scrollback and kitty consequences explicit and honest
- avoid pretending those outer consequences disappear just because text moved

## Progress

The first whole slab is now landed.

What moved onto
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig):

- printable codepoint write semantics
- printable ASCII-run write semantics
- wrap-newline consumption inside those text paths
- insert-mode char insertion inside those text paths

What changed:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns:
  - `writeCodepointLocked(...)`
  - `writeAsciiSliceLocked(...)`
- [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)
  now routes printable parser traffic directly through core-owned text verbs
- [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now uses the same core-owned text path for local echo
- dead helper owner is gone:
  - [terminal_core_text.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_text.zig)

Supporting contract changes:

- [scrolling.zig](/home/home/personal/zide/src/terminal/core/scrolling.zig)
  now accepts direct core ownership for scroll consumption
- kitty/common dirty-placement helpers now accept direct core ownership too,
  so text-side scroll consequences no longer require a protocol-shaped owner

## Current Read

This is a real `TerminalCore` sufficiency win:

- printable text now reads as direct terminal behavior
- parser dispatch is flatter again
- local echo no longer teaches a side text owner

The remaining outer consequences are more honest:

- scrollback history push
- kitty placement dirtiness/scroll effects

Those now read as explicit lower-level consumers of core-owned scroll actions,
not as reasons text had to stay protocol-owned.

## Decision

Do not reopen text ownership unless one stronger remaining text-adjacent
contradiction still clearly steals ground from `TerminalCore`.

The next default pressure returns to the broader `TerminalCore` sufficiency
rerank from this cleaner text baseline.
