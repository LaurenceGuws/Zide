# Terminal War 2 Re-Rank 2026-04-02

## Purpose

Close the first terminal architecture war as a coherent campaign and define the
next battlefield from the live codebase.

This is not another micro-review of the recently flattened seams.
It is the handoff from:

- destroy obvious false centers

to:

- identify the next top-level terminal architecture enemy

## War 1 Closure Read

The first war achieved its goal.

Major wins are now real in the code:

- `terminal_runtime.zig` is no longer the old fake public center
- publication/frame pacing/helper duplication is materially flatter
- widget/publication handoff is materially cleaner
- `workspace.zig` is much closer to a real tab/poll aggregate
- visible-terminal host routing is flatter and more direct
- the native terminal path reads much more like a host over one engine truth

Most importantly:

- the recent local host and publication seams now show diminishing returns
- continuing to grind those same files by momentum is now more likely to
  create cosmetic cleanup than architecture improvement

That is the right boundary for closing War 1.

## What War 1 Did Not Finish

Closing War 1 does not mean terminal architecture is complete.

It means the old enemy set is no longer the best place to spend effort.

The remaining question is now broader:

- what still prevents the full terminal system from reading as reference-grade
  at first glance when compared to the strongest terminal implementations?

## Current Comparison Pressure

From local `dev_references`:

- Ghostty still wins on making the engine/library center feel obvious and
  structurally inevitable
- Foot still wins on native present/damage/commit clarity
- Kitty still pressures backend ownership and refusal to hide behind soft
  indirection

Zide improved materially in War 1, but the new gap is less about thin wrapper
residue and more about top-level clarity.

## Current War 2 Candidate Questions

### 1. Is the engine/publication/native-host story now actually first-glance clear?

This is the strongest candidate.

The local seams are cleaner now, but the top-level story still needs a fresh
judgment:

- engine truth
- publication truth
- native host truth
- renderer/present truth

The next war should begin only after that whole shape is compared again
against the references.

### 2. Does `terminal_publication.zig` still represent the heaviest remaining center outside the engine?

Publication helper hunting is mostly exhausted.
But publication may still be the next large structural weight if, at top
level, it still reads like a broad truth center that wants one sharper split.

This should be judged as a whole-file/system question, not by one-function
ownership nudges.

### 3. Is present/render correctness now the next real battlefield?

If the architecture rerank shows no new large ownership lie, the next war may
need to pivot from structure to correctness:

- native present discipline
- redraw/damage correctness
- retained terminal texture truth
- Wayland-present edge cases

That would be a different war than War 1, and should be named as such.

## Recommended War 2 Start

Start War 2 with a fresh top-level terminal architecture review covering:

- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
- `src/terminal/core/publication/`
- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_host.zig`
- `src/app/terminal/`
- `src/ui/widgets/terminal_widget.zig`

And compare that live shape directly against the strongest local references.

## Current Judgment

War 1 should be considered closed.

War 2 should begin from:

- fresh top-level rerank
- reference pressure first
- no inherited momentum from the old micro-lanes

## Bottom Line

The first terminal war succeeded because it stopped tolerating false centers.

The second terminal war should begin only after asking a harder question:

- now that the obvious lies are flatter, what still looks second-rate when a
  strong terminal maintainer opens the full system?
