# WP-06 Resize, Scale, and Display Migration Semantics

## Scope

This report covers the resize- and display-transition contract around Zide's
current SDL + OpenGL + Wayland stack, with emphasis on:

- logical window size vs drawable pixel size
- display-scale and pixel-density changes
- display migration between monitors with different scale/refresh
- render-target recreation timing
- pacing implications during and after migration

Primary references:

- `src/ui/renderer/window_init.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/input_runtime.zig`
- `src/app/window_resize_event_frame.zig`
- `src/app/terminal/deferred_terminal_resize_frame.zig`
- `src/platform/window_metrics.zig`
- `reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c`
- `reference_repos/backends/sdl/src/video/wayland/SDL_waylandvideo.c`
- `reference_repos/backends/sdl/src/video/SDL_egl.c`
- `docs/AGENT_HANDOFF.md`

## Key Findings

1. Zide already treats resize as a two-stage event, which is the right shape.
   `src/ui/renderer/input_runtime.zig` marks any SDL resize-related window event
   as `window_resized_flag = true`. Then
   `src/app/window_resize_event_frame.zig` immediately refreshes window metrics
   and UI scale, while `src/app/terminal/deferred_terminal_resize_frame.zig`
   delays PTY row/column resize by `0.12s`. That split is good: pixel geometry
   updates immediately, terminal grid resize waits for the window to settle.

2. Zide's renderer already uses drawable pixels, not logical window size, as
   the render-target authority.
   In `src/ui/renderer.zig`, renderer init and
   `refreshWindowMetrics(...)` read both logical size and drawable size, and
   `ensureRenderTargetScaled(...)` sizes offscreen targets from
   `logical_size * render_scale`. This is the correct direction for Wayland,
   where logical size, display scale, and drawable size can diverge.

3. SDL's Wayland backend actively reconfigures drawable geometry on scale and
   display changes.
   In `reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c`,
   SDL attaches `wp_viewporter` and fractional-scale listeners when available,
   calls `ConfigureWindowGeometry(window)` before EGL configuration to set the
   drawable backbuffer size, and calls it again on display changes and other
   reconfiguration paths. This means drawable-size changes are not a secondary
   concern; they are part of the core Wayland window contract.

4. Display migration is not rare or hypothetical in the current live setup.
   The live logs already show the same window hopping between a `1.0x / 240Hz`
   display and a `1.6x / 60Hz` display. That means migration changes all of the
   following at once:
   - logical-to-drawable ratio
   - render-target pixel dimensions
   - effective UI scale
   - pacing budget / refresh characteristics

5. SDL's Wayland/OpenGL path has explicit frame-callback behavior for OpenGL.
   `reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c`
   creates a dedicated frame-event queue for OpenGL windows specifically to
   avoid compositor deadlock when the window is not visible. That is a strong
   signal that pacing/visibility semantics are part of the backend contract, not
   just renderer policy.

## Failure Risks

1. Render-target size drift across display hops.
   If a design ties authoritative composition state to old target sizes or
   assumes stable scale/drawable ratios, moving the window between displays can
   produce stale or partially valid composition surfaces.

2. Mixing logical and drawable authorities.
   The current stack tracks both `width/height` and `render_width/render_height`.
   Any redesign that is sloppy about which one owns composition, input mapping,
   screenshot/probe reads, or present blits will create correctness gaps.

3. PTY resize racing with render-target recreation.
   Zide intentionally delays terminal row/column resize, but render-target and
   UI-scale changes happen immediately. If the new design does not preserve that
   staging, it risks transient mismatches between composition size and terminal
   grid size.

4. Refresh-rate/pacing discontinuities after display migration.
   A 240Hz-to-60Hz move changes the present cadence materially. If pacing policy
   is derived implicitly from previous swap behavior or stale metrics, frame
   pacing and "recent activity" heuristics can become misleading.

5. Visibility-dependent deadlock or starvation in the wrong ownership layer.
   SDL's Wayland backend already treats frame callbacks specially for OpenGL.
   The renderer design should not add a second independent wait/ownership model
   that fights the backend's visibility behavior.

## Implications For Zide

1. The new presentation architecture must treat drawable pixel size as the
   authoritative size for all actual render/composition targets.
   Logical size remains important for layout, but not for target allocation or
   final present-path assumptions.

2. Resize/display migration should remain explicitly staged:
   - refresh window metrics and UI scale immediately
   - recreate or revalidate render targets immediately against drawable size
   - defer terminal row/column resize until the window has settled

3. Any offscreen or hybrid present design must survive monitor hops cleanly.
   A durable present path cannot assume constant scale, constant refresh, or
   stable default-framebuffer geometry.

4. The renderer should treat display migration as a composition invalidation
   boundary.
   Even if damage inside the terminal/editor remains narrow, render-target
   validity across scale/display changes should be assumed invalid until proven
   otherwise.

5. Pacing policy should be display-aware, but ownership should stay local.
   Zide can read refresh characteristics via `src/platform/window_metrics.zig`,
   but swap/present ownership should remain one clear renderer/backend seam
   rather than being spread across input, terminal, and presentation code.

## Recommended Constraints

1. Always allocate authoritative render targets from drawable pixels, never
   from logical window size alone.

2. Treat any of these SDL events as a hard geometry invalidation boundary:
   - `resized`
   - `size_changed` / pixel-size change
   - `display_changed`
   - `display_scale_changed`

3. Preserve the current two-stage resize contract:
   - immediate metric/UI-scale refresh
   - delayed PTY row/column resize after settle

4. On display/scale migration, require render-target revalidation before
   assuming any prior composed state is reusable.

5. Keep the present path single-owned.
   SDL/Wayland visibility/frame-callback behavior, render-target recreation,
   and final presentation should be coordinated by one renderer-side contract,
   not by multiple ad hoc timing paths.

6. Treat refresh-rate changes as pacing-input changes, not as proof that the
   underlying present contract changed.
   Geometry, scale, and pacing are related, but they should not be conflated.
