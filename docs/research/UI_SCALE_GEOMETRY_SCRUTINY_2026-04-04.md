# UI Scale Geometry Scrutiny 2026-04-04

## Purpose

This document does four things:

1. compares the SDL / Wayland / X11 / Windows scaling model that Zide is
   supposed to obey
2. records a repo-wide inventory of code touching scale, DPI, drawable size,
   or device-pixel snapping
3. states the current architecture problems explicitly
4. sets up a high-level redesign proposal without prematurely turning it into a
   TODO queue

This is scrutiny material, not final architecture authority. The proposed
target contract lives in:

- `app_architecture/ui/WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md`

## External Comparison

### SDL 3 baseline

Primary SDL references:

- `dev_references/sdlwiki_md/SDL3/README-highdpi.md`
- `dev_references/sdlwiki_md/SDL3/SDL_GetWindowDisplayScale.md`
- `dev_references/sdlwiki_md/SDL3/SDL_GetWindowPixelDensity.md`
- `dev_references/sdlwiki_md/SDL3/SDL_GetWindowSizeInPixels.md`
- `dev_references/sdlwiki_md/SDL3/README-wayland.md`
- `dev_references/sdlwiki_md/SDL3/SDL_HINT_VIDEO_X11_SCALING_FACTOR.md`

SDL's model is already split into distinct values:

- display content scale
  - what size content should feel like on the current display
- window logical size
  - the coordinate space the window API exposes
- window pixel size
  - the backbuffer/drawable size in pixels
- window pixel density
  - `pixel_size / logical_window_size`
- window display scale
  - combined content scale relative to the window's pixel size

Important SDL statements:

- `README-highdpi.md`
  - window size and window pixel size are distinct
  - `SDL_GetWindowPixelDensity()` is the ratio of pixel size to window size
  - `SDL_GetWindowDisplayScale()` is the expected content scale for the window
  - `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED` is the event to rebuild graphics
    context / targets from
  - `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED` is the event for content-scale
    change, not just another resize notification
- `SDL_GetWindowDisplayScale.md`
  - display scale is conceptually the scale display setting for content
- `SDL_GetWindowPixelDensity.md`
  - pixel density is only the ratio of pixel size to window size

So SDL's own event split is:

- `SDL_EVENT_WINDOW_RESIZED`
  - logical window size changed
- `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - pixel backbuffer size changed
- `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
  - content/UI scale changed
- `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
  - display-coupled state changed and must be requeried

SDL also states a backend split:

- Windows and Android are content-scale-first
  - coordinates are in physical pixels
  - ignoring content scale makes UI tiny
- macOS and iOS are logical-window-first
  - coordinates are in window coordinates
  - high-density is requested by asking for more pixels
- Linux split:
  - X11 behaves more like Windows
  - Wayland behaves more like macOS

That means SDL already expects apps to treat:

- content scale
- pixel density
- logical size
- pixel size

as separate concepts, not one `scale`.

### Wayland

Primary references:

- `dev_references/sdlwiki_md/SDL3/README-wayland.md`
- <https://wayland.app/protocols/fractional-scale-v1>
- <https://wayland.app/protocols/viewporter>
- <https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_SCALE_TO_DISPLAY>

Wayland-specific conclusions:

- legacy non-DPI-aware apps are scaled by the compositor and become blurry
- SDL has a legacy escape hatch:
  - `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1`
  - SDL explicitly documents this as legacy behavior with rounding, sizing,
    precision, and multi-monitor problems
  - new applications should not depend on it
- when SDL high pixel density is enabled for Wayland custom/external surfaces:
  - SDL handles scaling internally
  - application passes logical window size
  - application queries pixel size via `SDL_GetWindowSizeInPixels()`
  - application should not manually attach viewports or change surface scale

Wayland protocol direction:

- fractional-scale protocol:
  - compositor suggests fractional rendering scale
  - buffer size is surface size multiplied by intended scale
  - `wl_surface` buffer scale stays `1`
  - viewport destination rectangle remains the logical surface size
- viewporter protocol:
  - crop/scale occurs after buffer transform and buffer scale
  - logical destination size and pixel buffer size are intentionally separate

So on Wayland the correct mental model is:

- logical surface size
- pixel buffer size
- compositor-driven scale
- optional viewport mapping

not "one scale number the widget can poke at."

### X11

Primary references:

- `dev_references/sdlwiki_md/SDL3/README-highdpi.md`
- `dev_references/sdlwiki_md/SDL3/SDL_HINT_VIDEO_X11_SCALING_FACTOR.md`

X11 conclusions:

- SDL says X11 follows the Windows-style direction more than the Wayland/macOS
  direction
- SDL also exposes an explicit X11 scaling override hint:
  - `SDL_HINT_VIDEO_X11_SCALING_FACTOR`
  - this is a forced content scaling factor

That is a weaker, more manual world than Wayland:

- there is no clean Wayland-style compositor contract for logical surface size
  plus internal fractional buffer handling
- forcing scale exists as a hint
- this makes it even more important that Zide owns one normalized scale contract
  above SDL instead of spraying backend-specific behavior into widgets

### Windows

Primary references:

- <https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows>
- <https://learn.microsoft.com/en-us/windows/win32/hidpi/dpi-awareness-context>

Windows conclusions:

- DPI-unaware apps are bitmap stretched and blurry
- system-DPI-aware apps are only crisp at one DPI and blurry when DPI changes
- per-monitor DPI-aware apps:
  - get notified on DPI changes
  - are not bitmap-stretched by the system
  - must relayout and rerasterize themselves
- Per Monitor V2 specifically:
  - top-level and child windows receive DPI change notifications
  - app sees raw pixels of each display
  - app is never bitmap scaled by Windows
  - non-client area is DPI-aware automatically

Microsoft explicitly recommends:

- move layout logic out of one-time startup
- rerun DPI-sensitive layout when DPI changes
- invalidate cached DPI/font/size assumptions
- grep for non-DPI-aware APIs and replace them

That is directly aligned with the rule Zide should be following:

- no widget should cache its own private interpretation of display scale
- no widget should independently reinterpret logical vs pixel geometry

## Current SDL Event Handling Read

The live code still partially collapses SDL's more precise model:

- [sdl_api.zig](/home/home/personal/zide/src/platform/sdl_api.zig)
  `isResizeEvent(...)` currently groups:
  - `SDL_EVENT_WINDOW_RESIZED`
  - `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - `SDL_EVENT_WINDOW_MOVED`
  - `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
  - `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
- [window_resize_event_frame.zig](/home/home/personal/zide/src/app/window_resize_event_frame.zig)
  now preserves the change mask and forwards it into renderer refresh
- [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
  `refreshWindowState(...)` then re-queries the full display-metrics snapshot
  and applies:
  - logical window size
  - drawable size
  - mouse scale
  - UI scale
  - render scale

That is materially better than the old split refresh path, but it is still not
the final SDL-normalized contract.

The remaining mismatch is:

- SDL distinguishes layout, pixel-size, display-scale, and display-hop events
- our app now preserves that mask through refresh entry
- but the renderer still applies one broad full-state refresh for any
  refresh-affecting change kind

One concrete lie is gone though:

- moved-only events no longer count as refresh triggers by default

That is now the right pressure inside `WSG-4-01`.

## Repo-Wide Inventory

Inventory method:

- repo-wide `rg` over `src/`, `docs/`, and `app_architecture/`
- terms included:
  - `scale`
  - `dpi`
  - `pixel_density`
  - `display_scale`
  - `render_scale`
  - `drawable`
  - `ui_scale`
  - `snapToDevicePixel`

This section records the source-code inventory, grouped by responsibility.

### 1. Platform SDL boundary

These files talk directly about SDL/window/display truth:

- `src/platform/sdl_api.zig`
  - SDL window events
  - `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`
  - `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
  - `SDL_GetWindowDisplayScale`
  - `SDL_GetWindowPixelDensity`
  - high-pixel-density window creation flag
- `src/platform/display_metrics.zig`
  - collects window size, drawable size, display index, display scale, pixel
    density, derived `dpi`, derived `render_scale`
- `src/platform/window_metrics.zig`
  - wraps display metrics
  - exposes `getDpiScale`, `getRenderScale`, `getScreenSize`,
    `collectWindowMetrics`
- `src/platform/mouse_state.zig`
  - nominal mouse-scale boundary
  - currently fake: `computeMouseScale(...)` always returns `1.0`

### 2. Renderer-owned scale state and refresh path

These files are supposed to normalize scale for the rest of the app:

- `src/ui/renderer/font_runtime.zig`
  - `ScaleState`
  - `render_scale`
  - `ui_scale`
  - `user_zoom`
  - `wayland_scale_cache`
  - `refreshUiScale(...)`
- `src/ui/renderer/scale_utils.zig`
  - computes `ui_scale`
  - currently multiplies native scale only on Windows
  - carries dead Wayland cache parameters
- `src/ui/renderer/font_manager.zig`
  - derives layout size from `ui_scale * user_zoom`
  - derives raster size from `layout_size * render_scale`
  - writes scaled terminal/app/editor metrics
- `src/ui/renderer.zig`
  - stores renderer scale state
  - exposes `uiScaleFactor()`
  - exposes `renderScaleFactor()`
  - exposes `terminalCellGeometry()`
  - exposes raw display/window getter surface
- `src/ui/renderer/scene_frame_runtime.zig`
  - refreshes window/display metrics per frame
  - invalidates scene target on drawable/display/render-scale change

### 3. Text and glyph quantization

These files implement device snapping and scale-sensitive text geometry:

- `src/ui/font/shaping.zig`
  - local snap functions
  - local axis quantization
- `src/ui/renderer/text_runtime.zig`
  - local snap functions
  - text origin snapping
  - terminal cell draw snapping
- `src/ui/font/special_glyphs.zig`
  - render-scale participates in glyph cache key
- `src/ui/terminal_font.zig`
  - font state carries render scale
- `src/ui/font_sample_view.zig`
  - render-scale-aware sample rendering

### 4. Retained target / render target scaling

- `src/ui/renderer/retained_targets_runtime.zig`
  - own `snapToDevicePixel(...)`
  - retained-surface blit snapping
- `src/ui/renderer.zig`
  - `ensureRenderTargetScaled(...)`
- `src/ui/renderer/types.zig`
  - cache keys quantize render scale

### 5. Terminal widget scale and geometry consumers

These files currently consume scale directly or compute local snapped geometry:

- `src/ui/widgets/common.zig`
  - public `snapToDevicePixel(...)`
  - scrollbar sizes derived from `ui_scale`
- `src/ui/widgets/terminal_widget.zig`
  - hotkey dump pulls `refreshWindowMetrics(...)`
  - logs `ui_scale`, `render_scale`, drawable/window metrics
- `src/ui/widgets/terminal_widget_draw.zig`
  - device-snaps widget origin
  - reads `r.scale.render_scale`
  - reads `terminalCellGeometry()`
- `src/ui/widgets/terminal_widget_draw_grid.zig`
  - own `snapToDevicePixel(...)`
  - own quantize helpers
  - direct render-scale reads
- `src/ui/widgets/terminal_widget_draw_overlay.zig`
  - reads `r.uiScaleFactor()`
  - reads `r.scale.render_scale`
  - cursor thickness/inset math
- `src/ui/widgets/terminal_widget_hover.zig`
  - takes `render_scale` and `ui_scale`
  - snaps widget-local origin
  - underline thickness reads raw render scale
- `src/ui/widgets/terminal_widget_input.zig`
  - reads `shell.uiScaleFactor()`
  - reads `r.scale.render_scale`
  - snaps widget-local hit origin
- `src/ui/widgets/terminal_widget_keyboard.zig`
  - logs raw `ui_scale` and `render_scale`
- `src/ui/widgets/terminal_widget_retained_state.zig`
  - caches `last_render_scale`
- `src/ui/widgets/terminal_widget_debug_geometry.zig`
  - debug record carries render scale

### 6. Editor and general UI `ui_scale` consumers

These are not all wrong, but they are part of the public scale surface today:

- `src/editor/view/chrome_geometry.zig`
- `src/editor/render/visible_prep.zig`
- `src/editor/render/segment_paint.zig`
- `src/ui/widgets/editor_widget.zig`
- `src/ui/widgets/editor_widget_draw_text.zig`
- `src/ui/widgets/editor_widget_draw_overlay.zig`
- `src/ui/widgets/editor_widget_input.zig`
- `src/ui/widgets/shared_top_bar.zig`
- `src/ui/widgets/shared_top_bar_geometry.zig`
- `src/ui/widgets/side_nav.zig`
- `src/ui/widgets/status_bar.zig`
- `src/ui/widgets/tab_bar.zig`
- `src/app/window_caption_buttons_draw_runtime.zig`
- `src/app/window_caption_buttons_runtime.zig`
- `src/app/terminal/window_chrome_runtime.zig`
- `src/app/terminal/terminal_progress_runtime.zig`
- `src/app/terminal/terminal_scrollbar_runtime.zig`
- `src/app/terminal/terminal_close_confirm_draw.zig`
- `src/app/config_reload_notice.zig`
- `src/app/init_runtime.zig`
- `src/app/pre_input_shortcut_frame_runtime.zig`
- `src/app/post_preinput_hooks_runtime.zig`
- `src/app/shortcut_action_runtime.zig`

### 7. Event and diagnostic scale paths

- `src/app/window_resize_event_frame.zig`
  - calls `refreshWindowMetrics(...)`
  - then calls `refreshUiScale(...)`
- `src/app/mouse_debug_log.zig`
  - compares raw/scaled mouse
  - logs `display_scale`, `pixel_density`, `render_scale`

### 8. Existing docs already talking about this contract

- `app_architecture/ui/font_rendering_architecture.md`
- `docs/todo/ui/font_rendering.md`
- `docs/todo/terminal/wayland_present.md`
- `docs/todo/windows/implementation.md`

These docs contain useful findings, but they do not yet match a single fully
enforced public geometry contract for widgets.

## Explicit Current Problems

### 1. Scale truth is still split across too many public layers

Current path:

- `platform.display_metrics`
- `platform.window_metrics`
- `Renderer.scale`
- `Shell`
- widget-local snap and geometry logic

That is not one boring contract. It is one raw source plus several partially
normalized escape hatches.

### 2. `Shell` is still exposing raw renderer/backend scale surfaces to widgets

Examples:

- `Shell.uiScaleFactor()`
- `Shell.renderScaleFactor()`
- `Shell.refreshWindowMetrics(...)`
- `Shell.getDisplayMetrics()`
- `Shell.getDpiScale()`
- `Shell.getRenderSize()`
- `Shell.getScreenSize()`
- `Shell.getMonitorSize()`

That keeps widgets scale-aware in the wrong way.

### 3. Widgets still know about SDL-era concepts they should never need

Terminal widget code still sees or reconstructs:

- render scale
- UI scale
- snapped widget origin
- logical cell size
- device cell size
- window vs drawable metrics

This is exactly the leakage the user wants removed.

### 4. Snapping logic is duplicated and inconsistent

There are currently multiple snap implementations:

- `src/ui/font/shaping.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/retained_targets_runtime.zig`
- `src/ui/renderer/text_runtime.zig`
- `src/ui/widgets/common.zig`
- `src/ui/widgets/terminal_widget_draw_grid.zig`

Problems:

- the duplication itself is bad
- behavior differs
  - some horizontal snapping disables itself at non-integer scale
  - some always round
  - some are renderer-private
  - some are widget-public

This prevents one deterministic app-wide geometry rule.

### 5. `terminalCellGeometry()` is not yet the only terminal geometry authority

`Renderer.terminalCellGeometry()` is the right direction, but terminal widgets
still do their own extra work on top:

- device-pixel snap local origins
- hit-test base positions
- hover underline thickness from raw scale
- cursor overlay style from raw scale and raw `ui_scale`

So the renderer owns part of terminal geometry truth, but the widget still owns
too much of the last mile.

### 6. Event/update flow is split

Scale-sensitive refresh currently happens in multiple places:

- per-frame scene refresh in `scene_frame_runtime.zig`
- explicit `refreshWindowMetrics(...)`
- explicit `refreshUiScale(...)`
- target invalidation on scene target contract change
- widget-local debug pulls

This is workable, but not singular and enforced.

It is also still partially over-collapsed:

- the old split refresh path is gone
- but SDL's distinct window events are still bucketed too early into generic
  resize handling

### 7. `scale_utils.queryUiScale(...)` is visibly underdesigned

Current issues:

- Windows-specific native scale multiplication is hard-coded there
- backend-specific meaning is not modeled explicitly
- `WaylandScaleState` is carried through the API but currently unused theater
- `ZIDE_UI_SCALE` override is mixed directly into the same function as native
  scale normalization

That is not a clean policy boundary.

### 8. Mouse scaling contract is fake

`src/platform/mouse_state.zig` currently returns:

- `computeMouseScale(...) -> 1.0`

So the app structurally claims to have a mouse scale seam while not actually
solving that problem.

### 9. Present / render-target code still consumes scale as raw numbers

The scene-target path correctly invalidates on drawable-size and render-scale
changes, but the public story is still too raw:

- widgets and retained-target code still deal in `render_scale`
- draw targets snap with their own helpers
- window vs drawable reasoning is not fully hidden inside one renderer contract

### 10. Current docs overstate the cleanliness of the contract

`app_architecture/ui/font_rendering_architecture.md` says:

- OS/backend truth belongs in `platform.display_metrics`
- renderer/font code should consume that snapshot

That is directionally true, but not yet fully true in the live code, because
widgets still consume raw scale and rebuild local geometry from it.

## Bottom-Line Read

The current code is not "missing one fix."

The real problem is architectural:

- SDL/platform scale truth exists
- renderer partly normalizes it
- then the app re-publicizes too much of it
- widgets continue doing backend-flavored geometry math

So the current state is neither:

- a single SDL-owned abstraction

nor:

- a single renderer-owned abstraction

It is a half-normalized hybrid.

## What Must Be True After The Rewrite

1. Widgets do not read raw SDL/display scale concepts.
2. Widgets do not call `snapToDevicePixel(...)`.
3. Widgets do not reason about drawable size vs logical size.
4. Terminal draw, hover, input, open, and mouse-reporting use the same resolved
   view geometry object.
5. DPI-sensitive caches are invalidated by one coherent event/update flow.
6. SDL backend differences are normalized once, below widget level.
7. SDL event meanings remain distinct until the renderer-owned invalidation
   layer decides what to rebuild.

## Next Authority

The proposed end-state contract is documented in:

- `app_architecture/ui/WINDOW_SCALE_GEOMETRY_CONTRACT_PROPOSAL_2026-04-04.md`
