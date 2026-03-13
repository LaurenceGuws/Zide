# WP-07 Observability and Validation Contract

## Scope

Define which diagnostics should survive the Wayland present redesign so future
render/present bugs remain isolatable without turning logging into the bug.

This topic covers:

- startup contract logging
- suspicious-frame probes
- tag ownership and log hygiene
- validation paths that are strong enough for renderer/present work

Primary local references:

- [.zide.lua](/home/home/personal/zide/.zide.lua)
- [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig)
- [window_init.zig](/home/home/personal/zide/src/ui/renderer/window_init.zig)
- [AGENT_HANDOFF.md](/home/home/personal/zide/docs/AGENT_HANDOFF.md)

## Current Useful Signals

1. Startup contract logging is already high-value and low-perturbation.

   [window_init.zig](/home/home/personal/zide/src/ui/renderer/window_init.zig)
   now logs:

   - realized SDL GL attrs
   - Wayland native handles
   - queried EGL surface/config contract

   Those logs gave a decisive result (`EGL_BACK_BUFFER` +
   `EGL_BUFFER_DESTROYED`) with almost no hot-path cost. This class of log
   should remain permanent.

2. The best live present probe is suspicion-driven, not per-frame.

   [renderer.zig](/home/home/personal/zide/src/ui/renderer.zig) only emits the
   expensive `terminal.ui.target_sample` cut when it detects a present-side
   mismatch. That is the right pattern: always-armed registration, but
   conditional emission.

3. Silent baseline capture in the widget is the correct compromise.

   [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig)
   still keeps `bg/glyph/window/final` baseline state for probes even when it
   no longer writes every intermediate log line every frame. That preserves
   diagnostic power without flooding the hot path.

4. Tag separation already paid off.

   Moving overlay attribution off `terminal.ui.target_sample` and onto
   `terminal.ui.overlay_probe` was the right move. It reduced noise and made
   the present probe authoritative again.

## Current Probe Costs

1. Broad per-frame probe families visibly perturb timing.

   The current handoff notes already show this: when row/glyph probes were
   broader and emitted continuously, scrolling became smoother-but-slower and
   the ghost got harder to trigger. That makes them poor default diagnostics for
   a timing-sensitive present bug.

2. Probe scope matters more than raw log count.

   The final useful shape was not “more logs”; it was:

   - a cheap cursor-centered registration cross
   - suspicious-frame-only renderer emission
   - a small startup SDL/EGL contract log

   That combination is close to the right permanent observability posture.

3. Broken classifier paths should not be kept as standard diagnostics.

   The whole-frame compose experiment behind
   `ZIDE_DEBUG_COMPOSE_MAIN_TO_OFFSCREEN` introduced its own failure mode. That
   kind of probe belongs behind explicit experimental switches, not in the
   normal diagnostic contract.

## Recommended Permanent Diagnostics

1. Keep startup contract logging permanent.

   These should remain available on demand under `sdl.gl` / `sdl.window`:

   - SDL realized GL attrs
   - Wayland native handles
   - EGL surface/config contract

   They are cheap and they establish the real platform contract before any
   frame-level reasoning starts.

2. Keep one renderer-owned suspicious-frame probe path.

   Preserve the current model:

   - widget registers a small stable probe set
   - widget keeps silent baselines
   - renderer emits the expensive frame cut only when mismatch is detected

   That should stay the main present-side diagnostic path.

3. Keep diagnostics tag-scoped and issue-local.

   `.zide.lua` should continue to enable only the minimum bug-scoped tags for a
   given investigation. Permanent tags should be few and semantically clean,
   not one giant mixed renderer namespace.

4. Preserve one explicit “contract dump” path.

   The terminal-local viewport dump and the startup EGL contract dump are both
   valuable because they export durable state rather than transient frame spam.
   Future renderer redesign work should prefer more state dumps and fewer broad
   per-frame traces.

5. Add diagnostics around the new authoritative present boundary once it
   exists.

   If Zide moves to an authoritative scene target, diagnostics should report:

   - scene-target size/format
   - composition invalidation reason
   - whether the frame reused prior scene state or rebuilt it
   - whether the final default-framebuffer pass was a simple present copy/draw

## Validation Strategy

1. Separate contract validation from hot-path validation.

   Startup EGL/SDL logs validate the platform contract.
   Suspicious-frame target samples validate the live render/present seam.

2. Validate redesigns against the real old authority lane.

   The surviving authority is still the `nvim` text-buffer cursorline scrolling
   ghost. The new architecture should be judged against that repro first, not
   against synthetic or easier lanes.

3. Require low-perturbation probes for acceptance.

   If a validation setup materially changes scroll smoothness or makes the bug
   disappear, it is not authoritative enough for the final decision.

4. Keep one way to force raw behavior.

   The mitigation-off path still matters because it preserves access to the
   original bug class while the design changes.

## Bottom Line

The permanent observability contract should be:

- cheap startup contract logs
- a narrow suspicious-frame renderer probe
- clean tag ownership
- explicit state dumps for durable surfaces

It should not be:

- broad per-frame trace families
- mixed-purpose log tags
- experiments that materially alter the timing of the live repro lane
