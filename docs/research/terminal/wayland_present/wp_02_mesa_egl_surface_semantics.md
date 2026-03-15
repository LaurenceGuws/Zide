# WP-02 Mesa EGL/Wayland Surface Semantics

## Scope

This report covers the Mesa/EGL surface semantics that matter for Zide's
surviving Wayland presentation bug:

- what Mesa `libEGL` guarantees generically versus what platform drivers decide
- how window-surface `EGL_RENDER_BUFFER` and `EGL_SWAP_BEHAVIOR` are initialized
  and queried
- the difference between surface-requested render buffer and context-active
  render buffer
- what partial-update / buffer-age style assumptions are safe to make on this
  stack

Primary local references:

- [egl.rst](/home/home/personal/zide/reference_repos/rendering/mesa/docs/egl.rst)
- [eglsurface.c](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglsurface.c)
- [eglcontext.c](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglcontext.c)
- [eglSwapBuffers.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglSwapBuffers.md)
- [eglQuerySurface.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglQuerySurface.md)
- [eglGetConfigAttrib.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglGetConfigAttrib.md)
- [eglQueryContext.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglQueryContext.md)

## Key Findings

1. Mesa's `libEGL` is a dispatcher, not the full platform implementation.
   [egl.rst](/home/home/personal/zide/reference_repos/rendering/mesa/docs/egl.rst)
   states that the main library is window-system-neutral and dispatches most EGL
   entry points to dynamically loaded drivers. For Zide, that means the generic
   EGL surface contract matters, but final behavior still rides through the
   platform driver path.

2. Generic Mesa surface initialization treats window-surface swap as
   destructive by default.
   In [_eglInitSurface()](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglsurface.c),
   `swapBehavior` starts as `EGL_BUFFER_DESTROYED`, may be promoted to
   `EGL_BUFFER_PRESERVED` only if the config advertises
   `EGL_SWAP_BEHAVIOR_PRESERVED_BIT`, and is then forced back to
   `EGL_BUFFER_DESTROYED` for `EGL_WINDOW_BIT` surfaces. That lines up with the
   Khronos contract in
   [eglSwapBuffers.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglSwapBuffers.md):
   post-swap color is undefined unless `EGL_SWAP_BEHAVIOR ==
   EGL_BUFFER_PRESERVED`.

3. For window surfaces, `eglQuerySurface(EGL_RENDER_BUFFER)` returns the
   requested render buffer, not necessarily the actual one the context uses.
   Mesa's
   [_eglQuerySurface()](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglsurface.c)
   returns `surface->RequestedRenderBuffer` for window surfaces. The comment in
   that function explicitly cites the Khronos rule: for window surfaces, the
   value is the one requested when the surface was created or last set via
   `eglSurfaceAttrib`.

4. `eglQueryContext(EGL_RENDER_BUFFER)` is the actual context-side authority.
   Mesa's
   [_eglQueryContext()](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglcontext.c)
   delegates to `_eglQueryContextRenderBuffer()`, which returns
   `surf->ActiveRenderBuffer` for window surfaces. The same function notes that
   this may be either `EGL_BACK_BUFFER` or `EGL_SINGLE_BUFFER` depending on the
   requested surface value and client-API behavior. That matches
   [eglQueryContext.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglQueryContext.md).

5. Mutable render-buffer behavior is optional and tightly gated.
   In [_eglSurfaceAttrib()](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglsurface.c),
   `EGL_RENDER_BUFFER` can only be changed when `KHR_mutable_render_buffer` is
   exposed and the config advertises `EGL_MUTABLE_RENDER_BUFFER_BIT_KHR`.
   Without that, switching a window surface to single-buffer mode is not a
   generally available fallback.

6. Preserved swap is opt-in and config-constrained.
   `_eglSurfaceAttrib(..., EGL_SWAP_BEHAVIOR, EGL_BUFFER_PRESERVED)` succeeds
   only if the config advertises `EGL_SWAP_BEHAVIOR_PRESERVED_BIT`; otherwise
   Mesa returns `EGL_BAD_MATCH`.
   [eglGetConfigAttrib.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglGetConfigAttrib.md)
   and Mesa's config checks agree that preserved swap support is a property of
   the chosen config, not something the application can assume into existence.

7. Buffer-age / partial-update style paths are extension-gated and fragile.
   In
   [_eglQuerySurface()](/home/home/personal/zide/reference_repos/rendering/mesa/src/egl/main/eglsurface.c),
   `EGL_BUFFER_AGE_EXT` is only legal when `EXT_buffer_age` or
   `KHR_partial_update` is exposed, only for the current draw surface, and Mesa
   even emits a warning that `GALLIUM_HUD` can make queried buffer age artifact.
   This is a strong signal that these paths are optimization surfaces, not
   correctness foundations.

8. Swap-time resize handling is part of the EGL contract.
   [eglSwapBuffers.md](/home/home/personal/zide/reference_repos/rendering/khronos_refpages_md/EGL/eglSwapBuffers.md)
   says if the native window resized before swap, the EGL surface must be
   resized to match before posting pixels. For Zide, that means drawable-size
   and display changes are part of present correctness, not just window-event
   bookkeeping.

## Implications For Zide

- Zide should treat Wayland window-surface swap as destructive unless explicit
  preserved-swap support is both queried and intentionally designed around. The
  generic Mesa initialization path strongly suggests destructive swap is the
  normal case.

- Zide's current startup log of surface `EGL_RENDER_BUFFER` is useful, but it
  does not fully answer the "what buffer is the bound context actually using?"
  question. If that distinction matters for design or diagnostics, Zide should
  also query context `EGL_RENDER_BUFFER`.

- The durable architecture should not depend on default-framebuffer persistence
  across frames. If authoritative frame state must survive swap, it should live
  in Zide-owned textures/FBOs, not in assumed window-surface contents.

- Any future use of buffer-age / partial-update mechanisms must be strictly
  extension- and validation-gated. They are optional accelerators, not safe
  baseline assumptions.

- Resize, scale, and display migration need explicit invalidation/recreation
  rules in the renderer design because EGL allows surface resizing to materialize
  at swap time.

## Open Questions

- Does the active SDL/Wayland path ever cause the bound context's actual render
  buffer to differ from the requested surface render buffer on Zide's stack?

- Are there Mesa Wayland-driver specifics below the generic EGL layer that
  materially change how swap/destructive behavior should be interpreted on this
  exact path, or is the generic contract already sufficient for architecture?

- If Zide moves to an authoritative offscreen presentation path, which parts of
  the current direct-default path remain worth preserving as narrow fast paths,
  if any?

## Recommended Design Constraints

- Assume `EGL_BUFFER_DESTROYED` for correctness unless preserved behavior is
  explicitly queried and proven available on the chosen config.

- Keep authoritative image state in Zide-owned GPU resources instead of relying
  on post-swap default-framebuffer contents.

- Separate surface-requested render buffer from context-active render buffer in
  diagnostics and design reasoning.

- Treat buffer-age / partial-update support as optional optimization surfaces
  only, never as baseline correctness machinery.

- Build resize/display-change invalidation and target-recreation behavior into
  the present architecture from the start.
