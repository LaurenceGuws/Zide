# WP-04 Zide Present Seam Ownership

## Scope

Map the current ownership boundaries between terminal publication, widget
texture updates, renderer composition, and presentation feedback for the
surviving Wayland present bug. This report is about the remaining `nvim`
text-buffer scrolling ghost, not the older `wiki_life` publication bug that was
already fixed.

Primary local refs:

- [VT_CORE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
- [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
- [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
- [session_rendering.zig](/home/home/personal/zide/src/terminal/core/session_rendering.zig)
- [session_rendering_retirement.zig](/home/home/personal/zide/src/terminal/core/session_rendering_retirement.zig)

## Current Ownership Map

### Terminal core

The terminal core owns publication truth:

- `capturePresentation()` locks the session, refreshes pending scroll/view cache
  state if needed, copies the active `RenderCache`, and returns the captured
  presented generation in
  [session_rendering.zig](/home/home/personal/zide/src/terminal/core/session_rendering.zig).
- `publishedGeneration()`, `presentedGeneration()`,
  `notePresentedGeneration()`, and `acknowledgePresentedGeneration()` define the
  publication/presentation lifecycle surface in
  [session_rendering.zig](/home/home/personal/zide/src/terminal/core/session_rendering.zig)
  and
  [session_rendering_retirement.zig](/home/home/personal/zide/src/terminal/core/session_rendering_retirement.zig).
- `view_cache` owns active render-cache publication and dirty/damage semantics
  below that seam.

### Terminal widget

The widget owns terminal-content consumption and upload planning:

- `TerminalWidget.draw()` captures the published render cache into
  `self.draw_cache` via
  [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig).
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
  owns texture-update orchestration, terminal-local draw state, probe
  registration, and terminal composition into the current renderer target.
- [terminal_widget_draw_texture.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw_texture.zig)
  owns the rules for turning cache dirty state into full vs partial texture
  update plans.

### Renderer

The renderer owns frame and swap execution:

- `beginFrame()` and `endFrame()` in
  [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig) own target
  binding, swap timing, swap-edge fallbacks, and suspicious-frame capture.
- The renderer owns `SDL_GL_SwapWindow`, but not terminal publication truth.
- The renderer currently also owns the optional whole-frame offscreen compose
  experiment, though that path is not yet trustworthy.

### Presentation feedback

Presentation acknowledgement currently flows back through widget draw outcome:

- `terminal_widget_draw.zig` returns `PresentationFeedback` as `DrawOutcome`.
- `TerminalWidget.finishFramePresentation()` forwards that to the session in
  [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig).
- `completePresentationFeedback()` in
  [session_rendering.zig](/home/home/personal/zide/src/terminal/core/session_rendering.zig)
  decides whether to retire published damage.

## Proven Correct Seams

- Publication generation lineage is coherent enough for this lane. The active
  remaining bug is no longer explained by generation handoff drift; the current
  design notes already narrow that theory down.
- Backend publication is not the primary active seam for the old scrolling lane:
  `capturePresentation()` still sees `dirty=partial`, widget planning still
  chooses partial upload, and acknowledgement retires those generations
  coherently.
- The renderer-side probes show the pre-swap pipeline is correct:
  - widget `phase=final` correct
  - renderer `phase=pre_swap_back` correct
  - renderer `phase=pre_swap_front` correct
  - only `phase=present` becomes wrong

That means current terminal publication and terminal-texture update planning are
good enough to reach the pre-swap render target correctly for this lane.

## Ambiguous Or Overloaded Seams

### Terminal widget is still an overloaded handoff layer

[terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
still mixes:

- generation comparison
- terminal texture update policy
- mitigation policy integration
- suspicious-frame probe registration
- final terminal draw orchestration
- feedback that influences presentation retirement

That makes the widget both the consumer of publication truth and a partial owner
of presentation correctness.

### Presentation retirement is still driven by widget-local texture truth

`completePresentationFeedback()` acknowledges a presented generation when the
widget reports `texture_updated` or the presented cache was already clean. That
means retirement safety currently depends on widget-declared GPU upload truth
instead of an explicit renderer-owned present contract.

### Renderer owns swap behavior but not authoritative present semantics

The renderer owns swap, fallback experiments, and suspicious-frame probes, but
the final contract for what counts as an authoritative presented frame is still
implicit across widget and renderer behavior. That is exactly the seam where the
remaining Wayland bug now lives.

### Diagnostics are cross-owned

The decisive proof path currently depends on:

- silent `bg/glyph/window/final` baselines kept in the widget
- `pre_swap_*` and `present` capture in the renderer

That split works for debugging, but it means present validation is not yet a
first-class, explicitly owned subsystem boundary.

## Recommended Ownership Boundaries

### Terminal core should own publication truth only

Keep terminal core ownership limited to:

- generation truth
- render-cache publication
- dirty/damage semantics
- acknowledgement/retirement rules

The core should not grow default-framebuffer or swap-path ownership.

### Terminal widget should own terminal-content upload and composition preparation

The widget should remain responsible for:

- consuming `RenderCache`
- owning terminal-local textures and upload policy
- drawing terminal content into a renderer-provided composition surface

But it should stop being the implicit owner of final presentation correctness.

### Renderer should own the authoritative composition/present contract

The renderer should explicitly own:

- whether final composition is authoritative offscreen vs direct default-target
- the rules for presenting a valid frame on destructive-swap Wayland/EGL
- swap-edge behavior and final present discipline
- final presentation diagnostics

This is the seam that needs redesign, and it should become a clear renderer
boundary rather than a cross-layer implication.

### Presentation acknowledgement should become renderer-defined

The current `texture_updated` feedback is too widget-local. The redesign should
move toward a renderer-owned notion of:

- which generation actually made it through the authoritative composition path
- when it is safe to retire published damage

The widget can report upload/composition facts, but the renderer should define
what counts as a presented frame.

### Diagnostics should become a stable presentation contract

Keep the current probes, but formalize ownership:

- widget exposes stable pre-present baselines
- renderer owns pre-swap/present capture and interpretation
- the combined validation path should survive the redesign as a documented
  present diagnostic surface

## Bottom Line

The remaining Wayland ghost no longer points at terminal publication ownership.
It points at an under-specified renderer/present contract. The redesign should
therefore preserve the current terminal-core publication boundary, keep the
widget focused on terminal-content upload/composition, and move final present
authority into an explicit renderer-owned architecture that does not depend on
preserved default-framebuffer semantics.
