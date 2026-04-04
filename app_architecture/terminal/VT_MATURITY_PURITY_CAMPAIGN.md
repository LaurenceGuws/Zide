# VT Maturity Purity Campaign

Date: 2026-04-03

## Purpose

This is the current terminal architecture authority for agents and
contributors.

It replaces seam-hopping and local cleanup momentum with one explicit
indefinite priority:

- chase VT maturity purity until `zide-vt` reads like a serious, reference-
  grade library center

This is not a sequence of little wars.
It is one continuous VT scrutiny war.
It remains the default architecture focus until we can honestly say the live
VT contract is at least as strong as our peer references in the dimensions
that matter for a serious standalone library center.

Campaign exit criteria now live in:

- [VT_MATURITY_COMPLETION_LIST.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md)

Future work should march through that numbered list sequentially instead of
inventing local victory conditions.

## Core Standard

The standard is no longer:

- "is there one more easy extraction?"

The standard is:

- does the live terminal stack read like a finished VT library center with a
  clearly incidental runtime shell around it?

More concretely:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  must read like the terminal
- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  is presumed guilty and must justify its existence under hostile scrutiny
- the public host contract must feel deliberate, boring, and normalized
- the remaining difference from Ghostty/WezTerm should become maturity/taste,
  not ownership ambiguity

## What Victory Looks Like

Victory is not "many good refactors."

Victory is this first-glance result:

1. a strong terminal maintainer opens `terminal_core.zig` and immediately feels
   "this is the terminal"
2. the shell either disappears or survives only as an irreducible runtime
   boundary after aggressive scrutiny
3. hosts drive terminal truth through a contract that cleanly separates:
   - immutable terminal truth
   - terminal-semantic mutation
   - runtime/transport
   - publication/export
4. `zide-vt` no longer reads like an architecture campaign in progress

## What Already Landed

The baseline is much stronger now:

- old fake centers are gone
- `TerminalSession` is gone
- `PtyTerminalRuntime` is gone
- immutable export/query truth moved toward core
- key/keypad/alternate-scroll/char semantic dispatch moved toward core
- feed/apply semantics moved toward core
- resize semantics moved toward core
- public resize contract is unified
- dead session mutation facades are gone

That means the remaining work is not broad cleanup.
The remaining work is now deeper and stricter.

## Full Scope Of Remaining Work

There are four remaining maturity categories.

### 1. Terminal object sufficiency

Question:

- is `TerminalCore` sufficiently complete that it feels like the terminal
  object beneath the shell?

This is now the main pressure.
It is not enough for core to own many facts.
It must also feel like the natural center of terminal semantics.

### 2. Public contract normalization

Question:

- does the host-facing VT contract read like one coherent design, not just a
  historically accumulated set of useful capabilities?

This does not mean "make it tiny like Ghostty."
It means:

- make the categories obvious
- keep runtime/transport consequences outside terminal truth
- avoid teaching two public stories for the same operation

### 3. Terminal-driving interaction ownership

Question:

- when a host drives terminal behavior, is it obvious which parts are terminal
  semantics and which parts are runtime/writer mechanics?

Recent input and resize work improved this a lot.
That lane should stay paused unless a future named semantic slab appears.

### 4. Mutation/publication maturity

Question:

- do host-facing mutation paths read like terminal truth plus honest refresh
  ownership, or like leftover session-era choreography?

Recent viewport/selection cleanup improved this a lot too.
That lane should also stay paused unless a new larger contradiction appears.

## Ranked Current Pressure

From the current baseline:

1. `TerminalCore` sufficiency and object maturity
2. public host-contract normalization where it still weakens that maturity
3. only then any newly discovered terminal-semantic interaction slab
4. only then any newly discovered mutation/publication lie

Current comprehensive scope authority:

- [VT_MATURITY_FULL_SCOPE_2026-04-03.md](/home/home/personal/zide/docs/review/VT_MATURITY_FULL_SCOPE_2026-04-03.md)
  is the ranked full-scope map for what still separates `zide-vt` from mature
  reference-grade library feel
- do not reopen local VT seams without showing where they rank in that matrix
- [VT_CORE_EXECUTION_CONTRADICTION_REVIEW_2026-04-03.md](/home/home/personal/zide/docs/review/VT_CORE_EXECUTION_CONTRADICTION_REVIEW_2026-04-03.md)
  is the current named category-1 contradiction inside `TerminalCore`
  sufficiency
- [VT_POST_EXECUTION_RERANK_2026-04-03.md](/home/home/personal/zide/docs/review/VT_POST_EXECUTION_RERANK_2026-04-03.md)
  records the new category-1 form after the execution-contract wave:
  mixed protocol interaction state
- [VT_PROTOCOL_INTERACTION_CONTRACT_WAR_2026-04-03.md](/home/home/personal/zide/docs/review/VT_PROTOCOL_INTERACTION_CONTRACT_WAR_2026-04-03.md)
  is historical evidence from one front inside the same VT scrutiny war
- host-side native widget pressure is also valid VT work when it directly
  weakens the library-hosting story:
  - [TERMINAL_WIDGET_HOSTING_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_WIDGET_HOSTING_DESIGN.md)
  - [widget_scrutiny.md](/home/home/personal/zide/docs/todo/terminal/widget_scrutiny.md)
  - [TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md)

## What No Longer Counts As Progress

These are guilty by default now:

- shell thinning for appearance
- shell survival justified only by history
- helper extraction without a stronger library-center story
- deleting wrappers that do not change first-glance architecture
- reopening already-flattened lanes just because they still have files
- broad "cleanup" without one named contradiction against the maturity goal

## Allowed Future VT Work

VT work should continue only under one of these two conditions:

1. one named deeper `TerminalCore` capability gap
2. one named contract/object-model weakness that directly weakens
   `zide-vt` maturity

Those are not separate wars.
They are fronts within the same continuous scrutiny campaign.

Not:

- "core still feels slightly insufficient"
- "the shell still feels slightly present"

But:

- one named capability
- one named contract weakness
- one named redesign question

## Mandatory Comparison Pressure

All future VT maturity work should be compared directly against:

- Ghostty / `libghostty-vt` for library-center clarity
- WezTerm for terminal-object maturity and settled systems taste

Use those references differently:

- Ghostty pressures "is this a serious VT library center?"
- WezTerm pressures "does this terminal object feel mature and complete?"

## Operating Rule For Agents

Before any new VT code cut, answer this in writing:

- what exact maturity contradiction does this remove?

If that answer is not precise, do not cut code.

If the answer is precise:

- design the replacement
- cut the full semantic slice
- validate hard
- update the authority docs

## Bottom Line

The repo should now treat VT maturity purity as the one indefinite primary
architecture war.

Do not call every ranked front a separate war.
There is one war:

- VT scrutiny until our VT contract maturity is no longer second-rate next to
  the peers we actually respect

Everything else is secondary unless it directly blocks that outcome.
