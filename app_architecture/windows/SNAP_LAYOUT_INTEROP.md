# Windows Snap Layout Interop

Date: 2026-03-20

Purpose: define the next Windows-native design for Win11 Snap Layout hover in
terminal integrated chrome without regressing the accepted titlebar baseline.

Use this with:

- `app_architecture/windows/CHROME_POLICY.md`
- `docs/todo/windows/implementation.md`
- `docs/research/terminal/WINDOWS_NATIVE_CHROME_REFERENCE_CROSSCHECK_2026-03-20.md`

## Problem Statement

Zide's current accepted Win11 terminal integrated chrome already supports:

- drag
- resize
- maximize/restore
- minimize
- pressed-state caption buttons
- double-click maximize
- right-click system menu
- `Alt+Space`

What is still missing is native Win11 Snap Layout hover on the maximize button.

The stable baseline today is:

- maximize click is app-owned and correct
- the maximize hover Snap flyout is absent

This is acceptable as a baseline, but it is not the final native-feel target.

## What Failed

The first spike tried to reintroduce Snap hover through narrow message/hit-test
handoffs on the SDL top-level window.

That was the wrong seam.

Observed failures:

- top-level `HTMAXBUTTON` handoff produced unstable maximize behavior and odd
  native artifacts
- a transient custom child sink created during sync/update attempts repeatedly
  failed `CreateWindowExW(...)` against the SDL parent HWND
- a plain `STATIC` child probe on the same parent succeeded, so the failure was
  in our sink design and lifecycle, not in child windows on SDL generally

Conclusion:

- Snap hover should not be reintroduced through more transient hit-test patches
- the next cut needs a persistent, explicitly-owned input sink like Windows
  Terminal's drag-bar window

## Design Goal

Add Win11 Snap Layout hover while preserving the accepted integrated terminal
chrome behavior.

That means the next design must satisfy all of these together:

1. maximize hover shows the Win11 Snap flyout
2. maximize click still works and restores correctly
3. drag/double-click/right-click/system-menu behavior does not regress
4. the implementation does not introduce parallel fallback stacks

## Reference Direction

### Windows Terminal

Windows Terminal is the primary reference for this exact seam.

The key idea is not "return `HTMAXBUTTON` somewhere".
The key idea is:

- create a dedicated persistent input sink over the drag/title region
- let that sink own non-client hit-test and hover/click semantics for the
  regions it covers
- forward caption-area messages to the parent where appropriate

### WezTerm

WezTerm is the quality/architecture reference:

- native mechanics belong in the window backend
- visual presentation remains app-owned
- the custom path should remain disciplined instead of turning into a growing
  pile of per-message hacks

## Proposed Architecture

### One Persistent Sink Per Window

Integrated terminal chrome should create one persistent native child HWND when
the window enters the integrated-chrome path.

It should not:

- be recreated every sync
- be attached/detached repeatedly during ordinary UI updates
- be treated as a speculative temporary probe

Lifecycle:

1. create once when integrated terminal chrome is enabled for a window
2. keep it alive with the window
3. resize/reposition it when titleband geometry changes
4. destroy it when the window or integrated chrome path is torn down

### Sink Ownership

The sink belongs to shared Windows shell services, not terminal backend code.

It should live under the Windows/platform/shell layer, not in terminal core.

The terminal product contributes geometry/policy inputs:

- drag band rect
- maximize button rect
- minimize/close rects if later needed
- whether integrated mode is active

But the native child HWND and its message handling are shell-service concerns.

### Covered Region

The first cut should cover only the integrated titleband region needed for:

- drag caption area
- maximize button hover for Snap flyout

It does not need to replace every caption path immediately.

The stable accepted behavior should remain app-owned until the sink proves it
can own more without regressions.

## Message Ownership Strategy

### Sink-owned

The sink should own:

- `WM_NCHITTEST` for its covered titleband region
- native maximize hover anchor path
- non-client hover/leave tracking for the covered maximize zone

### Forward-to-parent

For plain drag-caption behavior, the sink should forward the appropriate
caption/non-client messages to the parent when the pointer is in drag space.

### Still app-owned in first cut

The first persistent-sink pass should keep these stable paths app-owned unless
the sink design proves it can take them cleanly:

- maximize click execution
- minimize click
- close click
- right-click system menu
- double-click maximize

That preserves the accepted baseline while Snap hover is added back.

## Geometry Contract

The sink should consume one stable geometry snapshot from the terminal
integrated-chrome runtime:

- full titleband rect
- drag rect
- maximize rect
- DPI-aware pixel coordinates

This geometry should already be final device-pixel geometry by the time it
reaches the sink layer.

Do not make the sink recalculate layout policy from UI state ad hoc.

## Structural Rules

### Allowed

- replacing the current maximize-hover seam directly
- removing the old broken Snap experiment entirely
- introducing a persistent sink abstraction if it becomes the owning seam

### Not allowed

- keeping old transient attach/detach Snap code as dormant fallback
- multiple competing maximize-hover implementations
- product-specific Windows hacks copied separately into IDE/editor/terminal code

## Suggested Rollout

1. Introduce a persistent sink type in the Windows shell/platform layer.
2. Feed it only integrated-terminal geometry and activation state.
3. Restore Snap hover through that sink.
4. Verify maximize click, drag, double-click, right-click, and `Alt+Space`
   still match the current accepted behavior.
5. Only then decide whether more caption paths should migrate into the sink.

## Exit Criteria

`W9-06` is done when:

- hovering the maximize button reliably shows Win11 Snap Layouts
- the flyout anchors in the correct place consistently
- maximize click still toggles correctly
- restore from maximized still works correctly
- drag/double-click/right-click/system-menu behavior remains accepted
- no extra runtime fallback path remains from the failed spike

## Relationship To Future IDE/Editor Work

This sink design is a shared shell-service capability.

That does not mean IDE/editor should inherit terminal integrated chrome.

It means future IDE/editor titlebar command work may reuse the shell-service
layer if they later need native caption/titleband hosting, while still keeping
their own product policy.

## Bottom Line

The next Snap attempt should not be:

- another top-level `WM_NCHITTEST` tweak
- another per-sync child window experiment

It should be:

- one persistent Windows-native input sink
- owned by shell services
- fed by integrated terminal titleband geometry
- introduced as a clean replacement of the bad maximize-hover seam
