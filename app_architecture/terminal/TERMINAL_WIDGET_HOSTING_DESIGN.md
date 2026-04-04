# Terminal Widget Hosting Design

Date: 2026-04-04

## Purpose

Define the target shape for the native terminal widget stack under the current
VT maturity standard.

This is not a generic widget modularization doc.
It exists because the native terminal widget can still weaken VT maturity even
if `TerminalCore` itself gets cleaner.

If the widget only hosts Zide VT through a wide set of custom seams, then the
host side is still teaching the wrong story:

- not "here is a mature terminal object with a boring host contract"
- but "here is a special Zide terminal stack that happens to contain a VT"

That is unacceptable for the current comparison bar against Ghostty and
WezTerm.

## Related Authority

- [VT_MATURITY_PURITY_CAMPAIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md)
- [VT_MATURITY_COMPLETION_LIST.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md)
- [TERMINAL_SUBSYSTEM_LAYERS.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md)
- [TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md](/home/home/personal/zide/docs/review/TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md)
- [widget_scrutiny.md](/home/home/personal/zide/docs/todo/terminal/widget_scrutiny.md)

## Why This Counts As VT Work

This lane advances the main scrutiny war because it directly pressures:

- completion item 1
  - `TerminalCore` must feel unquestionably like the terminal object
- completion item 5
  - public host contract must feel deliberate and normalized
- completion item 8
  - host edge must not undermine terminal identity
- completion item 9
  - peer comparison must no longer show a clear first-glance loss

If native hosting still requires a mixed widget/session/render/present stack,
then the live terminal contract is still not peer-grade in practice.

## Core Standard

The native terminal widget must read like a host of terminal truth, not a
co-owner of it.

That means:

- terminal semantics stay terminal-owned
- publication truth is consumed through one read model
- renderer/presenter infrastructure is explicit
- widget-local input mapping is explicit
- debug capture is explicit

Not:

- a large shell object that stores whatever the terminal front currently needs
- draw branches each inventing their own cursor/cell policy
- input subfiles each reaching directly into different VT/session verbs
- retained surface policy hidden inside widget draw glue

## Ownership Zones

### 1. `TerminalWidgetController`

Own only pane-local widget state and host coordination:

- focus state
- hover state
- local drag gesture state
- pending open request
- recent input / blink pause state if it remains UI-owned

It may orchestrate work, but it should not be the long-term home of render,
damage, publication, or debug machinery.

### 2. `TerminalViewModel`

One read model derived from terminal publication/cache for the whole widget
front.

It should own:

- viewport truth
- visible rows/cols
- cursor truth
- draw-visible cells
- alt/sync/dirty state needed by the widget
- base colors and other display facts needed consistently by draw/input/debug

Rule:

- widget subsystems consume this model
- they do not each derive overlapping mini-views directly from `RenderCache`

Additional host-side rule:

- the widget shell should not directly own raw `RenderCache` lifetime and
  latest-capture preparation as loose fields/helpers
- if publication/cache storage must survive on the host side, it should live
  behind one explicit publication-state owner

### 3. `TerminalSurfacePresenter`

A named renderer/presenter subsystem for retained terminal surfaces.

It should own:

- retained texture lifecycle
- full vs partial redraw choice
- viewport shift policy
- partial damage plan
- scene-target invalidation interaction
- presentation feedback handoff

Rule:

- retained-surface planning is presenter infrastructure
- it must not live as folklore inside generic terminal widget draw glue
- widget-top-level kitty and retained state should not survive as unrelated
  fields if they are really one presenter-owned surface bucket
- retained readiness/generation/partial-plan bookkeeping should also be hidden
  behind that surface owner instead of being poked directly across presenter
  code

### 4. `TerminalGridPainter`

The terminal cell painter.

It should own:

- resolved cell color/style policy
- cursor-cell style overrides
- blink/reverse resolution
- direct vs shaped vs special vs fallback branch selection
- background and glyph draw sequencing for the grid itself

Rule:

- semantic cell style is resolved once
- optimized branches consume that resolved style
- they do not each re-encode cursor/background/foreground policy

### 5. `TerminalOverlayPainter`

The overlay layer above the grid.

It should own:

- cursor overlay painting
- selection overlay painting
- hover underline painting

Rule:

- overlay visuals must agree with grid semantics
- overlay files must not compensate for grid inconsistency with special local
  behavior

### 6. `TerminalInputAdapter`

Own host-input mapping into terminal actions.

It should own:

- keyboard mapping
- pointer/selection mapping
- mouse-report mapping
- ctrl-open hit-test mapping
- paste initiation policy

Rule:

- widget input consumes a smaller named terminal action contract
- leaf widget files should not each reach into different session/core verbs

### 7. `TerminalDebugCapture`

Own widget-specific diagnostic capture and dump formatting.

It should own:

- geometry/debug samples
- dump formatting
- draw-path probes

Rule:

- debug capture is allowed
- but it must not become the long-term identity of the main widget shell

## Hard Rules

### Rule 1: No direct `RenderCache` scatter

Outside the view model and explicit presenter/painter internals, widget code
must not keep deriving local truth directly from `RenderCache`.

### Rule 2: No semantic policy duplication across draw branches

Cursor-cell and resolved-cell visual policy must not be duplicated in direct,
shaped, special, and fallback paths.

### Rule 3: No hidden presenter logic in generic widget draw glue

Retained-surface planning and invalidation must read like presenter
infrastructure, not like one more branch inside a generic draw routine.

### Rule 4: No direct session locking in random widget leaves

If widget code still needs direct session locking, that should survive hostile
scrutiny as an explicit terminal action or presenter requirement.
It must not remain as incidental leaf behavior.

### Rule 5: File-size reduction is not the goal

This lane is complete only when the ownership story gets better.
Smaller files are incidental.

## Non-Goals

This lane is not:

- a renderer rewrite
- a VT semantic rewrite
- a casual switch to FFI-first hosting
- a “split files until they look modular” exercise
- an excuse to reopen already settled VT core lanes without a direct widget
  hosting contradiction

## Migration Principles

### 1. Introduce the read model first

Without a real `TerminalViewModel`, later cuts will just reshuffle helper
functions while keeping the same overlapping interpretations.

### 2. Split presenter infrastructure before painter micro-cleanup

Retained-surface and damage logic is a whole seam.
Take that seam whole instead of continuing to patch it from inside the draw
file.

### 3. Centralize cell style before more optimization

The draw-grid file must stop encoding cursor/cell policy differently in each
optimization branch before new hot-path work lands there.

### 4. Collapse input around actions, not around file size

The input side should end with a smaller action contract, not just a new set of
small files that still call the same scattered session/core verbs.

### 5. Move debug last unless it blocks a cleaner seam

The debug seams are useful.
They should move after the ownership model is clearer unless they are directly
blocking a cleaner design.

## Done When

This lane is done when a strong maintainer can read the native terminal widget
stack and think:

- this is a host of a mature terminal object
- this is not co-owning terminal semantics by accident
- retained terminal presentation is explicit infrastructure
- input is mapped through a coherent terminal action seam
- optimized draw branches are not semantic policy landmines

If it still reads like a custom Zide-only stack that knows too much about the
engine, this lane is not done.
