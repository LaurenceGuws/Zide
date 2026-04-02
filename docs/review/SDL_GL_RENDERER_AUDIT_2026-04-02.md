# SDL/GL Renderer Audit

Date: 2026-04-02

## Scope

Review the current SDL3/OpenGL renderer implementation as a whole, with focus
on:

- renderer ownership shape
- scene/present contract drift
- SDL/GL host seam maturity
- backend surface honesty

This review is branch evidence for the SDL/GL scrutiny lane. Current technical
authority remains:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`
- `docs/todo/terminal/wayland_present.md`

## Findings

### 1. `src/ui/renderer.zig` is still the dominant fake center

Severity: high

`src/ui/renderer.zig` still acts as the real rendering architecture instead of
an honest renderer host/facade.

What it owns at once:

- frame lifecycle:
  - `beginFrame`
  - `submitFrame`
- scene-target invalidation and recreation:
  - `refreshSceneTargetContract`
  - `ensureSceneTarget`
  - `prepareSceneTarget`
  - `beginSceneFrame`
  - `drawSceneTargetToDefault`
- product-specific retained-target APIs:
  - `ensureTerminalTexture`
  - `beginTerminalTexture`
  - `drawTerminalTexture`
  - `ensureEditorTexture`
  - `beginEditorTexture`
  - `drawEditorTexture`
- unrelated semantic/runtime state:
  - input queues
  - text input state
  - clipboard buffer
  - zoom and UI scale policy
  - window chrome state
  - presentation capture state

Representative references:

- `src/ui/renderer.zig:1018`
- `src/ui/renderer.zig:1047`
- `src/ui/renderer.zig:1099`
- `src/ui/renderer.zig:1295`

Judgment:

- the scene-target model inside the file is good
- the ownership concentration around it is not

### 2. The live renderer API still contradicts the declared target contract

Severity: high

The architecture authority already says the steady renderer boundary should not
be product-specific. It explicitly calls out APIs like:

- `beginEditorTexture`
- `beginTerminalTexture`
- `drawEditorTexture`
- `drawTerminalTexture`

Those APIs are still live and central on the renderer surface today.

References:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md:25`
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md:166`
- `src/ui/renderer.zig:1305`
- `src/ui/renderer.zig:1313`
- `src/ui/renderer.zig:1324`
- `src/ui/renderer.zig:1383`

Judgment:

- the repo has already written down the right boundary
- the code is still knowingly shipping the old one

### 3. Scene ownership is structurally right, but product-retained-target
choreography still shapes the steady-state path

Severity: high

The healthy center of the renderer is already visible:

- collect display metrics
- refresh scene-target contract
- invalidate on drawable/display/render-scale changes
- compose one scene target
- draw scene to default framebuffer
- swap once

But the same type still owns target rebinding and product-specific composition
re-entry through `restoreMainCompositionTarget`.

References:

- `src/ui/renderer.zig:1018`
- `src/ui/renderer.zig:1157`
- `src/ui/renderer.zig:1182`
- `src/ui/renderer.zig:1211`
- `src/ui/renderer.zig:1243`

Judgment:

- renderer-owned scene truth exists
- product-specific retained-target orchestration still distorts the live API
  and control flow around that truth

### 4. The module split is still helper-oriented, not ownership-oriented

Severity: medium

There are many renderer submodules, but the split does not yet move the real
center of gravity enough.

Examples:

- `src/ui/renderer/targets.zig` is only a thin forwarder over
  `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer.zig` still imports and re-exports most of the live surface

References:

- `src/ui/renderer/targets.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer.zig`

Judgment:

- file count increased
- ownership clarity did not increase proportionally

### 5. The SDL/GL host seam is functionally decent but still reads like an
issue-era probe surface

Severity: medium

`src/ui/renderer/window_init.zig` does the necessary host work:

- SDL init
- GL attribute setup
- window creation
- context creation
- swap interval

But it also carries:

- realized-context logging
- Wayland native-handle logging
- EGL contract probing
- Linux icon application

References:

- `src/ui/renderer/window_init.zig:25`
- `src/ui/renderer/window_init.zig:104`
- `src/ui/renderer/window_init.zig:136`
- `src/ui/renderer/window_init.zig:252`
- `src/ui/renderer/window_init.zig:289`

SDL3 official docs support the underlying host model:

- `README-highdpi`
- `SDL_GL_SetAttribute`
- `SDL_GL_CreateContext`
- `SDL_GL_SwapWindow`

Judgment:

- the host seam is not obviously wrong
- it is still too mixed to read as mature

Status note after the first SDL/GL host seam cut:

- steady host setup now remains in `src/ui/renderer/window_init.zig`
- diagnostic/probe logging moved to
  `src/ui/renderer/window_init_diagnostics.zig`
- Linux window icon policy moved to
  `src/ui/renderer/window_icon_runtime.zig`

This improves the seam shape without changing behavior.

### 6. Backend surface honesty still lags runtime truth

Severity: medium

Build/runtime policy clearly says only `sdl_gl` is implemented.

Before the first code cut in this lane, the repo still visibly carried backend
stubs:

- `src/ui/renderer/backends/egl.zig`
- `src/ui/renderer/backends/wgl.zig`
- `src/ui/renderer/backends/metal.zig`
- `src/ui/renderer/backends/gles.zig`

References:

- `src/ui/renderer.zig:208`
- `build_system/bootstrap_policy.zig`

Judgment:

- this creates a maturity gap on first inspection
- either the repo has a real backend split or it should stop pretending to

## External Comparison

### SDL3 official docs

Useful authority:

- `https://wiki.libsdl.org/SDL3/README-highdpi`
- `https://wiki.libsdl.org/SDL3/SDL_GL_SetAttribute`
- `https://wiki.libsdl.org/SDL3/SDL_GL_CreateContext`
- `https://wiki.libsdl.org/SDL3/SDL_GL_SwapWindow`

Relevant pressure:

- logical size vs drawable pixel size must be explicit
- GL attributes belong before window creation
- realized values should be checked after context creation
- swap is main-thread and default-framebuffer oriented

Judgment against Zide:

- fundamentals broadly align
- the problem is architecture shape, not basic SDL3 misuse

### Ghostty

Useful references:

- `https://github.com/ghostty-org/ghostty/blob/main/src/renderer/OpenGL.zig`
- `https://github.com/ghostty-org/ghostty/blob/main/src/renderer/Thread.zig`

Relevant pressure:

- graphics API wrapper is much narrower
- render scheduling is separate from graphics API details
- host/runtime responsibilities are separated more cleanly

Judgment against Zide:

- the main weakness is ownership concentration
- not obviously incorrect GL mechanics

## Best Current Center

The strongest part of the current renderer is already the right one:

- renderer-owned scene target
- explicit contract from display metrics
- hard invalidation on drawable/display/render-scale changes
- one final scene-to-default draw
- one swap

This should be treated as the real center for future cuts.

## Recommended First Cuts

1. Narrow `src/ui/renderer.zig` around the scene-target/present center
   - move non-render semantic/runtime state out of the dominant renderer type

2. Start retiring product-specific renderer target APIs
   - editor/terminal-specific target ownership should stop defining the steady
     renderer boundary

3. Split the SDL/GL host seam into steady host setup vs issue-scoped probes
   - keep the useful diagnostics available
   - stop letting them define the host module shape

4. Make backend surface honesty match reality
   - remove or quarantine unsupported backend surfaces until there is a real
     backend split

## Bottom Line

Zide's SDL3/OpenGL renderer is not mainly held back by low-level GL correctness.

It is held back by ownership shape:

- one oversized renderer center
- a live API that still exposes declared-wrong product-specific seams
- a host seam still carrying issue-era probe gravity
- a backend surface that gestures beyond what actually exists
