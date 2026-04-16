//! Android-native text interaction plan for the terminal host.
//!
//! Purpose: make a GPU-textured terminal feel like native Android text when the
//! user expects text interaction, without inventing a parallel Java text model.

# Android Text Interaction Plan

Purpose: define the Android-native selection/copy/paste integration plan for the
terminal host.

Owner docs:

- `docs/todo/android/implementation.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`

## Decision

Android owns text interaction chrome and gesture policy.

The shared terminal core owns:

- terminal text truth
- selection truth
- selected-text export
- selection highlight published in the render cache

Java must not invent:

- a duplicate text buffer
- a duplicate selection model
- fake Java-side copy text assembled from texture reads

## Product Goal

The terminal texture must smell like normal Android text when the user expects
text interaction:

- long press starts selection at the touched content
- Android shows the native floating text toolbar anchored to the selection
- copy/paste flows through Android clipboard integration
- future selection expansion uses Android-native affordances, not ad-hoc debug
  widgets

## Official Android Contract

For a custom view, the relevant Android contract is:

- `startActionMode(callback, ActionMode.TYPE_FLOATING)`
- `ActionMode.Callback2`
- `onGetContentRect(...)` to anchor the floating toolbar
- `invalidateContentRect()` whenever the anchored selection rect changes

That contract only gives toolbar positioning. Android does not automatically
provide TextView-grade selection handles or geometry for a terminal texture.
Those must be driven from terminal-owned selection truth.

## Ownership Boundary

Shared terminal/core ownership:

- selection start/update/finish/clear
- selected plain-text export
- render-cache selection rows/column spans
- future word/range expansion semantics

Android host ownership:

- long-press and drag gesture arbitration
- mapping touch coordinates to terminal cell coordinates
- floating toolbar lifecycle
- clipboard integration
- future native-style handles/magnifier overlays

## Required Native Bridge Shape

The Android bridge must expose terminal-owned state instead of forcing Java to
reconstruct it:

1. selection lifecycle verbs
   - clear selection
   - start/update/finish selection by terminal cell
   - select a finished range when Android already knows both endpoints
2. selection geometry/state query
   - whether a selection is active
   - selection anchor/content rect in viewport coordinates
   - enough range data to re-anchor the toolbar after scroll/resize
3. selection text export
   - selected plain text for clipboard copy

First cut can stay minimal:

- one finished selection rect for floating-toolbar anchoring
- selected plain-text export for `Copy`

It does not need full drag handles yet.

## Geometry Contract

Selection anchoring must be expressed in the same Android-owned viewport
authority already used for scrollback and IME:

- Java touch input resolves to terminal row/col using product viewport size and
  visible row count
- native selection geometry resolves back into that same viewport coordinate
  space
- no content-frame sizing, centering offsets, or texture-local hacks are
  allowed in the selection contract

## Implementation Queue

### `AT-A1` Floating Toolbar Anchor

Purpose:

- prove native Android floating text actions can anchor to terminal-owned
  selection truth without custom Java button surfaces

Acceptance:

- long press selects terminal content from shared selection truth
- Java starts `ActionMode.TYPE_FLOATING` with `ActionMode.Callback2`
- `onGetContentRect(...)` returns the current selected content rect
- no top action bar
- no permanent floating Java button
- toolbar survives normal redraws while the selected range stays valid

### `AT-A2` Clipboard Copy

Purpose:

- route `Copy` through Android clipboard using terminal-owned selected text

Acceptance:

- tapping Android `Copy` updates `ClipboardManager`
- pasted content matches terminal-owned selected plain text
- no cache-file hack if a direct bridge return is practical
- if the first cut needs a file bridge, it must be documented as temporary and
  replaced in the next queue item

### `AT-A3` Drag Expansion

Purpose:

- expand selection with Android-native interaction instead of desktop pointer
  emulation

Acceptance:

- selection can expand beyond the initial long-press word/range
- toolbar anchor updates through `invalidateContentRect()`
- gesture arbitration remains explicit against:
  - tap-based deselection
  - vertical scrollback drag/fling
  - pinch zoom
  - left-edge sidebar swipe

### `AT-A4` Paste

Purpose:

- route Android paste into the live shell/editor through the existing input
  bridge

Acceptance:

- Android paste action reaches PTY/editor input
- no Java-side terminal text mutation
- IME/input ownership remains stable after paste

## Do Not Do

- no custom Java top bars for copy/select actions
- no permanent floating action buttons
- no Java-owned transcript or mirror text buffer
- no desktop mouse-selection emulation as the mobile product answer
- no Android-local selection truth that can diverge from shared terminal state

## Current Baseline

`AT-A1`, `AT-A2`, and the first `AT-A3` baseline are now met.

What is proved:

- long press starts terminal-owned word selection from product-surface touch
  coordinates
- Java starts `ActionMode.TYPE_FLOATING` with `ActionMode.Callback2`
- `onGetContentRect(...)` anchors the floating toolbar from terminal-owned
  selection geometry
- `Copy` reads selected text directly from Zig through JNI and writes it to
  Android `ClipboardManager`
- `Copy` clears selection after the action completes
- IME visibility is no longer owned by product-surface tap; the assist bar owns
  explicit IME open/close
- drag expansion is live on device:
  - long-press selection can extend by drag
  - selection autoscroll now starts from the first/last visible row and ramps
    with distance outside the viewport
  - Android-owned handles now reuse that same shared selection/autoscroll path
- tap policy is now selection-scoped:
  - tap inside active selection: preserve selection
  - tap outside active selection: clear selection
- helper-chrome policy is now explicit:
  - active selection change hides only the floating toolbar
  - tap inside selection toggles the Android-owned helper chrome without
    mutating the Zig-owned selection highlight
- Java ownership is now explicit too:
  - `dev.zide.terminal.selection.SelectionController` owns Android-native
    selection mutation, handles, and autoscroll policy
  - `dev.zide.terminal.host.TerminalSurfaceHostController` owns the native
    SurfaceView host wiring
  - `dev.zide.terminal.host.TerminalChromeController` owns the Android assist-bar / sidebar / IME chrome policy
  - `ZideActivity` no longer owns duplicate selection state or
    selection index mutation helpers

What remains for the next cut:

- finish `AT-A3` polish around large-range selection ergonomics and helper UX
- `AT-A4` Android paste routed through the existing input bridge
- exact handle theming/animation polish only after the interaction contract is
  stable
