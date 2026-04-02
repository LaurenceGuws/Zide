# SDL/GL Renderer Scrutiny

Date: 2026-04-02

## Purpose

Start a focused renderer scrutiny round for Zide's SDL3/OpenGL path.

This writeup is not the long-term architecture authority. It is the branch
research brief for:

- the SDL3/OpenGL host seam
- renderer ownership shape
- scene/present contract drift
- backend maturity surface

Current technical authority still lives in:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`
- `docs/todo/terminal/wayland_present.md`

## Why This Round Exists

The app-hygiene lane improved the build surface and stripped a lot of
app/platform residue, but the next obvious maturity wall is the renderer
itself.

The branch question is no longer:

- "is SDL3 enough?"

That answer is already broadly yes.

The real question is:

- does Zide's SDL3/OpenGL rendering implementation read like a mature owned
  system, or like a still-transitional pile around one oversized center?

## Scope Under Scrutiny

This round is about the native rendering implementation as a whole:

- SDL init and window creation
- GL attribute/context setup
- display metrics, drawable size, and render scale
- renderer-owned scene target lifecycle
- subsystem retained targets
- final scene-to-default present
- backend surface honesty

Primary code under scrutiny:

- `src/ui/renderer.zig`
- `src/ui/renderer/window_init.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/targets.zig`
- `src/platform/window.zig`
- `src/platform/window_metrics.zig`
- `src/platform/sdl_api.zig`

## External Comparison Set

The verified external standard for this round is:

### Official SDL3 docs

- `https://wiki.libsdl.org/SDL3/README-highdpi`
- `https://wiki.libsdl.org/SDL3/SDL_GL_SetAttribute`
- `https://wiki.libsdl.org/SDL3/SDL_GL_CreateContext`
- `https://wiki.libsdl.org/SDL3/SDL_GL_SwapWindow`

These are the authority for:

- high-DPI/window-pixel behavior
- GL attribute setup timing
- context creation ownership
- swap semantics and main-thread expectations

### Architecture comparator

The best serious renderer comparator currently verified is Ghostty:

- `https://github.com/ghostty-org/ghostty/blob/main/src/renderer/OpenGL.zig`
- `https://github.com/ghostty-org/ghostty/blob/main/src/renderer/Thread.zig`

Important limitation:

- Ghostty is not an SDL3/OpenGL peer in the narrow runtime sense on Linux
- it is still useful because its renderer/backend/scheduling ownership split is
  much cleaner than Zide's current shape

What this means in practice:

- use SDL3 docs as host/runtime authority
- use Ghostty as renderer-architecture pressure
- do not cargo-cult Ghostty runtime-specific decisions

## Current High-Confidence Findings

### 1. Zide's SDL3/OpenGL fundamentals are broadly correct

The live path already aligns with the main SDL3 rules:

- GL attributes are configured before window creation
- GL context is created and made current explicitly
- drawable pixel size is treated separately from logical window size
- a renderer-owned scene target exists
- final present happens once through `SDL_GL_SwapWindow`

This means the main issue is not "wrong basic SDL3/OpenGL usage."

### 2. `src/ui/renderer.zig` is still the dominant fake center

`src/ui/renderer.zig` remains the real architectural problem in this lane.

It currently owns too much at once:

- frame lifecycle
- scene-target invalidation/recreation
- editor/terminal-specific retained target APIs
- fonts and font policy
- input state and text input state
- clipboard, zoom, UI scale, and window-chrome state
- screenshot and present diagnostics

The scene-target model inside it is healthy.
The file ownership shape around that model is not.

### 3. The live renderer API still contradicts the declared target contract

`app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md` already says the
steady renderer boundary should avoid product-specific APIs like:

- `ensureEditorTexture`
- `beginEditorTexture`
- `drawEditorTexture`
- `ensureTerminalTexture`
- `beginTerminalTexture`
- `drawTerminalTexture`

Those APIs are still live on `src/ui/renderer.zig`.

So the repo has already written down the right boundary but is still shipping
the old one.

Progress note, 2026-04-02:

- retained-target implementation moved into
  `src/ui/renderer/retained_targets_runtime.zig`
- widget/view consumers now route through
  `src/ui/renderer/retained_surface_api.zig`
- the raw product-specific renderer methods still exist, but they are no longer
  the primary widget-facing surface

### 4. The SDL/GL host seam is functionally decent but still reads like an
investigation seam

At the start of this round, `src/ui/renderer/window_init.zig` did real host
work, but it also carried:

- realized-context logging
- Wayland native-handle logging
- EGL surface contract probing
- Linux window icon setup

That mix made the host seam read less like a mature narrow runtime boundary and
more like an accumulated issue-era probe surface.

### 5. Backend maturity still looks aspirational from the outside

Build/runtime truth says only `sdl_gl` is real.

Before this scrutiny round started, the repo still visibly carried backend
stubs such as:

- `src/ui/renderer/backends/egl.zig`
- `src/ui/renderer/backends/wgl.zig`
- `src/ui/renderer/backends/metal.zig`
- `src/ui/renderer/backends/gles.zig`

That creates a first-glance maturity gap:

- either there is a real backend split
- or there is not

Right now the surface still gestures toward one that does not actually exist.

## Focus Areas

### Focus 1: Renderer center of gravity

Question:

- what still makes `src/ui/renderer.zig` the de facto rendering architecture
  instead of just the renderer host?

Targets:

- `src/ui/renderer.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/draw_ops.zig`
- `src/ui/renderer/text_runtime.zig`

Expected pressure:

- mixed ownership
- helper-oriented splits that do not move the real center
- product-specific API leaks

### Focus 2: SDL/GL host seam

Question:

- where do SDL3 window/context/high-DPI rules end and Zide-specific
  workaround/probe logic begin?

Targets:

- `src/ui/renderer/window_init.zig`
- `src/platform/window.zig`
- `src/platform/window_metrics.zig`
- `src/platform/sdl_api.zig`

Expected pressure:

- setup vs diagnostics blur
- issue-era Wayland/EGL probing still living in steady host init
- platform-specific host policy that may not defend its location

Progress note, 2026-04-02:

- steady host setup remains in `src/ui/renderer/window_init.zig`
- the temporary SDL/GL/Wayland startup probe shell was removed after the
  migration investigation
- Linux window icon application now lives in
  `src/ui/renderer/window_icon_runtime.zig`

### Focus 3: Scene/present contract drift

Question:

- where does live code still violate the promised renderer-owned scene /
  default-framebuffer-as-sink model?

Targets:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `docs/todo/terminal/wayland_present.md`
- `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`
- `src/ui/renderer.zig`
- widget draw paths that still consume renderer target APIs

Expected pressure:

- scene target is the real center in theory
- product-retained-target choreography still shapes steady-state control flow

### Focus 4: Backend maturity surface

Question:

- which seams are real backend authority and which are placeholder theater?

Targets:

- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/targets.zig`
- build/runtime renderer backend policy

Expected pressure:

- one real backend
- a runtime/build surface that should not gesture beyond that
- thin forwarder modules that do not create honest boundaries

## Subagent Angles Used For This Round

### 1. Renderer Ownership Auditor

Output expected:

- ranked fake centers
- product-specific renderer API leaks
- files/functions that still own too much truth

### 2. SDL3 Host Seam Auditor

Output expected:

- exact SDL3 alignments
- overcomplications
- immature host/probe seams

### 3. Contract Drift Auditor

Output expected:

- promises made by renderer/present docs
- live APIs that still contradict them
- top cuts required for honesty

### 4. Reference Comparator

Output expected:

- what Ghostty separates that Zide still collapses
- what is transferable
- what is runtime-specific and should not be copied mechanically

## Initial Branch Judgment

The likely first real target in the SDL/GL lane is not:

- OpenGL correctness tweaking
- another Wayland-only probe family
- speculative backend expansion

It is:

- `src/ui/renderer.zig` as the dominant fake center around an otherwise good
  scene-target design

That means the first high-value cuts should probably aim at:

1. narrowing the live renderer API away from product-specific target ownership
2. isolating the SDL/GL host seam from diagnostic/probe clutter
3. making backend surface honesty match actual runtime truth

Progress note, 2026-04-02:

- the implementation for editor/terminal retained-target operations now lives
  under `src/ui/renderer/retained_targets_runtime.zig`
- `src/ui/renderer.zig` still exposes the same public methods for now, but no
  longer owns that implementation slab directly

## Next Deliverable

The next branch deliverable should be a ranked SDL/GL scrutiny memo with:

- findings ordered by severity
- code references
- SDL3/renderer-reference crosschecks
- a short list of the highest-value structural cuts
