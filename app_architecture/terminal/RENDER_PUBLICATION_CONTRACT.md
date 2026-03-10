Date: 2026-03-10

Purpose: define the backend contract for the next redraw/dirty-tracking lane so
we can improve `nvim`, gutters, scope guides, and dense full-screen redraw
workloads without re-entangling UI scheduling with terminal-core ownership.

This is not a "do optimizations now" doc. It is the contract target for the
later lane once VT core/session/transport separation is far enough along.

## Why This Needs Its Own Contract

Recent terminal work made the backend cleaner:

- `TerminalCore` now owns more real engine state
- transport/FFI host wake semantics are clearer
- PTY and no-PTY hosts now share a basic redraw wake contract

But redraw quality is still limited by backend publication shape:

- `view_cache` still blends projection, publication, and redraw policy
- dirty retirement still depends on presented-generation acknowledgement
- widget/runtime layers still participate in redraw choreography more than they
  should

That is why workloads such as:

- `nvim` line numbers and gutter updates
- scope-guide redraws
- `ascii-rain`
- repeated clear+redraw TUI patterns

still need a stronger backend contract before another optimization push.

## Reference Direction

Reference read, local snapshots:

- Ghostty:
  - wake renderer after stream/mailbox publication
  - renderer consumes terminal state plus explicit dirty state
  - scheduling and redraw wake stay outside the VT core, but visible-state
    transitions are authoritative
- Alacritty:
  - terminal/display dirty state is explicit
  - window redraw is requested after visible-state changes
  - per-frame damage is a renderer concern, but it is driven from terminal-side
    dirty truth, not guessed in the UI layer

The shared lesson:

- terminal/backend owns state change truth
- host/UI owns scheduling and actual drawing
- the seam between them must be explicit and narrow

## Current Zide Problems

### 1. Too many publication channels

Current redraw/publication decisions are influenced by:

- grid dirty state
- `output_generation`
- published render-cache generation
- presented generation
- `clear_generation`
- kitty generation
- visible-history generation
- view-cache pending state

This works, but it is easy for one path to drift.

### 2. `view_cache` carries policy, not just projection

`view_cache` currently does all of these:

- history + screen projection
- selection overlay projection
- kitty ordering sensitivity
- row-hash refinement
- viewport-shift publication support
- some full-vs-partial redraw choice

That is too much for one layer.

### 3. Renderer wake and renderer correctness are still too coupled

The FFI host path is now better:

- `redraw_ready` is a wake hint
- snapshot generation/damage remain authoritative

But the native widget/runtime path still carries more publication behavior than
we want long-term.

### 4. Presented-generation ack is still too structural

Presented-generation ack is valuable, but it currently has too much influence
over when backend damage is refined or retired.

That makes correctness sensitive to whether the renderer has caught up, which is
exactly where top-row starvation and stale-gutter bugs appear.

## Target Contract

### A. Backend owns three explicit states

1. Model dirty state
- authoritative mutation truth at screen/history/kitty level

2. Published view state
- stable render-facing snapshot/cache state
- includes generation + damage bounds + viewport context

3. Presented acknowledgement
- renderer feedback only
- used for retirement and optimization
- must not become a second correctness truth

### B. Host/UI owns only two things

1. Wake/scheduling
- frame requests
- redraw throttling
- coalescing

2. Drawing
- texture upload/update
- overlay rendering
- final presentation

The UI should not decide whether backend state is “really dirty.”

### C. Wake events remain advisory

For both FFI and native UI:

- wake events/hints say “fetch fresh published state”
- snapshot/render-cache generation + damage remain authoritative
- hosts may coalesce wakes, but must not invent redraw state

### D. Published state must stand on its own

The renderer/host should be able to answer:

- do I need to redraw?
- what bounds are dirty?
- is this a safe partial update?

without also consulting unrelated backend flags or side channels.

## Concrete Follow-Up Goals

### 1. Reduce publication inputs

Collapse the publication contract around:

- model dirty
- published generation
- published damage
- explicit full-dirty reason when applicable

Keep `presented_generation` as optimization/retirement feedback only.

### 2. Split `view_cache` into projection vs publication policy

Desired separation:

- projection/cache building
- publication decision
- damage refinement/retirement

These do not all need to live in one file or one owner.

### 3. Keep scroll/clear/alt/resize authoritative

Operations that must remain explicit publication events:

- resize reflow
- alt-screen enter/exit
- RIS/DECSTR
- clear-display full clears
- scrollback viewport movement
- kitty geometry/state changes that affect visible composition

These should stay backend-owned and explicit.

### 4. Make row-hash refinement strictly optional optimization

Refinement must never be allowed to override correctness when:

- presented generation is behind
- viewport context changed
- source damage already implies visible redraw

It should only narrow already-valid damage, never become the reason damage is
lost.

## Entry Criteria For The Lane

Start the redraw/publication lane when:

- VT core/session/transport split is stable enough that we are not moving the
  backend center every patch
- PTY and no-PTY host wake semantics are already explicit
- replay fixtures remain the regression authority

That is close, but not finished yet.

## First Implementation Order When This Lane Starts

1. Define one explicit published-state contract for native widget and FFI hosts.
2. Move damage/publication ownership out of ad hoc widget/runtime code.
3. Separate `view_cache` projection from publication-policy decisions.
4. Add targeted regressions for:
   - `nvim` gutter/line-number updates
   - scope-guide redraws
   - dense clear+redraw loops
   - scrollback-offset transitions
5. Only then tune partial texture update behavior.
