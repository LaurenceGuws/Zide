# VT Maturity Completion List

Date: 2026-04-03

## Purpose

Turn VT maturity purity into one explicit numbered completion list.

This list is the campaign exit criteria for the one continuous VT scrutiny war.

It exists to prevent:

- seam-hopping
- faux progress from tiny local wins
- redefining success every few commits

The war is not complete when we feel better about the code.

It is complete when we can honestly say the live Zide VT contract is no longer
clearly behind Ghostty and WezTerm in the dimensions that matter for a serious
library center.

## How To Use This List

1. Always work from the lowest-numbered incomplete item that is not blocked.
2. Only skip an item when a written note explains why a higher item is a true
   prerequisite.
3. Every code cut must name which numbered item it advances.
4. Do not declare VT maturity complete until every item is either:
   - completed
   - deliberately rejected with written reasoning that says why it is not
     required for peer-grade maturity

## Completion Criteria

### 1. `TerminalCore` must feel unquestionably like the terminal object

Completion test:

- a strong terminal maintainer can open
  [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  and immediately read it as the real terminal, not just the dominant inner
  engine
- major terminal-semantic operations no longer feel “completed elsewhere” by
  default
- the remaining outer-owner dependencies are obviously runtime,
  synchronization, or reporting only

Current pressure:

- deeper protocol execution maturity
- remaining owner-shaped completion around core behavior

### 2. `TerminalRuntimeShell` must survive only if it is irreducibly necessary

Completion test:

- every responsibility still living on
  [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  has survived hostile scrutiny and proved it cannot honestly move inward or
  outward without weakening the architecture
- nothing remains on the shell because it is historically shell-shaped
- if the shell still exists, it contains only irreducible:
  - synchronization
  - transport attachment / writer access
  - lifecycle / process ownership
  - runtime-dependent reporting that cannot belong to the terminal object
- if the shell can disappear entirely, that is preferable to preserving it
- hosts do not experience the shell as the real terminal API

Current pressure:

- assume the shell is guilty until each surviving responsibility is defended
- reject both cosmetic shell-thinning and sentimental shell preservation

### 3. Protocol execution must terminate on contracts that feel terminal-centered

Completion test:

- major protocol families no longer read like protocol-local semantic owners
- parser/protocol handling feels like it terminates on core-side semantic
  contracts, with runtime mechanics explicitly outside
- remaining protocol code in `src/terminal/protocol/` reads mostly like:
  - routing
  - framing
  - reply/report mechanics where appropriate

Current pressure:

- CSI input/reporting contract
- remaining parser-owner maturity questions

### 4. Input/reporting boundaries must be cleanly divided between terminal semantics and runtime reporting

Completion test:

- key, char, keypad, alternate-scroll, and other terminal-semantic host
  interactions are core-centered
- input protocol state is clearly separated from runtime-dependent reporting
  behavior
- host-reporting paths such as color-scheme, in-band resize, and kitty paste
  reporting no longer blur terminal protocol semantics and transport/reporting
  mechanics

Current pressure:

- remaining CSI reporting flags and reporting behavior

### 5. Public host contract must feel deliberate, boring, and normalized

Completion test:

- the host-facing VT contract teaches one clear story for:
  - immutable terminal truth
  - terminal-semantic mutation
  - runtime/transport
  - publication/export
  - reporting
- hosts are not taught two ways to think about the same capability
- breadth is acceptable only if the categories stay obvious

Current pressure:

- FFI/host edge normalization
- broad-but-honest contract shaping

### 6. Mutation and publication paths must read as terminal truth plus honest refresh ownership

Completion test:

- selection, viewport, feed/apply, and adjacent host-facing mutation paths no
  longer feel like session-era completion choreography
- when publication is involved, it reads like an explicit consumer of terminal
  effects, not hidden completion magic

Current pressure:

- mostly guardrail now
- only reopen if a fresh contradiction appears

### 7. Remaining protocol reply/report behavior must reinforce, not weaken, the library-center story

Completion test:

- reply sinks and writer/report paths are explicit enough that protocol
  semantics no longer feel shell-anchored by accident
- remaining reply/report mechanisms are justified by clear contract shape, not
  historical convenience

Current pressure:

- keep CSI reporting/reply work honest if it resumes

### 8. The host edge must not undermine terminal identity

Completion test:

- FFI handles, constructor story, and public naming reinforce the idea that
  the host is using a terminal library, not a shell-shaped object with a
  terminal hidden inside it
- the public edge does not make the shell feel like the real object

Current pressure:

- keep host-edge normalization under review as terminal maturity improves

### 9. Peer comparison must no longer show a clear first-glance loss

Completion test:

- against Ghostty:
  - Zide no longer loses clearly on engine/library-center clarity
- against WezTerm:
  - Zide no longer loses clearly on terminal-object maturity and sufficiency
- if differences remain, they read as:
  - taste
  - tradeoff
  - contract breadth choice
  not:
  - ownership confusion
  - unfinished object model
  - architectural cleanup in progress

### 10. The docs must be able to declare VT maturity victory without hand-waving

Completion test:

- we can write one short, defensible claim saying:
  - Zide’s VT contract is now peer-grade in the dimensions that matter
- that claim is backed by:
  - the numbered list above
  - direct comparison against Ghostty and WezTerm
  - no unresolved top-ranked contradiction that obviously undercuts it

## Sequencing Rule

Default execution order:

1. `TerminalCore` sufficiency
2. protocol execution maturity
3. input/reporting contract split
4. public host contract normalization
5. host-edge identity reinforcement
6. remaining reply/report and mutation/publication guardrail work
7. final peer comparison and victory audit

If a step is taken out of order, the owning note must say why.

## Bottom Line

This is the numbered list we march through sequentially.

The VT scrutiny war is complete only when this list is complete.
