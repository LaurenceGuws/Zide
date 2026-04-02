# VT Input Semantics War

Date: 2026-04-03

## Purpose

Open the next VT-focused war directly on the top blocker from the plug-and-play
gap matrix:

- host-driving input semantics are still too shell-centered

This is not a generic input cleanup queue.
It is a focused design/ownership war about what should feel terminal-owned
versus shell/transport-owned.

## Why This Is The Next War

From the current comparison baseline:

- `TerminalCore` is now credible as the engine center
- `TerminalRuntimeShell` is now mostly honest as the outer shell
- publication/runtime sludge is no longer the blocker

The biggest remaining gap versus Ghostty and WezTerm is now:

- hosts still talk to the terminal primarily through
  [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  instead of through a more obviously terminal-owned semantic interaction
  contract

## Live Battlefield

Primary files:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [key_encoder.zig](/home/home/personal/zide/src/terminal/input/key_encoder.zig)
- [input.zig](/home/home/personal/zide/src/terminal/input/input.zig)
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
- [terminal_widget_keyboard.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_keyboard.zig)

Current shape:

- semantic input-mode decisions
- key/char mapping
- writer selection and availability
- protocol encoding
- raw writer calls
- local echo fallback

all still meet in one broad shell-facing lane

## What This War Is Not

Do not turn this into:

- a shell-thinning vanity pass
- a writer/transport rewrite
- a broad rename of input modules
- a cosmetic move of `sendText` / `sendBytes`

Those do not solve the plug-and-play blocker.

## Ranked Sub-slabs

### 1. Key/char semantic dispatch before encoding

Why first:

- this is the only sub-slab that still plausibly moves the contract toward a
  more terminal-owned story
- it is where app-cursor fallback, key-mode gating, ctrl/alt char fallback,
  and repeat handling still feel more semantic than transport-shaped

Current blocker:

- local echo fallback is still selected on writer absence, so the line between
  terminal semantics and shell mechanics is not yet crisp enough

Progress, later on 2026-04-03:

- the key-action-only slice is now landed
- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns the semantic key-action dispatch decision
- new owner module:
  [terminal_core_key_dispatch.zig](/home/home/personal/zide/src/terminal/core/terminal_core_key_dispatch.zig)
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now routes both `sendKeyAction(...)` and
  `sendKeyActionWithMetadata(...)` through that one core-owned decision
- this keeps:
  - repeat suppression
  - app-cursor fallback selection
  terminal-owned
- while leaving:
  - lock acquisition
  - writer selection
  - protocol encoding
  shell-owned

What remains blocked:

- char dispatch still carries the local-echo ambiguity
- keypad and broader input/reporting still need their own honesty test

Progress, later on 2026-04-03:

- keypad-action dispatch is now landed too
- the same owner module,
  [terminal_core_key_dispatch.zig](/home/home/personal/zide/src/terminal/core/terminal_core_key_dispatch.zig),
  now also owns keypad semantic dispatch
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now routes `sendKeypadAction(...)` through that core-owned decision
- this keeps:
  - repeat suppression
  - press-only keypad emission
  - app-keypad mode use
  terminal-owned
- while leaving:
  - lock acquisition
  - writer selection
  - protocol encoding
  shell-owned

What remains blocked now:

- char dispatch still carries the local-echo ambiguity
- broader reporting/mouse/text lanes are still transport-shaped unless proven
  otherwise

Progress, later on 2026-04-03:

- alternate-scroll mapping is now landed under the same semantic owner
- [terminal_core_key_dispatch.zig](/home/home/personal/zide/src/terminal/core/terminal_core_key_dispatch.zig)
  now decides whether a wheel step becomes terminal arrow-key intent
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now routes `reportAlternateScrollWheel(...)` through that core-owned decision

What this moved:

- alternate-scroll mode gating
- alt-screen gating
- arrow-key intent selection

What still stayed outside core:

- the actual key emission path
- lock acquisition
- writer selection
- protocol encoding

Progress, later on 2026-04-03:

- char-action dispatch is now landed too
- [terminal_core_key_dispatch.zig](/home/home/personal/zide/src/terminal/core/terminal_core_key_dispatch.zig)
  now owns:
  - repeat suppression
  - local-echo eligibility
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  now routes both `sendCharAction(...)` and
  `sendCharActionWithMetadata(...)` through that core-owned decision

What this resolved:

- core no longer needs to know whether a writer exists
- shell still decides whether missing writer actually triggers fallback
- local echo is now treated as:
  - terminal-owned eligibility
  - shell-owned execution when no writer path is available

What still remains out of scope:

- raw text/byte send
- mouse reporting
- focus/color-scheme reporting

### 2. Broader host-driving input semantic contract

Examples:

- keypad semantics
- alternate scroll-wheel mapping
- possibly some focus/reporting meaning if it can be separated from raw write
  mechanics

Why second:

- this only makes sense after the key/char line is cleaner

### 3. Public resize/input story convergence

Why third:

- once input semantics are cleaner, resize should be judged by the same bar:
  terminal semantic verb on core, shell transport/reporting outside it

This is not part of the immediate code war.

## Design Bar

Any move in this war must preserve this line:

- terminal-owned semantic decision
- shell-owned locking, writer access, transport selection, and protocol
  encoding

If a move drags writer/transport mechanics into
[TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig),
it is the wrong move.

## Initial Judgment

The first real objective is still not code.

It is:

- define whether key/char semantic dispatch can be represented as one coherent
  result shape without smuggling writer absence into core semantics

If that answer stays muddy, this war should stop quickly rather than pretending
the input lane is cleaner than it is.

## Bottom Line

The next uninterrupted VT focus is now explicit:

- input semantics war

And inside that war, the only honest opener remains:

- key/char semantic dispatch before encoding

Current state:

- key-action dispatch is now a real first slice
- keypad-action dispatch now follows the same pattern
- alternate-scroll mapping now follows the same pattern
- char-action dispatch now follows the same pattern too
- broader reporting/text-send lanes are still not automatic from these wins

## Post-Char Rerank

After landing key, keypad, alternate-scroll, and char semantic dispatch:

- the remaining `session/input.zig` surface is no longer the same class of
  contradiction
- `sendText(...)` and `sendBytes(...)` read as direct writer verbs
- `reportFocusChanged(...)` and `reportColorSchemeChanged(...)` read as
  explicit shell/reporting paths
- `reportMouseEvent(...)` remains tightly coupled to writer protocol encoding
  and interaction-side mouse state

That means the remaining input lane is now mostly:

- writer-shaped
- reporting-shaped
- or explicitly shell/runtime-shaped

not a clean terminal-semantic ownership lie.

So this war should now stop from the stronger baseline unless a new input slab
appears that is both:

- terminal-semantic in substance
- separable from writer selection, protocol encoding, and transport/reporting

## Current Stop Marker

Landed semantic wins:

- key action dispatch
- keypad action dispatch
- alternate-scroll mapping
- char action dispatch

Out-of-scope / not-clean-enough continuations from this baseline:

- raw text/byte send
- mouse reporting
- focus reporting
- color-scheme reporting

Those are not being left untouched out of caution.
They are being left untouched because, from the live code, they no longer
look like the same plug-and-play blocker this war was opened to solve.
