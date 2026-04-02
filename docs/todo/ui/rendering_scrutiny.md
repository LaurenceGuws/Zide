# Rendering Scrutiny

## Scope

Track the remaining SDL3/OpenGL renderer architecture work after the residue
purge.

This queue exists to answer one question:

- what still prevents `src/ui/renderer.zig` from reading like a serious
  renderer host over one scene/present truth?

This is not a general UI roadmap.
It is the execution queue for the remaining renderer-center campaign.

## Authority

Use these as the current authority set for this lane:

- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `docs/research/SDL_GL_RENDERER_SCRUTINY_2026-04-02.md`
- `docs/review/SDL_GL_RENDERER_AUDIT_2026-04-02.md`

## Current State

The easy SDL/GL lies are mostly dead:

- startup probe shell removed
- input bring-up noise removed
- fake backend selector removed
- fake forwarding shells removed
- product-specific renderer target APIs removed from `renderer.zig`
- dead SDL input slab removed

What remains is not residue. It is ownership concentration.

`src/ui/renderer.zig` is still too large and too semantically mixed.

## Target Read

The renderer center should read as:

- renderer-owned scene/present truth
- GL resource and target lifecycle
- draw/text execution entrypoints
- stable host-facing render contract

It should not read as:

- the owner of all input/runtime state
- the owner of window chrome policy
- the owner of presentation diagnostics/capture policy
- the owner of every font/zoom/UI-scale policy detail

## Remaining Issue Map

### RS-01 Renderer State Bag Is Still Too Broad

Current pressure:

- `src/ui/renderer.zig` still stores GL state, font state, retained targets,
  input state, clipboard state, window chrome state, and present trace/capture
  state in one type.

Primary references:

- `src/ui/renderer.zig:325`
- `src/ui/renderer.zig:471`

Done when:

- the renderer struct reads like one owned rendering center instead of a grab
  bag of unrelated runtime domains.

### RS-02 Init/Deinit Still Mix Too Many Responsibilities

Current pressure:

- constructor/destructor still assemble and tear down:
  - SDL window/context
  - font path resolution and font state
  - scale/zoom defaults
  - window chrome owners
  - text input setup
  - render resources

Primary references:

- `src/ui/renderer.zig:528`
- `src/ui/renderer.zig:819`

Done when:

- setup/teardown read as renderer assembly over narrower sub-owners instead of
  one giant lifecycle slab.

### RS-03 Input State Still Lives In Renderer

Current pressure:

- key/mouse queues, composition state, focus queue, resize flag, and wait-event
  staging still live directly on `Renderer`.

Primary references:

- `src/ui/renderer.zig:422`
- `src/ui/renderer.zig:456`
- `src/ui/renderer.zig:1257`
- `src/ui/renderer.zig:1731`

Done when:

- renderer input state has a narrower owner or a clearly justified renderer
  boundary.

### RS-04 Window Chrome Still Lives In Renderer

Current pressure:

- Windows frame/snap/chrome state and hit-testing still live directly in the
  renderer center.

Primary references:

- `src/ui/renderer.zig:406`
- `src/ui/renderer.zig:410`
- `src/ui/renderer.zig:1347`
- `src/ui/renderer.zig:1453`

Done when:

- host window-chrome ownership is narrower and no longer inflates the renderer
  core.

### RS-05 Present Capture And Trace Still Live In Renderer

Current pressure:

- present trace bookkeeping and screenshot capture arming still live directly
  on `Renderer`.

Primary references:

- `src/ui/renderer.zig:458`
- `src/ui/renderer.zig:470`
- `src/ui/renderer.zig:1007`
- `src/ui/renderer.zig:1176`

Done when:

- present diagnostics/capture either have a narrower owner or clearly justify
  their place in the renderer center.

### RS-06 Font/Zoom/UI-Scale Policy Still Inflates Renderer

Current pressure:

- font config, font caches, ligature config, zoom state, and UI-scale policy
  still occupy a major part of the renderer center.

Primary references:

- `src/ui/renderer.zig:364`
- `src/ui/renderer.zig:400`
- `src/ui/renderer.zig:550`
- `src/ui/renderer.zig:663`
- `src/ui/renderer.zig:838`
- `src/ui/renderer.zig:980`

Done when:

- renderer-facing font/runtime surface is smaller and the remaining font/zoom
  ownership is deliberate instead of inherited.

## Recommended Order

1. `RS-03` Input state
2. `RS-04` Window chrome
3. `RS-05` Present capture/trace
4. `RS-06` Font/zoom/UI-scale policy
5. `RS-02` Constructor/destructor simplification after the above owners shrink
6. `RS-01` Final renderer-center reassessment

## Rules For This Lane

- No extraction theater.
- No new fake helper files.
- No behavior changes unless explicitly re-scoped.
- Each cut should remove a real ownership lie through the full affected
  surface.
- Keep validating with `zig build test` and `zig build`.
