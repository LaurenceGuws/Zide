# Window Scale Geometry TODO

## Scope

Replace the current half-normalized scale/geometry story with one boring,
deterministic, renderer-owned public contract.

This queue is not "fix one cursor bug."
It is the app-wide ownership lane for:

- scale truth
- logical vs drawable size truth
- resolved widget geometry
- resolved terminal grid geometry
- snapping / quantization ownership
- scale-change refresh and invalidation flow

Current authority and evidence:

- [WINDOW_SCALE_GEOMETRY_DESIGN.md](/home/home/personal/zide/app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md)
- [WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md](/home/home/personal/zide/app_architecture/ui/WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md)
- [UI_SCALE_GEOMETRY_SCRUTINY_2026-04-04.md](/home/home/personal/zide/docs/research/UI_SCALE_GEOMETRY_SCRUTINY_2026-04-04.md)
- [font_rendering_architecture.md](/home/home/personal/zide/app_architecture/ui/font_rendering_architecture.md)
- [font_rendering.md](/home/home/personal/zide/docs/todo/ui/font_rendering.md)

## Problem Statement

The current code is not on one geometry contract.

Scale truth is split across:

- `platform.display_metrics`
- `platform.window_metrics`
- renderer scale state
- shell public accessors
- widget-local snap and geometry logic

That leaves the app in a bad middle state:

- raw SDL/platform truth exists
- renderer partly normalizes it
- then widgets still reconstruct their own backend-flavored geometry

## Hard Rules

These rules are the bar for this queue.

### Forbidden surfaces

Widget code must not end this queue still using:

- `r.scale.render_scale`
- `Shell.renderScaleFactor()`
- `Shell.getDpiScale()`
- `Shell.getDisplayMetrics()`
- `Shell.getRenderSize()`
- `Shell.getScreenSize()`
- `Shell.getMonitorSize()`
- `Shell.refreshWindowMetrics(...)` as normal widget/runtime geometry input
- public widget `snapToDevicePixel(...)`

### Forbidden outcomes

Do not call the queue complete if:

- terminal draw and terminal input use different geometry derivations
- snapping still exists in multiple public widget helpers
- scale-change handling is still partly renderer-owned and partly widget-owned
- SDL/Wayland/X11/Windows differences still leak into widget code

## Execution Order

### Phase 0: Lock the public contract

Goal:

- approve the exact public geometry surfaces before code churn

Required outputs:

- final public generic widget contract
- final public terminal view contract
- explicit list of public scale APIs that will be deleted or narrowed

Completion bar:

- no ambiguity remains about what widgets are allowed to know

### Phase 1: Introduce renderer-owned resolved geometry

Goal:

- add renderer-owned resolved geometry objects without behavior change

Required direction:

- one renderer-private raw backend normalization path
- one public `UiGeometryContext`
- one public `TerminalViewGeometry`

Completion bar:

- renderer can produce both contracts from current scale state
- widget consumers can be migrated incrementally without inventing new raw
  scale reads

### Phase 2: Move terminal widget consumers to one resolved contract

Goal:

- make terminal-space consumers share one geometry contract

Must migrate together:

- terminal draw
- terminal overlay
- terminal hover
- terminal hit testing
- hyperlink open
- pointer selection
- mouse reporting
- debug snapshot logging

Completion bar:

- terminal widget subsystems no longer compute snapped origin or cell geometry
  from raw scale themselves

### Phase 3: Remove widget-side snapping and raw scale access

Goal:

- delete public scale leakage

Required deletions or narrowings:

- widget `snapToDevicePixel(...)` helpers
- widget direct `render_scale` reads
- shell/public raw display-metric access from widget code

Completion bar:

- no widget file depends on raw renderer scale state or SDL-style metrics

### Phase 4: Collapse the scale refresh pipeline

Goal:

- one renderer-owned refresh/invalidation story

Required outcome:

- resize, drawable-size change, display change, scale change, and zoom-driven
  relayout route through one coherent renderer update path

SDL event model that this phase must obey:

- `SDL_EVENT_WINDOW_RESIZED`
  - logical layout/window size changed
- `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - drawable/backbuffer size changed
- `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
  - UI/content scale changed
- `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
  - display-coupled truth must be requeried

Phase 4 is not complete if those meanings are collapsed too early back into one
generic "resize" concept.

Completion bar:

- widgets consume resolved geometry snapshots
- widgets do not decide whether scale-sensitive state needs rebuild

### Phase 5: Clean up backend/policy residue

Goal:

- remove leftover fake or theatrical seams

Likely targets:

- dead/unused `WaylandScaleState` theater
- fake mouse-scale seam in `platform/mouse_state.zig`
- any remaining split between geometry truth and text/retained-target truth

Completion bar:

- the geometry story reads as one deliberate design, not an accretion of fixes

## Active Inventory Baseline

The current high-risk files are:

- `src/platform/display_metrics.zig`
- `src/platform/window_metrics.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/font_runtime.zig`
- `src/ui/renderer/scale_utils.zig`
- `src/ui/renderer/text_runtime.zig`
- `src/ui/renderer/retained_targets_runtime.zig`
- `src/ui/widgets/common.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget_draw_grid.zig`
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
- `src/ui/widgets/terminal_widget_hover.zig`
- `src/ui/widgets/terminal_widget_input.zig`
- `src/app_shell.zig`

This is not a suggestion to churn all of them at once.
It is the current inventory of where the contract is still split.

## Validation

Always:

- `zig build`
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`

Manual:

- terminal at `render_scale=1.0`
- terminal at fractional scale such as `1.25`, `1.5`, or `1.6`
- same terminal interactions across:
  - draw
  - cursor overlay
  - hover underline
  - mouse selection
  - hyperlink open
  - mouse reporting
- scale/display hop if available

## TODO

- [x] `WSG-0-01` Freeze the public geometry contract
  - Authority now lives in:
    - [WINDOW_SCALE_GEOMETRY_DESIGN.md](/home/home/personal/zide/app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md)
  - Frozen decisions:
    - `WidgetLayout` stays the pane-rectangle authority
    - generic widgets consume `UiGeometryContext`
    - terminal widget subsystems consume `TerminalViewGeometry`
    - raw `Shell` scale/metric getters are on the cut list
- [x] `WSG-1-01` Introduce renderer-owned resolved geometry snapshots
  - Landed shape:
    - [layout.zig](/home/home/personal/zide/src/types/layout.zig)
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
    - [app_shell.zig](/home/home/personal/zide/src/app_shell.zig)
  - Renderer now exposes:
    - `uiGeometryContext()`
    - `terminalViewGeometry(...)`
  - Current low-risk consumer:
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - the debug/view-geometry sampling path now records the renderer-owned
      terminal snapshot instead of reconstructing it ad hoc
  - This was intentionally a no-behavior-change checkpoint:
    - the full terminal widget migration still belongs to `WSG-2-01`
- [x] `WSG-2-01` Move terminal draw/overlay/hover/input/open/reporting onto one terminal geometry contract
  - Landed migration fronts:
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget_draw_grid.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_grid.zig)
    - [terminal_widget_draw_overlay.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_overlay.zig)
    - [terminal_widget_hover.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_hover.zig)
    - [terminal_widget_input.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_input.zig)
    - [terminal_widget_open.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig)
    - [terminal_widget_pointer.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_pointer.zig)
    - [terminal_widget_mouse_reporting.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_mouse_reporting.zig)
  - Terminal-space consumers now share renderer-owned `TerminalViewGeometry` for:
    - viewport rectangle
    - snapped logical origin
    - rows/cols
    - logical cell width/height
    - baseline-from-top
  - Remaining raw `render_scale` reads in terminal widget code are now limited to:
    - raster snapping
    - underline/cursor stroke thickness
    - retained-texture / device-pixel rendering policy
  - Those survivors belong to `WSG-3-*`, not terminal geometry ownership.
- [x] `WSG-3-01` Delete widget-side snap helpers and raw render-scale reads
  - Remove `common.snapToDevicePixel(...)` and any equivalent widget-level
    public surface.
  - First deletion landed:
    - [common.zig](/home/home/personal/zide/src/ui/widgets/common.zig)
    - terminal widgets no longer depend on a shared public `snapToDevicePixel(...)`
      helper
  - Renderer-owned snap/pixel-step primitives now exist in:
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
  - Terminal widget migration landed in:
    - [terminal_widget_draw_grid.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_grid.zig)
    - [terminal_widget_draw_overlay.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_overlay.zig)
    - [terminal_widget_hover.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_hover.zig)
    - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [terminal_widget_keyboard.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_keyboard.zig)
  - Final non-terminal escape hatch also landed:
    - [font_sample_view.zig](/home/home/personal/zide/src/ui/font_sample_view.zig)
      now uses renderer-owned logical/raster conversion helpers plus
      [UiGeometryContext](/home/home/personal/zide/src/types/layout.zig)
      instead of raw `renderer.scale.render_scale` and raw window dimensions
    - the font sample view now rebuilds its sample fonts when raster scale
      changes, so it no longer drifts stale across display-scale or zoom
      changes
  - Completion result:
    - widget-local snap helper is deleted
    - widget/view code no longer reads raw `renderer.scale.render_scale`
    - the next pressure is no longer widget raw scale access
- [ ] `WSG-3-02` Delete raw scale/metric access from `Shell` where widgets currently rely on it
  - Narrow diagnostics separately if needed.
  - Landed diagnostic replacement:
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
      `WindowGeometryDiagnostics`
    - [app_shell.zig](/home/home/personal/zide/src/app_shell.zig)
      `windowGeometryDiagnostics()` and `refreshWindowGeometryDiagnostics(...)`
  - Rewired consumers:
    - [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
    - [mouse_debug_log.zig](/home/home/personal/zide/src/app/mouse_debug_log.zig)
    - [shortcut_action_runtime.zig](/home/home/personal/zide/src/app/shortcut_action_runtime.zig)
  - Deleted public raw getter surface from `Shell`:
    - `renderScaleFactor()`
    - `getDpiScale()`
    - `getDisplayMetrics()`
    - `getScreenSize()`
    - `getRenderSize()`
    - `getMonitorSize()`
  - Deleted matching renderer getter residue where it no longer served a real public contract.
  - Current honest remainder:
    - `refreshWindowMetrics(...)` still survives as a broader refresh hook
    - that remainder belongs with `WSG-4-01`, not with raw widget metric access
- [ ] `WSG-4-01` Collapse scale refresh and invalidation into one renderer-owned path
  - First real refresh unification landed:
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
      `refreshWindowState(...)`
    - [font_runtime.zig](/home/home/personal/zide/src/ui/renderer/font_runtime.zig)
      `refreshUiScaleFromDisplayMetrics(...)`
    - [window_resize_event_frame.zig](/home/home/personal/zide/src/app/window_resize_event_frame.zig)
    - [init_runtime.zig](/home/home/personal/zide/src/app/init_runtime.zig)
  - What changed:
    - window-event refresh no longer does:
      - `refreshWindowMetrics(...)`
      - then `refreshUiScale()`
    - startup no longer uses a separate scale-only refresh path
    - one renderer-owned refresh now applies:
      - window size
      - drawable size
      - mouse scale
      - UI scale
      - render scale
      from one display-metrics snapshot
  - The old broad refresh split is gone from app-side callers.
  - First SDL-event-fidelity cut also landed:
    - [sdl_api.zig](/home/home/personal/zide/src/platform/sdl_api.zig)
      now classifies window changes explicitly instead of reducing them to one
      resize boolean
    - [input_state.zig](/home/home/personal/zide/src/ui/renderer/input_state.zig)
      and [input_runtime.zig](/home/home/personal/zide/src/ui/renderer/input_runtime.zig)
      now preserve a `WindowChangeMask`
    - [window_resize_event_frame.zig](/home/home/personal/zide/src/app/window_resize_event_frame.zig)
      now consumes that mask instead of a generic `isWindowResized()` boolean
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
      and [app_shell.zig](/home/home/personal/zide/src/app_shell.zig)
      now carry that explicit mask through `refreshWindowState(...)`
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
      now stores the current `DisplayMetrics` snapshot as renderer-owned state
    - moved-only window events no longer trigger the generic refresh path
    - [scene_frame_runtime.zig](/home/home/personal/zide/src/ui/renderer/scene_frame_runtime.zig)
      now consumes queued renderer-owned scene-target invalidation at
      `beginFrame(...)` using the renderer-owned `DisplayMetrics` snapshot
      instead of recollecting SDL metrics independently every frame or
      recomputing invalidation locally
  - Current honest remainder:
    - terminal retained-surface presentation no longer squeezes a wider
      offscreen logical surface into a narrower on-screen viewport:
      - [retained_targets_runtime.zig](/home/home/personal/zide/src/ui/renderer/retained_targets_runtime.zig)
        now supports logical source cropping for retained-surface blits
      - [texture_draw.zig](/home/home/personal/zide/src/ui/renderer/texture_draw.zig)
        now exposes proportional logical source rect calculation
      - [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
        now presents terminal retained surfaces with matched source/destination
        logical widths and records that contract in the terminal debug dump
    - present/invalidation policy still has its own scene-target contract path
    - zoom still has its own trigger path, but now shares the same
      `WindowRefreshResult` contract shape as window refresh at the
      shell/renderer boundary
    - [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
      `WindowRefreshResult` now carries renderer-owned follow-up semantics too:
      - `needsRedraw()`
      - `needsUiLayoutRefresh()`
      - `needsDeferredTerminalResize()`
      - explicit `scene_target_invalidation`
      so app code is no longer hand-deciding those from raw fields
    - refresh/invalidation still consumes that mask too generically:
      - `refreshWindowState(...)` no longer does a full display-coupled metrics
        requery for plain resize / pixel-size changes:
        - geometry-only changes now refresh:
          - window size
          - drawable size
          - derived pixel-density / render-scale
          from a geometry-only snapshot
        - display-coupled changes still use full `DisplayMetrics`
      - but `ui_scale` refresh is now correctly limited to:
        - `display_changed`
        - `display_scale_changed`
        instead of also rerunning on plain logical resize or pixel-size change
      - the next remaining over-collapse is no longer duplicate scene-target
        invalidation computation or unconditional full metrics requery
      - what remains is the honest question of whether zoom should stay as its
        own trigger path or merge even further into the same refresh trigger
        pipeline
    - the next work is to decide whether present/invalidation and zoom should
      unify further while preserving SDL's distinct event meanings instead of
      collapsing them back into one broad refresh action
- [ ] `WSG-5-01` Delete backend/policy residue that no longer survives hostile scrutiny
  - dead Wayland-scale state
  - fake mouse-scale seam
  - any remaining widget-visible SDL geometry vocabulary
  - Current strongest residue after the terminal drift fix and font-sample cut:
    - [mouse_state.zig](/home/home/personal/zide/src/platform/mouse_state.zig)
      still has the fake mouse-scale seam
    - [shaping.zig](/home/home/personal/zide/src/ui/font/shaping.zig) and
      [text_runtime.zig](/home/home/personal/zide/src/ui/renderer/text_runtime.zig)
      still carry duplicated snap/quantize policy outside one renderer-owned
      contract

## Exit Criteria

This queue is only complete when all of these are true:

1. Widgets consume one resolved geometry contract.
2. Terminal draw and terminal input use the same geometry object.
3. No widget code reads raw `render_scale`.
4. No widget code uses public snap helpers.
5. SDL/backend scaling differences are normalized below the widget boundary.
6. Scale-change handling is singular and renderer-owned.
7. SDL resize/pixel-size/display-scale/display-change semantics stay distinct
   until the renderer invalidation layer resolves them.
