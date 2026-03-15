# WP-05 Damage, Upload, and Composition Strategy

## Scope

This topic asks how Zide should preserve narrow damage and lightweight uploads
while moving to a presentation architecture that is safe on a destructive-swap
Wayland/EGL stack.

The current constraints are:

- Zide already has detailed terminal texture planning for partial vs full
  updates, row-local spans, and viewport-shift handling in
  [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig).
- The surviving live bug is not in VT publication or pre-swap composition; it
  appears across swap/present on the default framebuffer path in
  [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig).
- The active EGL contract is destructive-swap, so the design cannot rely on
  default-framebuffer preservation semantics.

The goal is therefore not “full redraw every frame.” The goal is “retain narrow
damage inside Zide-owned targets, and make the final present step disposable.”

## Design Options

### 1. Direct default-framebuffer composition

Keep today's basic shape:

- update terminal textures narrowly
- draw the full UI directly into the default framebuffer
- swap

Pros:

- simplest frame graph
- no extra scene target
- lowest extra GPU memory

Cons:

- correctness still depends on default-framebuffer semantics that the current
  Wayland/EGL path does not guarantee
- makes present ownership ambiguous because the default framebuffer is both
  composition target and present sink
- keeps the current bug class viable

Assessment:

- Not a durable target for this stack.

### 2. Authoritative whole-scene compose target

Compose the entire frame into a renderer-owned offscreen target, then do one
final copy/draw to the default framebuffer immediately before swap.

Pros:

- scene correctness is decided before touching the default framebuffer
- destructive swap becomes a presentation detail, not a retained-state risk
- easier seam ownership: widget-local damage vs renderer scene composition vs
  final present

Cons:

- adds one extra full-window composite step per presented frame
- can become expensive if implemented as “always redraw everything everywhere”
- requires careful resize/recreate rules

Assessment:

- Architecturally sound, but only if narrow widget-local damage survives inside
  the composed scene.

### 3. Hybrid retained-widget targets plus authoritative scene target

Keep narrow retained targets where they pay for themselves, especially the
terminal texture, but treat the final scene as an authoritative offscreen
compose target and the default framebuffer as a one-frame sink only.

Pros:

- best match for Zide's embedded/resource bar
- preserves the value of current row/span-local terminal upload logic
- removes reliance on default-framebuffer persistence
- keeps composition ownership explicit

Cons:

- only works if seam ownership stays strict
- requires careful invalidation rules for scene target vs widget target

Assessment:

- Strongest current design direction for Zide.

## Fast-Path Risks

### Risk: destructive-swap safety turns into brute-force redraw

Zide's current texture planner already supports:

- row-local partial spans
- full-vs-partial choice
- shift-aware partial plans

in [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig).

If the redesign throws that away and replaces it with “full terminal upload plus
full scene repaint every frame,” it will regress the embedded/native goal.

### Risk: using the default framebuffer as a retained optimization base

The current present seam says this is unsafe. Any optimization that assumes the
window surface remains a stable previous-frame source after swap is architecturally
suspect on the active stack.

### Risk: blending damage ownership across layers

The renderer should not reinterpret VT/widget dirtiness heuristics into present
ownership. Ghostty is a good contrast here: it keeps coarse `false/partial/full`
dirty state and row-local dirty markers inside render-state ownership rather
than treating present as the source of truth
([render.zig](/home/home/personal/zide/reference_repos/terminals/ghostty/src/terminal/render.zig)).

### Risk: adopting the existing offscreen experiment as the design

Zide's current `compose_main_to_offscreen` experiment already proved it is not
yet authoritative. It introduced its own broken lane. The design should borrow
the ownership direction, not the current implementation shape in
[renderer.zig](/home/home/personal/zide/src/ui/renderer.zig).

## Reliability Constraints

### Retained truth must live in Zide-owned targets

If something is reused across frames, it should be a Zide-owned GPU resource:

- terminal texture
- optional editor/widget retained textures
- scene compose target

not the default framebuffer.

### Final present should be semantically dumb

By the time the renderer touches the default framebuffer, semantic composition
should already be finished. The final step should be “present this scene,” not
“continue deciding what the scene is.”

Kitty's `indirect_output` state is a useful signal here:

- `texture_id`
- `framebuffer_id`

in [state.h](/home/home/personal/zide/reference_repos/terminals/kitty/kitty/state.h),
with lifecycle in
[state.c](/home/home/personal/zide/reference_repos/terminals/kitty/kitty/state.c)
and output binding in
[gl.c](/home/home/personal/zide/reference_repos/terminals/kitty/kitty/gl.c).
The main takeaway is explicit output-target ownership, not Kitty-specific GL
details.

### Damage should stay narrow as long as possible

Foot is useful here even though it is not using the same GPU path. It:

- reuses prior buffer contents when safe
- applies current damage narrowly
- submits explicit dirty rectangles with `wl_surface_damage_buffer()`

in [render.c](/home/home/personal/zide/reference_repos/terminals/foot/render.c).

The Zide equivalent is:

- keep terminal/widget damage local and narrow
- flatten only at the final scene-present boundary

### Full invalidation should remain explicit

Ghostty's coarse `Dirty.false / partial / full` split is a good reminder that
full invalidation should be explicit and rare, not an accidental side effect of
presentation uncertainty
([render.zig](/home/home/personal/zide/reference_repos/terminals/ghostty/src/terminal/render.zig)).

## Recommendation Criteria

The winning design should satisfy all of these:

1. Correctness:
   - no dependence on preserved default-framebuffer contents

2. Narrow work:
   - terminal/editor damage remains row/span-local until late in the pipeline

3. Explicit ownership:
   - VT publication owns cell/grid truth
   - widget upload logic owns texture truth
   - renderer owns scene composition truth
   - default framebuffer owns nothing persistent

4. Cheap final present:
   - the last step to the window surface is a simple scene output step, not a
     second semantic redraw system

5. Resize/display safety:
   - scene target recreation is explicit and isolated from normal partial-update
     logic

6. Observability:
   - suspicious-frame probes should still be able to sample “scene before
     present” vs “presented result” without redefining ownership

## Recommendation

Zide should target a hybrid architecture:

- keep narrow retained widget-local targets, especially the terminal texture and
  its row/span-local partial upload logic
- introduce an authoritative renderer-owned scene compose target
- treat the default framebuffer as a one-frame present sink only

In practical terms:

- narrow damage and lightweight uploads happen inside Zide-owned targets
- the renderer composes the scene authoritatively before present
- the final default-framebuffer step becomes disposable and correctness-neutral

That is the best current path to combine reliability with lightweight updates on
the active stack.
