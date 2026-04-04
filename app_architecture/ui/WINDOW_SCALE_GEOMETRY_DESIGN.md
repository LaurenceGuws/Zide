# Window Scale Geometry Design

## Purpose

This is the exact authority for `WSG-0-01`.

It freezes:

- the public geometry contracts widgets are allowed to consume
- the renderer-private scale split beneath them
- the first `Shell` API deletion/narrowing decisions

This doc replaces vague "one geometry contract" language with the exact target
shape.

Related docs:

- [WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md](/home/home/personal/zide/app_architecture/ui/WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md)
- [UI_SCALE_GEOMETRY_SCRUTINY_2026-04-04.md](/home/home/personal/zide/docs/research/UI_SCALE_GEOMETRY_SCRUTINY_2026-04-04.md)
- [window_scale_geometry.md](/home/home/personal/zide/docs/todo/ui/window_scale_geometry.md)

## Core Decision

`WidgetLayout` remains the public pane/layout rectangle authority.

We are not introducing a second public layout tree.

Instead:

- `WidgetLayout` keeps owning pane rectangles
- one generic geometry context provides scale/layout policy shared by widgets
- one terminal-specific geometry context provides resolved terminal view truth

That is the simplest coherent contract from the current baseline.

## Renderer-Private Split

The renderer keeps a private normalization boundary between platform truth and
widget truth.

Exact private concepts:

- logical window size
- drawable pixel size
- content/display scale
- raster/backbuffer scale
- user zoom

Exact private responsibilities:

- decide layout scale
- decide raster scale
- decide font rebuild conditions
- decide render-target invalidation conditions
- decide device-pixel snapping policy

These values are not widget-facing by default.

## SDL Normalization Rule

The renderer-private split must obey SDL's actual high-DPI model from:

- `dev_references/sdlwiki_md/SDL3/README-highdpi.md`
- `dev_references/sdlwiki_md/SDL3/README-wayland.md`

That means the private boundary must keep these concepts distinct:

- logical window size
- pixel backbuffer size
- window pixel density
- window display scale

And it must treat these SDL events as meaningfully different:

- `SDL_EVENT_WINDOW_RESIZED`
  - logical layout/window size changed
- `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - drawable/backbuffer size changed
- `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
  - UI/content scale changed
- `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
  - display-coupled truth must be requeried

The app-wide normalization rule is:

- layout follows logical window size
- render targets follow pixel-size changes
- UI sizing follows display-scale changes
- display hops force one coherent requery of all display-coupled truth
- moved-only window events do not count as scale/geometry refresh by default

Widgets must not interpret these SDL events themselves.
Widgets only consume the already-resolved renderer contracts.

## Public Contract 1: `UiGeometryContext`

Exact target:

```zig
pub const UiGeometryContext = struct {
    window: shared_types.layout.Rect,
    ui_scale: f32,
};
```

Rules:

- `window` is the same logical window-space contract used by `WidgetLayout`
- `ui_scale` is the only generic scale value widgets may consume directly
- this contract is backend-agnostic
- this contract contains no drawable-size, pixel-density, display-scale, or
  render-scale vocabulary

Use cases:

- shared chrome spacing
- status bar, tab bar, side nav, top bar geometry
- editor overlay thickness and padding policy
- modal sizing and spacing

Non-use cases:

- device-pixel snapping
- drawable-size decisions
- backbuffer sizing
- text raster sizing

## Public Contract 2: `TerminalViewGeometry`

Exact target:

```zig
pub const TerminalViewGeometry = struct {
    viewport: shared_types.layout.Rect,
    origin_x: f32,
    origin_y: f32,
    viewport_width: f32,
    viewport_height: f32,
    rows: usize,
    cols: usize,
    cell_width: f32,
    cell_height: f32,
    baseline_from_top: f32,
};
```

Field intent:

- `viewport`
  - logical terminal pane rectangle as consumed by the widget layer
- `origin_x` / `origin_y`
  - resolved terminal-grid origin used by draw, hover, input, open, and mouse
    reporting
- `viewport_width` / `viewport_height`
  - resolved visible grid viewport in logical units
- `rows` / `cols`
  - currently drawable/published terminal grid extent for the active view
- `cell_width` / `cell_height`
  - resolved terminal cell size in logical units
- `baseline_from_top`
  - resolved baseline in logical units

Rules:

- this is the only widget-facing terminal geometry contract
- it is already coherent and already snapped where required by renderer policy
- terminal widget subsystems must not derive alternate origin/cell/baseline
  geometry from raw scale
- terminal runtime sizing must use the same inner viewport contract as draw
  does; it must not size against a larger outer pane height and then ask the
  widget to paint a smaller stripped terminal rect

Not included on purpose:

- `render_scale`
- `display_scale`
- `pixel_density`
- drawable size
- device-pixel cell metrics

Reason:

- those remain renderer-private
- if a renderer-owned subsystem needs device-pixel data, that can live in a
  renderer-private companion contract, not on the widget-facing one

## Diagnostics Contract

Debugging still needs raw visibility, but that must not leak into normal widget
code.

So the exact rule is:

- raw scale/display/drawable state may exist in a dedicated renderer diagnostic
  snapshot
- diagnostic access does not make those values part of the normal widget
  contract

This is the right home for:

- display scale
- pixel density
- drawable size
- render scale
- monitor size
- window/display migration traces

## `Shell` API Decisions

### Keep for now

- `Shell.uiScaleFactor()`
  - temporary survivor during migration
  - target state: most widget code should prefer `UiGeometryContext.ui_scale`
- `Shell.terminalCellGeometry()`
  - runtime-side survivor for terminal grid sizing and VT/PTTY cell metrics
  - not a normal widget geometry surface
  - widgets should still consume `TerminalViewGeometry`, not device-pixel cell
    metrics
- `Shell.terminalCellWidth()`
- `Shell.terminalCellHeight()`
  - temporary survivors only for diagnostics/logging compatibility
  - terminal grid sizing and VT resize must not depend on these rounded logical
    float getters anymore

### Delete from normal widget use

These are explicitly on the cut list:

- `Shell.renderScaleFactor()`
- `Shell.getDpiScale()`
- `Shell.getDisplayMetrics()`
- `Shell.getRenderSize()`
- `Shell.getScreenSize()`
- `Shell.getMonitorSize()`

Disposition:

- remove from normal widget/runtime geometry use
- if still needed for diagnostics, replace with one renderer diagnostic snapshot
  path instead of many public ad hoc getters

### Narrow heavily

- `Shell.refreshWindowMetrics(...)`

Disposition:

- not a normal widget geometry API
- may survive only as:
  - renderer/internal refresh path
  - explicit debug/diagnostic capture path

Widgets must not call it for regular geometry decisions.

## Forbidden Widget Inputs

After this design lands, widget code must not take:

- raw `render_scale`
- raw `display_scale`
- raw `pixel_density`
- drawable-size parameters
- public `snapToDevicePixel(...)`

If a widget/helper signature still needs those values, that is a design smell.

## Exact Migration Target By Area

### Generic UI widgets

Generic UI widgets should consume:

- `LayoutRect` / `WidgetLayout`
- `UiGeometryContext`

Examples:

- top bar
- status bar
- side nav
- tab bar
- editor overlays and spacing policy

### Terminal widget subsystems

Terminal widget subsystems should consume:

- terminal publication/view state
- `TerminalViewGeometry`

Examples:

- draw
- overlay
- hover
- pointer input
- mouse reporting
- hyperlink open
- debug view dump

### Renderer-only code

Renderer-only code may consume:

- private normalized scale state
- private device-pixel metrics
- private display/drawable truth

Examples:

- font sizing
- render-target sizing
- scene-target invalidation
- text raster quantization
- present diagnostics

## First Deletion Order

This is the intended first public-surface deletion order:

1. stop new widget code from using `Shell.renderScaleFactor()`
2. stop new widget code from using public `snapToDevicePixel(...)`
3. move terminal widget subsystems to `TerminalViewGeometry`
4. remove widget dependence on `Shell.refreshWindowMetrics(...)`
5. remove widget dependence on raw `Shell` display/render getters

The point is to cut the leak paths before cleaning residual helpers.

## Success Bar For Code Phase

The next code phase is correct only if:

1. terminal draw and terminal input consume the same `TerminalViewGeometry`
2. generic widgets consume `WidgetLayout` plus `UiGeometryContext`
3. no widget computes snapped origin from raw scale
4. no widget needs to know drawable size or pixel density
5. raw scale/display values move behind one diagnostic path instead of many
   public helpers
6. SDL event meaning stays distinct below the widget boundary instead of being
   collapsed back into generic "resize" behavior
