# Windows Snap Layout Interop

Date: 2026-03-20

Purpose: record the Windows-native design and closure evidence for Win11 Snap
Layout hover in the shared Windows maximize-hover seam without regressing the
accepted titlebar baseline.

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

The original missing piece was fully-correct native Win11 Snap Layout anchoring
on the maximize button.

The current implementation baseline is:

- a persistent native child sink now owns the shared maximize-hover seam used
  by terminal integrated chrome and editor/IDE titleband chrome
- Win11 Snap Layout hover now appears reliably from that sink on the local
  Win11 test box
- maximize click, drag, double-click maximize, right-click system menu, and
  `Alt+Space` stayed stable on that path
- the previously open defect was that the Snap flyout could occasionally first
  appear from the top-left of the monitor before settling into the correct
  maximize anchor

Current local state, 2026-03-22:

- the shared parent-HWND frame seam closed that remaining anchor defect on the
  local Win11 baseline
- user retest on terminal/editor/IDE accepted the fix and closed the item

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
- later host-specific diagnosis narrowed that further:
  - layered child sinks on this SDL/Win32 host fail creation
  - a transparent plain child sink succeeds
  - so the persistent sink seam stays correct, but the exact child-window style
    contract must follow the host instead of copying Windows Terminal flags
    blindly

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

The active cut now covers the integrated caption/button strip and owns:

- drag caption area
- minimize/maximize/close hit regions
- maximize hover for Snap flyout

This replaced the earlier split ownership path because the split seam kept
causing drift between app-side and Win32-side button state.

## Message Ownership Strategy

### Sink-owned

The sink owns:

- `WM_NCHITTEST` for the covered titleband/caption-button region
- native maximize hover anchor path
- non-client hover/leave tracking for the covered maximize zone
- caption button hover/press/release state

### Forward-to-parent

For plain drag-caption behavior and non-client right-click/double-click
messages, the sink forwards the appropriate caption/non-client messages to the
parent.

### Current note

The remaining defect is not “ownership missing”.

The remaining defect is anchor quality under the current otherwise-correct sink
seam.

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

## Investigation Record

The sections below capture the evidence trail that led to the final fix. They
remain here as authority for why the accepted seam owns both:

- the persistent child maximize-hover sink
- the shared top-level parent-HWND frame owner

## Current Investigation Findings

### Scope Correction

The remaining anchor defect is not terminal-only.

Current user-verified scope:

- terminal, editor, and IDE
- windowed and maximized
- no reliable special case isolates it
- trigger remains random on maximize-button hover

So this is a shared Windows maximize-hover issue in the shell-service seam, not
a product-specific terminal regression.

### Explorer/XAML Popup Host Evidence

The current probe work established the following on a bad repro:

- our maximize-button screen rect is already correct and stable before popup
  birth
- our native input path is already correct on the bad repro:
  - `WM_NCHITTEST -> HTMAXBUTTON`
  - `WM_SETCURSOR -> HTMAXBUTTON`
  - `WM_NCMOUSEMOVE -> HTMAXBUTTON`
- the popup is created by `explorer.exe`
- the relevant external windows are:
  - `Xaml_WindowedPopupClass` titled `PopupHost`
  - `XamlExplorerHostIslandWindow`
  - `Windows.UI.Composition.DesktopWindowContentBridge`

Observed bad sequence:

1. maximize hover enters on our sink with stable `HTMAXBUTTON`
2. Explorer creates `PopupHost` at `(0,0,0,0)`
3. `PopupHost` gets a first real location near top-left
4. only after that does Explorer/XAML move the popup host and island bridge to
   the correct maximize-anchor region

Representative bad repro sequence:

- `PopupHost` first visible rect:
  - `(-18,-4,620,459)`
- final correct popup rect:
  - approximately `(2120..2760, 726..1189)`

Conclusion:

- the remaining defect is not explained by stale maximize geometry
- the remaining defect is not explained by missing `HTMAXBUTTON`
- the remaining defect is not explained by missing `WM_SETCURSOR`
- the remaining defect is later in Explorer/XAML popup anchoring than the
  current sink message path

### Architectural Implication

The current persistent sink seam is sufficient to make Snap appear and to keep
maximize/caption behavior stable.

The remaining defect likely requires a deeper top-level frame/host alignment
change, closer to Windows Terminal's full non-client/custom-frame model, rather
than another small hit-test or hover-message tweak.

### SDL Host Hypothesis

The current Zide integrated windows still rely on SDL's Win32 borderless host
behavior at the top level:

- SDL borderless-windowed style defaults to a hybrid frame:
  - `WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX`
  - plus `WS_THICKFRAME | WS_MAXIMIZEBOX` for resizable windows
- SDL's Win32 event path also returns `0` from `WM_NCCALCSIZE` for borderless
  windows and manually substitutes monitor work-area behavior when maximized

That is materially different from Windows Terminal's host model:

- top-level window starts from `WS_OVERLAPPEDWINDOW`
- top-level message handler owns `WM_NCCALCSIZE`
- top-level frame margins are updated through
  `DwmExtendFrameIntoClientArea(...)`
- the drag-bar window is only one part of a fuller top-level custom-frame path

So the strongest current architectural hypothesis is:

- the remaining Snap popup birth defect is not in the child sink
- it is in the top-level SDL borderless host/frame semantics that Explorer/XAML
  is anchoring against

Current focused experiment:

- keep the accepted child sink seam intact
- force SDL's plain popup borderless style (`SDL_BORDERLESS_WINDOWED_STYLE=0`)
  across integrated windows
- then compare whether the `PopupHost` still births at `(0,0)` / top-left
  before settling

Result:

- no meaningful improvement
- our top-level window style changed, but Explorer still created `PopupHost`
  first at `(0,0,0,0)` and then near top-left before relocating it correctly

Interpretation:

- the remaining defect is not fixed by a simple SDL borderless-style toggle
- the top-level delta is deeper than style bits alone
- the next viable lane is a real top-level non-client/frame ownership cut, not
  more SDL hint tuning

Final effective cut:

- add a shared parent-HWND subclass for integrated windows
- own `WM_NCCALCSIZE` at the top level instead of leaving top-level non-client
  semantics entirely to SDL borderless handling
- apply explicit `DwmExtendFrameIntoClientArea(...)` top margins from that same
  parent-HWND seam
- keep the accepted child sink for maximize hover/button input unchanged

Closing result, 2026-03-22:

- immediate user retest on terminal and editor showed a strong improvement
- first 10 hover probes on each path were all good on the local Win11 machine
- follow-up user retest accepted the fix and closed the issue
- no top-left birth/teleport defect was observed in the closing runs

Interpretation:

- the first effective fix was top-level non-client/frame ownership, not another
  child-sink tweak
- this supports the earlier hypothesis that Explorer/XAML needed a more native
  top-level frame model than SDL borderless handling alone was providing

## Current Rollout State

1. A persistent sink type exists in the Windows shell/platform layer.
2. It is fed shared titleband/maximize geometry and activation state.
3. A shared parent-HWND frame owner now also owns top-level `WM_NCCALCSIZE`
   and DWM top-frame margins for integrated windows.
4. Snap hover is restored through the child sink on top of that frame seam.
5. Maximize click, drag, double-click, right-click, and `Alt+Space` stayed
   accepted on the local Win11 machine across terminal/editor/IDE.
6. The previously open top-left popup birth defect is closed on the current
   local Win11 baseline.

## Exit Result

`W9-06` is now closed on the current local Windows baseline.

Closing evidence:

- hovering the maximize button reliably shows Win11 Snap Layouts
- the popup anchor defect stopped reproducing after the parent-HWND frame owner
  landed
- maximize click still toggles correctly
- restore from maximized still works correctly
- drag/double-click/right-click/system-menu behavior remains accepted
- the failed probe scaffolding and no-effect SDL style experiment were removed

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
