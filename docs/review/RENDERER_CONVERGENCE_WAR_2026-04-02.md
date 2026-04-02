# Renderer Convergence War 2026-04-02

## Purpose

Open the next architecture war after Terminal War 3.

## Current Target

The active battlefield is now renderer / scene / publication convergence.

The core question is:

- what still prevents the native renderer path from reading like one generic
  scene/publication model instead of a cleaner transitional mix?

## First Concrete Contradiction

The first concrete contradiction is retained-surface API shape.

Even after the earlier renderer cleanup wave, the retained-target owner still
spoke in product nouns:

- editor surface
- terminal surface

That is stronger product-shaped residue than the current contract should allow.

## First Cut

The first convergence cut is now landed:

- [retained_targets_runtime.zig](/home/home/personal/zide/src/ui/renderer/retained_targets_runtime.zig)
  now exposes one generic retained-surface contract:
  - `RetainedSurface`
  - `ensureSurface(...)`
  - `beginSurface(...)`
  - `endSurface(...)`
  - `surfaceAvailable(...)`
  - `drawSurface(...)`
  - `scrollSurface(...)`
- editor, terminal, and font-sample callers now use that generic surface API
  directly

## Current Judgment

This is the right opener:

- it cuts a real product-shaped renderer seam
- it does not invent a new fake owner
- it moves the native path closer to a generic scene/publication vocabulary

Follow-on convergence cleanup is still valid where older test or smoke tooling
keeps a second product-shaped retained-surface vocabulary alive.

Progress note, later on 2026-04-02:

- the editor scripted-input smoke harness now uses the same generic
  retained-surface terms (`ensureSurface`, `beginSurface`, `endSurface`,
  `drawSurface`) instead of its old editor-specific fake renderer verbs
- retained-surface update/blit counters in that harness now use generic
  retained-surface names too
- the retained-target owner now reports surface update/blit/end events to the
  scene-frame owner through generic retained-surface trace verbs instead of
  editor/terminal-specific trace helper names
