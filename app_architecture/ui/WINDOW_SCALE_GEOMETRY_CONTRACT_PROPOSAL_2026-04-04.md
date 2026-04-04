# Window Scale Geometry Contract Proposal 2026-04-04

## Status

This is a high-level proposal for discussion, not yet an approved TODO queue.

It exists because the current codebase still leaks SDL/backend scale behavior
into widgets and terminal view code. The goal is to replace that with one
boring, deterministic geometry contract.

For the exact frozen contract and API cut list, see:

- [WINDOW_SCALE_GEOMETRY_DESIGN.md](/home/home/personal/zide/app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md)

## Goal

Widgets should consume one resolved geometry contract, not backend scale
mechanics.

In concrete terms:

- widgets should know their resolved logical geometry
- terminal widgets should know their resolved terminal-grid geometry
- widgets should not know:
  - `display_scale`
  - `pixel_density`
  - `render_scale`
  - drawable size
  - SDL high-DPI behavior
  - Wayland/X11/Windows-specific scaling differences

## Core Position

SDL/backend scale handling should be private implementation detail.

The public UI contract should be:

- singular
- renderer-owned
- deterministic
- app-wide

Not:

- part renderer
- part shell
- part widget-local snap math

## Design Principles

### 1. One raw backend boundary

Keep raw SDL/backend truth acquisition in one place only:

- `src/platform/display_metrics.zig`

That layer may know about:

- logical window size
- drawable pixel size
- display index
- display content scale
- pixel density
- platform-specific caveats

No widget should know any of that directly.

### 2. One renderer-private normalization layer

The renderer should own one private normalization step that turns raw platform
truth into internal renderer truth.

That internal layer should decide:

- which values affect layout
- which values affect raster/backbuffer sizing
- which values affect target invalidation
- which values affect font rebuilds
- which values affect hit testing

This layer should absorb Windows / Wayland / X11 differences.

It also has to preserve SDL's own split instead of flattening it into one
"scale" number:

- logical window size
- pixel backbuffer size
- pixel density
- display scale

And the refresh model must follow SDL's event meanings:

- `SDL_EVENT_WINDOW_RESIZED`
  - logical layout size changed
- `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - drawable/backbuffer size changed
- `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
  - UI/content scale changed
- `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
  - display-coupled truth changed and must be requeried

### 3. One public widget geometry contract

Expose one public geometry contract for widgets. At minimum it should have:

- resolved logical window size
- resolved UI scale for layout spacing
- resolved widget-local origin/size after layout

And for terminal widgets specifically:

- resolved terminal viewport origin
- resolved cell width/height in logical units
- resolved baseline in logical units
- resolved device-pixel cell metrics, if truly needed by renderer-owned
  consumers only
- resolved rows/cols / visible viewport dimensions

The key rule:

- this contract is already snapped and already coherent
- widgets consume it
- widgets do not reinterpret it

That includes SDL event interpretation:

- widgets do not decide what a display-scale change means
- widgets do not decide what a pixel-size change means
- widgets do not decide whether drawable or logical size should win

### 4. One geometry source per concern

After the rewrite:

- platform code owns raw display/window/drawable truth
- renderer owns normalized scale truth
- widget layout owns pane/widget rectangles
- terminal view contract owns terminal-grid geometry

No concern should have two active public owners.

### 5. One draw/input/hover/open contract for terminal widgets

Terminal widget subsystems must all consume the same resolved terminal geometry:

- draw
- overlay
- hover
- hit testing
- pointer selection
- hyperlink open
- mouse reporting
- debug dump

If these paths use separate geometry derivations, the contract has failed.

### 6. No public snapping helpers for widgets

After the rewrite:

- `snapToDevicePixel(...)` should not be a public widget helper
- widgets should not receive `render_scale` just to snap origins
- snapping and quantization policy should live below the widget boundary

## Proposed Contract Shape

### Private platform snapshot

Private raw snapshot, renderer-internal:

```zig
const PlatformDisplaySnapshot = struct {
    window_w: i32,
    window_h: i32,
    drawable_w_px: i32,
    drawable_h_px: i32,
    display_index: i32,
    display_content_scale: f32,
    pixel_density: f32,
    window_display_scale: f32,
};
```

This is not widget-facing.

### Private renderer normalization

Renderer-private normalized scale state:

```zig
const WindowScaleState = struct {
    layout_scale: f32,
    raster_scale: f32,
    user_zoom: f32,
    logical_window_w: i32,
    logical_window_h: i32,
    drawable_w_px: i32,
    drawable_h_px: i32,
};
```

Responsibilities:

- `layout_scale`
  - affects layout / font logical size / chrome spacing
- `raster_scale`
  - affects raster size / device-pixel quantization / render-target sizing

This is where backend differences are normalized.

### Public widget contract

Public app-wide widget contract:

```zig
pub const UiGeometryContext = struct {
    window_w: f32,
    window_h: f32,
    ui_scale: f32,
};
```

This is intentionally boring.

Most widgets should need nothing richer than this plus their layout rect.

### Public terminal contract

Public terminal-only resolved view geometry:

```zig
pub const TerminalViewGeometry = struct {
    origin_x: f32,
    origin_y: f32,
    viewport_w: f32,
    viewport_h: f32,
    cell_w: f32,
    cell_h: f32,
    baseline: f32,
    rows: usize,
    cols: usize,
};
```

Rules:

- this is already coherent
- this is already snapped where necessary
- every terminal widget subsystem consumes this exact contract

No terminal widget code should be recomputing:

- snapped origin
- cell size from raw scale
- baseline from raw font metrics
- cursor thickness from raw render scale

outside renderer-owned policy.

## Public API Changes Implied

The following current public surfaces are suspicious and should likely be
removed or narrowed from widget reach:

- `Shell.renderScaleFactor()`
- `Shell.getDpiScale()`
- `Shell.getDisplayMetrics()`
- `Shell.getRenderSize()`
- `Shell.getScreenSize()`
- `Shell.getMonitorSize()`
- `Shell.refreshWindowMetrics(...)` as a normal widget tool
- public widget-level `snapToDevicePixel(...)`

Potential survivors:

- `Shell.uiScaleFactor()`
  - only if we decide generic widgets are allowed to scale spacing directly
  - otherwise even this should be absorbed into `UiGeometryContext`

Better direction:

- generic widgets get `UiGeometryContext`
- terminal widget subsystems get `TerminalViewGeometry`
- diagnostics/debugging can ask renderer for a diagnostic snapshot without
  teaching normal widget code the same raw surfaces

## Event / Refresh Contract

Scale-sensitive refresh should collapse into one renderer-owned flow.

When any of these happen:

- logical window resize
- drawable-size change
- display change
- display-scale change
- pixel-density change

the renderer should do one update pass that decides:

1. did logical layout geometry change?
2. did raster/backbuffer geometry change?
3. do fonts need rebuild?
4. do retained targets need recreation?
5. do terminal/editor resolved geometry snapshots need invalidation?

Widgets should consume the result, not participate in the decision.

## Enforcement Rules

### Rule 1

No widget file may read `r.scale.render_scale` directly.

### Rule 2

No widget file may define or call a public `snapToDevicePixel(...)`.

### Rule 3

No terminal widget subsystem may derive its own origin/cell/baseline from raw
scale inputs.

### Rule 4

`platform.display_metrics` is the only raw SDL display/window acquisition seam.

### Rule 5

Any debug dump may inspect raw scale state, but debug visibility does not make
that state part of the normal widget contract.

## Recommended Execution Order

### Phase 1: Freeze the target contract

- approve the public contract shapes
- decide whether `ui_scale` stays public or is folded into resolved widget
  geometry entirely
- decide terminal contract fields exactly once

### Phase 2: Introduce renderer-owned resolved geometry

- add renderer-owned `UiGeometryContext`
- add renderer-owned `TerminalViewGeometry`
- populate both from current renderer state without changing behavior yet

### Phase 3: Move terminal widget consumers to resolved geometry

In one front, convert:

- terminal draw
- overlay
- hover
- input hit-testing
- hyperlink open
- mouse reporting
- debug geometry capture

to the resolved terminal contract.

### Phase 4: Remove raw widget scale access

- delete public widget snap helpers
- delete widget reads of `r.scale.render_scale`
- delete widget reads of raw display/window metrics

### Phase 5: Collapse event/update flow

- renderer owns one scale refresh pipeline
- widgets no longer call `refreshWindowMetrics(...)` for normal work

### Phase 6: Clean up diagnostics and policy

- keep a renderer diagnostic snapshot for logging/debugging
- simplify `scale_utils`
- remove dead Wayland-scale theater
- replace fake mouse-scale seam with a real contract or delete it

## Success Criteria

This proposal is successful when all of these are true:

1. widgets consume one resolved geometry contract
2. no widget reasons about SDL backend scale behavior
3. terminal draw and terminal input use the same geometry object
4. scale-change handling is renderer-owned and singular
5. snapping policy exists in one owner, not six
6. the code reads like one geometry system, not a negotiated truce

## Non-Goals

This proposal does not assume:

- changing the VT architecture campaign
- changing renderer backend
- changing present architecture
- changing text rendering algorithms by itself

It is specifically about geometry and scale ownership.
