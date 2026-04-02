# VT War 4 Scope And Seeds

Date: 2026-04-03

## Purpose

Define the full scope of the next `zide-vt` scrutiny pass from the current
post-`vt-sprint` baseline.

This is not another wrapper-cleanup queue.
The question is narrower and harder now:

- what still prevents [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  from reading like a sufficiently complete, swappable VT library center beside
  Ghostty and WezTerm?

## Current Baseline

The old local contradictions are already materially gone:

- `TerminalSession` is deleted from live code
- `PtyTerminalRuntime` is deleted from live code
- the live VT shape is now:
  - [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- immutable export, metadata, and activity truth moved materially closer to
  `TerminalCore`
- the remaining shell surface is much smaller and reads more honestly than the
  old session facade

That means War 4 is not about finding another fake file center by momentum.

## Full Investigation Scope

War 4 should cover the full VT-library question, but it should do so through a
small number of explicit comparison tracks:

1. Engine-object sufficiency
   - does `TerminalCore` feel like the unmistakable VT object?
   - if not, what exact host-facing capability slab still feels missing?

2. Runtime-shell legitimacy
   - does [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
     now read like an honest outer runtime/transport shell?
   - or does it still hide engine responsibilities?

3. Public/FFI host contract shape
   - is the remaining plug-and-play gap caused by shell dependence?
   - or is the contract simply richer and less normalized than Ghostty’s
     intentionally narrow `vt.h`?

4. Internal caller dependence
   - which in-repo callers still need the shell for legitimate runtime reasons?
   - which still depend on it out of habit or packaging convenience?

5. Mature-reference pressure
   - where do Ghostty and WezTerm still feel more "obviously terminal" than
     Zide at first glance?
   - does that imply a real missing `TerminalCore` capability, or only a
     stylistic difference we should not overfit to?

## Preliminary Master Read

The current live code suggests the remaining gap is probably not:

- obvious wrapper sludge
- obvious shell dishonesty
- obvious FFI incompleteness

The stronger possibilities are now:

1. `TerminalCore` still lacks one named host-facing capability or packaging
   slab that the references make feel engine-owned.
2. The shell is honest enough, but the host/public ABI is broader and less
   normalized than Ghostty's narrow `vt.h`, which weakens "plug-and-play"
   optics even if it is not architecturally wrong.
3. The remaining shell dependence in host/FFI paths is mostly legitimate:
   transport, liveness, lifecycle, foreground-process data, and publication
   synchronization.

That makes War 4 a design-comparison war, not a local cleanup war.

## Seed Prompts

These are the intended parallel scrutiny tracks.

### Track A: Ghostty engine-center comparison

Compare current Zide `TerminalCore` against Ghostty
[Terminal.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/terminal/Terminal.zig)
as a VT library center.

Focus:

- host-facing engine sufficiency
- object identity
- capabilities or state groupings Ghostty makes feel engine-owned

Reject:

- renderer/windowing differences
- generic style commentary

Deliver:

- concrete mismatches ranked by severity, with exact file references

### Track B: runtime-shell legitimacy

Compare Zide
[TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
against Ghostty
[Termio.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/termio/Termio.zig).

Focus:

- init
- locking
- transport/lifecycle
- what hosts must go through the shell for

Deliver:

- ranked findings with exact file references
- explicit statement if the shell now looks honest enough

### Track C: WezTerm maturity pressure

Compare current Zide VT center against WezTerm
[terminal.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)
and related terminal-state structure.

Focus:

- object-model sufficiency
- whether WezTerm still feels more obviously complete as "the terminal object"

Deliver:

- concrete mismatches only, or explicit statement that none are obvious

### Track D: public/FFI host contract shape

Review current Zide VT host-facing contract across:

- [src/terminal/ffi](/home/home/personal/zide/src/terminal/ffi)
- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)

Compare against Ghostty’s
[vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
and Zide’s embeddable goals.

Focus:

- shell dependence
- host-contract breadth and normalization
- whether the contract is genuinely a plug-and-play blocker

Deliver:

- ranked findings with exact file references

### Track E: internal caller dependence map

Survey in-repo callers of `TerminalRuntimeShell` versus `TerminalCore`.

Focus:

- which callers truly need shell/runtime behavior
- which still depend on the shell out of habit, packaging convenience, or
  boundary ambiguity

Deliver:

- one or two highest-payoff suspect call paths, ranked with file references

## What Counts As Success

War 4 should end with one of two explicit outcomes:

1. name one specific missing `TerminalCore` capability or contract slab and
   open the next code war on that
2. conclude that the remaining split is already honest enough, and that the
   remaining plug-and-play gap is mostly normalization/maturity rather than
   another obvious architecture contradiction

## What Should Not Happen

- reopening shell/query cleanup by momentum
- treating "broader than Ghostty" as automatically wrong
- copying Ghostty or WezTerm surface area mechanically
- inventing a new fake center just to make `TerminalCore` look bigger

## Bottom Line

The next serious question is no longer whether Zide has a fake VT center.

The next serious question is whether one specific missing `TerminalCore`
capability or host-contract weakness still blocks a credible `zide-vt` from
reading like a swappable library beside Ghostty and WezTerm.
