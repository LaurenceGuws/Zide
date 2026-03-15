# WP-03 Reference Terminal Presentation Architectures

## Scope

This report compares the most relevant local terminal references for present and
render architecture on Wayland-capable stacks, with emphasis on:

- composition target ownership
- damage/upload policy
- present discipline around swap/commit

The goal is not feature parity review. The goal is to identify which
architectural patterns are reliable under destructive-swap or otherwise
non-preserving presentation semantics, and which of those patterns fit Zide's
embedded/native constraints.

## Per-Reference Findings

### Ghostty

- Ghostty clearly treats framebuffer ownership as an explicit abstraction, not
  as an implicit default-buffer assumption. Its OpenGL helper wraps framebuffer
  binding and explicitly notes that the default framebuffer is not reliably
  zero across drivers; it queries the current binding at runtime instead of
  hard-coding assumptions. See
  [Framebuffer.zig](/home/home/personal/zide/reference_repos/terminals/ghostty/pkg/opengl/Framebuffer.zig).
- That is a useful architectural signal even without reading the whole render
  path: Ghostty expects platform/driver framebuffer state to vary and isolates
  that variability behind an owned rendering abstraction.
- Implication:
  - Ghostty's style pushes toward explicit render-target ownership and away
    from casual direct-default-framebuffer assumptions.

### Foot

- Foot is the strongest local reference for narrow damage and explicit Wayland
  presentation discipline.
- It tracks dirty regions directly in its render path and pushes those regions
  to the compositor with `wl_surface_damage_buffer(...)`. See
  [render.c](/home/home/personal/zide/reference_repos/terminals/foot/render.c).
- It also has an explicit strategy for compositor buffer reuse and latency:
  when buffers are released later than ideal, it can pre-apply the previous
  frame's damage to the freed buffer in a worker path so the next frame starts
  from a correct base without waiting for a full redraw. See
  [render_buffer_release_callback](/home/home/personal/zide/reference_repos/terminals/foot/render.c).
- Foot integrates Wayland presentation timing explicitly through
  `wp_presentation` and tracks the compositor presentation clock. See
  [wayland.h](/home/home/personal/zide/reference_repos/terminals/foot/wayland.h)
  and [wayland.c](/home/home/personal/zide/reference_repos/terminals/foot/wayland.c).
- Foot's architecture is not “draw and hope swap semantics work out.” It is:
  - maintain authoritative buffer contents
  - maintain explicit damage
  - integrate compositor-facing timing deliberately
- Implication:
  - Foot is the best local authority for how a lightweight native terminal can
    stay fast without depending on preserved implicit state.

### Kitty

- Kitty uses its own GLFW fork and owns the EGL/Wayland stack more directly
  than Zide currently does.
- Its EGL path is explicit: choose EGL config, create EGL context/surface, make
  current, and swap through `eglSwapBuffers`. See
  [egl_context.c](/home/home/personal/zide/reference_repos/terminals/kitty/glfw/egl_context.c).
- Its Wayland path loads and owns `wl_egl_window_*` integration directly. See
  [wl_init.c](/home/home/personal/zide/reference_repos/terminals/kitty/glfw/wl_init.c)
  and [wl_window.c](/home/home/personal/zide/reference_repos/terminals/kitty/glfw/wl_window.c).
- Kitty is useful less because it demonstrates a specific offscreen-present
  trick and more because it shows a terminal willing to own the backend seam
  directly rather than trust a vague default-framebuffer contract.
- Implication:
  - If Zide stays on SDL/OpenGL, Kitty is a good reference for the level of
    backend explicitness required around EGL and Wayland objects.

### WezTerm

- WezTerm's strongest relevant signal is architectural discipline around the
  window-system present boundary rather than raw EGL details.
- Its window layer explicitly exposes a `pre_present_notify()` call, with
  documentation stating that on Wayland it is used to schedule frame callbacks
  and align redraw pacing with the compositor. See
  [window.rs](/home/home/personal/zide/reference_repos/terminals/wezterm/window/src/window.rs).
- Its Wayland window layer also explicitly manages the Wayland EGL surface
  resize/scale lifecycle. See
  [window.rs](/home/home/personal/zide/reference_repos/terminals/wezterm/window/src/os/wayland/window.rs).
- The key architectural lesson is that presentation is treated as a real
  protocol boundary with explicit notification/pacing hooks, not just “call
  swap when rendering is done.”
- Implication:
  - Zide should likely have an explicit internal “about to present” seam with
    owned pacing/visibility consequences, even if the backend stays SDL-based.

### Rio

- Rio contributes the same explicit present-boundary lesson as WezTerm, but in
  a smaller and cleaner form.
- `Window::pre_present_notify()` is documented as the correct hook to call
  after drawing and before submitting the buffer, specifically so the windowing
  system can schedule and throttle redraw correctly on Wayland. See
  [window.rs](/home/home/personal/zide/reference_repos/terminals/rio/rio-window/src/window.rs).
- Rio is useful because it separates:
  - render work
  - present notification
  - actual buffer submission
  instead of collapsing them into one opaque “swap” action.
- Implication:
  - A redesigned Zide present path should likely have a first-class pre-present
    phase, even if the final implementation detail is still OpenGL swap on SDL.

## Cross-Cutting Patterns

- Do not rely on implicit default-framebuffer behavior.
  - Ghostty explicitly abstracts framebuffer ownership.
  - Kitty explicitly owns EGL/Wayland details.
- Treat presentation as a protocol boundary, not merely a GL call.
  - WezTerm and Rio both make “pre-present” a named API boundary.
- Keep authoritative render state separate from compositor-facing submission.
  - Foot is the clearest example: damage and buffer state are maintained as
    owned state, then Wayland submission is done deliberately.
- Narrow damage is still compatible with correctness.
  - Foot shows that lightweight/native does not require full redraws if damage
    and buffer lifetime are owned cleanly.
- Resize/scale/display changes belong in the presentation architecture, not as
  incidental side effects.
  - WezTerm and Rio both expose platform-aware present lifecycle hooks.

## Implications For Zide

- Zide should not design around preserved default-framebuffer semantics on the
  Wayland lane. None of the strongest references depend on vague implicit swap
  behavior as a correctness foundation.
- The likely winning shape for Zide is:
  - authoritative internal composition state
  - explicit damage ownership
  - explicit pre-present boundary
  - final submission/present treated as a sink, not as reusable state
- Foot is the strongest lightweight/native reference for damage and buffer
  ownership.
- WezTerm and Rio are the strongest references for explicit present pacing and
  pre-present discipline.
- Ghostty and Kitty are the strongest references for “own the backend seam
  explicitly; do not let framebuffer assumptions leak through the stack.”

## Open Questions

- Does Ghostty ultimately rely on an authoritative offscreen composition model
  for the terminal path, or does it keep more direct default-target rendering
  while still isolating framebuffer ownership cleanly?
- Which of the references preserve narrow damage all the way through the final
  compositor submission path, and which fall back to broader composition at the
  last stage?
- For Zide specifically, is the best durable answer:
  - full authoritative offscreen composition
  - a hybrid model with authoritative offscreen main composition plus narrow
    texture uploads
  - or a stricter direct path that still treats present as destructive every
    frame?
- How much of WezTerm/Rio's explicit pre-present discipline can be reproduced
  cleanly through SDL without bypassing SDL entirely on Wayland?
