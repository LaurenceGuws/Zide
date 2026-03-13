# WP-01 SDL/Wayland/EGL Present Contract

## Scope

This report covers the SDL-owned contract between Zide and the Wayland/EGL
stack:

- EGL library loading and surface creation
- Wayland-specific OpenGL ES / EGL swap behavior
- window-surface ownership and native handle lifetime
- resize/display-migration implications visible at the SDL layer

It does not attempt to define Mesa's deeper EGL semantics or recommend a final
renderer architecture by itself. Those belong to later topics.

## Key Findings

1. SDL's generic `SDL_GL_SwapWindow()` contract is too coarse to be the real
   authority for Wayland/EGL.

   The public SDL doc still describes `SDL_GL_SwapWindow()` in the usual
   double-buffer terms, but the Wayland backend overrides the behavior with its
   own frame-callback-driven swap control. See
   [SDL_GL_SwapWindow.md](/home/home/personal/zide/reference_repos/sdlwiki_md/SDL3/SDL_GL_SwapWindow.md)
   and
   [SDL_waylandopengles.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c).

2. On Wayland, SDL intentionally forces EGL swap interval to zero and manages
   pacing itself.

   `Wayland_GLES_SetSwapInterval()` stores the requested interval in SDL state
   but then calls `eglSwapInterval(..., 0)` unconditionally. The comment is
   explicit: SDL avoids blocking inside EGL because Wayland compositors can
   stall forever waiting for frame callbacks.
   See
   [SDL_waylandopengles.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c).

3. SDL's Wayland backend makes swap order depend on its own `double_buffer`
   mode, not just on the app's requested GL attributes.

   In `Wayland_GLES_SwapWindow()`, SDL does one of two things:

   - if `data->double_buffer` is true, it calls `eglSwapBuffers()` first and
     then waits on the Wayland frame callback.
   - if `data->double_buffer` is false, it waits first and only then calls
     `eglSwapBuffers()`.

   This is SDL-owned behavior above EGL itself, and it means "swap semantics"
   on this backend are partly SDL scheduling semantics.
   See
   [SDL_waylandopengles.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c).

4. SDL explicitly skips swaps when the Wayland shell surface is not in a shown
   or waiting-for-frame state.

   `Wayland_GLES_SwapWindow()` returns success without swapping when the shell
   surface is hidden or otherwise not in the expected presentable states. This
   means Zide cannot assume "call swap, therefore a presentation attempt
   happened" on Wayland.
   See
   [SDL_waylandopengles.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c).

5. SDL uses Wayland frame callbacks as part of its presentation contract and
   includes a timeout escape hatch.

   The backend waits on `swap_interval_ready`, dispatches the dedicated frame
   event queue, and times out after roughly 50ms (`20hz`) so apps still make
   forward progress even if the compositor throttles callbacks aggressively.
   That is an SDL-specific liveness contract, not an app-level rendering
   contract.
   See
   [SDL_waylandopengles.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c)
   and the frame-ready path in
   [SDL_waylandwindow.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c).

6. Window-surface ownership is dynamic on Wayland and not all native objects
   persist across show/hide cycles.

   SDL documents that the `xdg_*` objects do not persist across window
   show/hide and must be re-queried each time the window is shown.
   `SDL_GetWindowProperties()` is therefore a live-inspection API, not a
   one-time bootstrap API.
   See
   [SDL_GetWindowProperties.md](/home/home/personal/zide/reference_repos/sdlwiki_md/SDL3/SDL_GetWindowProperties.md).

7. SDL exposes enough EGL state directly for runtime contract inspection.

   `SDL_EGL_GetCurrentDisplay()`, `SDL_EGL_GetCurrentConfig()`, and
   `SDL_EGL_GetWindowSurface()` are all public and main-thread-only. For Zide,
   that means the actual EGL surface/config contract can be logged and verified
   at runtime without leaving SDL.
   See:
   [SDL_EGL_GetCurrentDisplay.md](/home/home/personal/zide/reference_repos/sdlwiki_md/SDL3/SDL_EGL_GetCurrentDisplay.md),
   [SDL_EGL_GetCurrentConfig.md](/home/home/personal/zide/reference_repos/sdlwiki_md/SDL3/SDL_EGL_GetCurrentConfig.md),
   and
   [SDL_EGL_GetWindowSurface.md](/home/home/personal/zide/reference_repos/sdlwiki_md/SDL3/SDL_EGL_GetWindowSurface.md).

8. SDL owns EGL window-surface creation/destruction, and Wayland window resize
   goes through `wl_egl_window_resize()`.

   SDL creates the EGL window surface in `SDL_EGL_CreateSurface()` and destroys
   it in `SDL_EGL_DestroySurface()`. On Wayland, the native `wl_egl_window` is
   created/destroyed in the Wayland window code and resized with
   `wl_egl_window_resize(...)`.
   See
   [SDL_egl.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/SDL_egl.c),
   [SDL_waylandwindow.c](/home/home/personal/zide/reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c).

## Implications For Zide

- Zide should not treat `SDL_GL_SwapWindow()` on Wayland as a thin "flip the
  backbuffer now" primitive. SDL adds frame-callback scheduling, hidden-window
  elision, timeout behavior, and its own `double_buffer` policy.
- Zide should not treat the requested SDL GL swap interval as the actual EGL
  swap interval on Wayland. SDL deliberately forces EGL itself to interval 0.
- Any design that relies on stable default-framebuffer semantics across swap is
  already fighting both Wayland/EGL and SDL's Wayland pacing model.
- Zide should treat Wayland native handles and EGL handles as inspectable,
  runtime-owned state, not as fixed bootstrap facts.
- Resize, display migration, and show/hide transitions must be part of the
  renderer contract, because SDL may recreate or retarget the underlying native
  objects while still presenting a stable `SDL_Window` surface API.

## Open Questions

- Under what conditions does SDL set `data->double_buffer` on this Wayland
  path, and how tightly does that track EGL/back-buffer reality versus SDL's
  own scheduling preference?
- How much of the surviving Zide bug is caused by SDL's Wayland swap ordering
  policy versus deeper EGL/compositor semantics below SDL?
- On display/scale migration, which SDL window events are the earliest safe
  moment for Zide to treat render targets and EGL-surface-derived assumptions as
  stale?
- Does SDL's Wayland backend ever recreate the EGL surface in place during
  visible lifecycle transitions that matter to Zide's renderer ownership model,
  beyond the obvious create/destroy paths?

## Recommended Design Constraints

1. Treat the default framebuffer on Wayland as a present sink, not as an
   authoritative long-lived composition store.

2. Do not base renderer correctness on SDL's generic double-buffer wording.
   Use actual runtime EGL contract inspection and backend-specific behavior as
   the authority on this path.

3. Assume swap pacing is compositor- and frame-callback-mediated on Wayland,
   with SDL controlling the policy above EGL. The renderer should therefore be
   robust to deferred, skipped, or reordered presentation opportunities.

4. Make render-target and presentation ownership explicit across:
   - drawable-size changes
   - show/hide
   - display migration
   - scale changes

5. Keep startup/runtime contract logging for SDL/EGL/Wayland handles. It is not
   optional debugging sugar on this stack; it is part of establishing the real
   platform contract.

6. Prefer an architecture where Zide's own composed frame is authoritative
   before the SDL/Wayland swap boundary, instead of depending on post-swap
   default-framebuffer behavior to remain meaningful.
