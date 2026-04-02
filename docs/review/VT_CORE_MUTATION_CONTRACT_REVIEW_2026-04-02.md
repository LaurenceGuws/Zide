# VT Core Mutation Contract Review

Date: 2026-04-02

## Current Read

The `vt-sprint` identity wave materially changed the public shape:

- `TerminalCore` is exported at the VT root
- immutable terminal content and metadata reads now route through
  [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- app/UI/FFI/workspace/replay consumers now speak
  [TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
  directly
- `PtyTerminalRuntime` is effectively boxed into VT-root compatibility residue
  plus the historical PTY-named regression file

That means the next blocker is no longer public naming.

## Strongest Remaining Contradiction

`TerminalCore` now looks credible for immutable host-facing reads, but it still
does not look sufficient for mutable host interaction.

The clearest examples are still exported from
[terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig):

- viewport / scrollback host actions from
  [content.zig](/home/home/personal/zide/src/terminal/core/session/content.zig)
- selection mutation and gesture helpers from
  [selection.zig](/home/home/personal/zide/src/terminal/core/session/selection.zig)

Those operations are not pure runtime-shell transport behavior.
They are user-facing terminal state changes.

The reason they still sit on `TerminalSession` is also clear:

- they mutate core-owned state
- they also need publication / view-refresh invalidation

So the real remaining contradiction is:

- `TerminalCore` looks like the engine for reads
- `TerminalSession` still looks like the necessary object for mutable
  host-facing terminal interaction

That is a more serious blocker to a credible `zide-vt` boundary than the old
`PtyTerminalRuntime` naming residue.

## Comparison Pressure

Against Ghostty / WezTerm pressure, the gap is no longer "too many wrappers."

The gap is:

- does the engine object own a coherent host-facing mutation contract
- or does the host still need the runtime/session aggregate to do normal
  terminal state interaction

Right now Zide is still closer to the second story.

## Best Next Move

Do not keep shaving naming residue.

The next `vt-sprint` step should be a deliberate design move around mutable
host interaction:

1. Define whether viewport/selection mutation belongs on `TerminalCore`
   directly, or on an explicit engine-adjacent mutation contract rooted in core
   truth.
2. Separate the mutation truth from publication invalidation choreography.
3. Only then cut the first whole mutable-host slab off
   `TerminalSession`.

Progress note, later on 2026-04-02:

- the first whole mutable-host slab has now moved in the selection lane
- higher-level host selection semantics now live under
  [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  via [terminal_core_selection.zig](/home/home/personal/zide/src/terminal/core/terminal_core_selection.zig):
  - range selection
  - ordered-range selection
  - click-selection expansion
  - gesture extension
  - cell/update selection helpers
- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig) is now narrower:
  - lock
  - call core-owned mutation truth
  - request publication refresh

That is the right split:

- mutation truth moved toward `TerminalCore`
- publication invalidation stayed outside it

The next same-class question is whether viewport / scrollback host mutation
should move the same way.

Progress note, later on 2026-04-02:

- the first viewport follow-through is now in too
- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns host-facing scrollback mutation verbs:
  - `maxHostScrollbackOffset(...)`
  - `setHostScrollbackOffset(...)`
  - `scrollHostScrollbackBy(...)`
- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  now uses those core-owned host verbs and keeps only:
  - lock
  - publication refresh
  - a small amount of UI-facing normalization

This is not the full viewport war yet, but it confirms the same split is
working there too.

Progress note, later on 2026-04-02:

- the live host callers no longer need the mutation facade hanging off
  `TerminalSession` for the common publication-aware paths
- widget pointer/keyboard/paste, scrollbar runtime, and FFI scrollback control
  now call the real session mutation owners directly:
  - [session/content.zig](/home/home/personal/zide/src/terminal/core/session/content.zig)
  - [session/selection.zig](/home/home/personal/zide/src/terminal/core/session/selection.zig)

That matters because the remaining value of the mutation facade on
`TerminalSession` is getting much thinner.

## Non-Goals

- no more alias churn just to reduce `PtyTerminalRuntime` mentions
- no random helper extraction from session mutation code
- no pretending the current mutation/publication coupling is already the right
  library boundary
