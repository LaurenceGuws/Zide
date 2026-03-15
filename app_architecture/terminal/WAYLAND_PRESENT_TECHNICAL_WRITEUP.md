# Wayland Present Technical Writeup

## Purpose

Consolidate the Wayland present research set into one technical decision
document for Zide's renderer/presentation redesign.

This writeup is the bridge between:

- the high-level brief in
  [WAYLAND_PRESENT_DESIGN_BRIEF.md](/home/home/personal/zide/app_architecture/terminal/WAYLAND_PRESENT_DESIGN_BRIEF.md)
- the temporary topic reports under
  [research/wayland_present](/home/home/personal/zide/docs/research/terminal/wayland_present)
- the implementation plan that will follow from this document

## Problem Summary

Zide still has a surviving Wayland presentation bug in the older `nvim`
text-buffer cursorline scrolling lane. The important proven fact is now stable:

- terminal publication is coherent enough
- widget texture planning is coherent enough
- pre-swap rendering is correct
- the visible result becomes wrong only across/past presentation on the current
  SDL + OpenGL + Wayland/EGL path

At the same time, the active stack contract is explicitly hostile to
default-framebuffer retention:

- `EGL_RENDER_BUFFER = EGL_BACK_BUFFER`
- `EGL_SWAP_BEHAVIOR = EGL_BUFFER_DESTROYED`
- preserved-swap support is not present on the chosen config

That means the surviving design problem is not “how do we tune one more swap
fallback?” It is:

How should Zide own rendering and presentation so correctness does not depend
on preserved default-framebuffer state on Wayland?

## Consolidated Findings

### 1. SDL/Wayland present is not a thin `swap()` abstraction

From [wp_01_sdl_wayland_egl_contract.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_01_sdl_wayland_egl_contract.md):

- SDL's generic `SDL_GL_SwapWindow()` documentation is too coarse to be the
  real authority on Wayland.
- SDL's Wayland backend forces EGL swap interval to zero and manages pacing
  itself with frame callbacks and timeout behavior.
- SDL's Wayland swap ordering depends on its own backend state, including
  internal `double_buffer` behavior.
- SDL may skip a swap entirely depending on shell-surface state.

Implication:

- Zide must not architect around a simplistic “render to default framebuffer,
  call swap, done” model on this backend.

### 2. The EGL window-surface contract is destructive by default

From [wp_02_mesa_egl_surface_semantics.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_02_mesa_egl_surface_semantics.md):

- Mesa's generic EGL surface initialization treats window-surface swap as
  destructive unless preserved-swap support is explicitly advertised and used.
- `eglQuerySurface(EGL_RENDER_BUFFER)` reports the requested surface render
  buffer, while `eglQueryContext(EGL_RENDER_BUFFER)` is the actual context-side
  authority.
- Buffer-age / partial-update paths are optional, extension-gated, and not
  suitable as baseline correctness machinery.

Implication:

- Default-framebuffer contents after swap are not a valid retained-state
  foundation for Zide's renderer architecture.

### 3. The best native references do not trust vague default-buffer behavior

From [wp_03_reference_terminal_architectures.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_03_reference_terminal_architectures.md):

- Ghostty isolates framebuffer ownership explicitly.
- Foot keeps authoritative buffer contents and explicit damage under its own
  control and then submits to Wayland deliberately.
- Kitty owns the backend seam directly and does not pretend EGL/Wayland is a
  generic hidden implementation detail.
- WezTerm and Rio both expose explicit pre-present boundaries instead of
  collapsing present into one opaque swap call.

Implication:

- The right design direction is explicit ownership, explicit present boundary,
  and authoritative internal frame state before the final compositor-facing
  step.

### 4. Zide's current ownership is almost right, except at the final seam

From [wp_04_zide_present_seam_ownership.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_04_zide_present_seam_ownership.md):

- terminal core already owns publication truth
- terminal widget already owns terminal-content consumption and texture-update
  planning
- renderer already owns frame/swap execution

The problem is that final presentation semantics are still under-specified and
cross-owned:

- presentation retirement still partly depends on widget-local upload truth
- renderer owns swap behavior but not yet a fully authoritative present
  contract

Implication:

- The redesign should preserve terminal-core and widget responsibilities, while
  making renderer-owned scene composition and present semantics explicit.

### 5. Narrow damage should survive; only the final present boundary should
become disposable

From [wp_05_damage_upload_composition_strategy.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_05_damage_upload_composition_strategy.md):

- Full redraw everywhere is not acceptable.
- Current row/span-local terminal damage and partial uploads are valuable and
  should not be thrown away.
- The strongest design option is a hybrid model:
  - keep narrow retained widget-local targets
  - introduce an authoritative renderer-owned scene compose target
  - treat the default framebuffer as a one-frame present sink only

Implication:

- The redesign should not be “swap fallback but stronger.”
- It should be “authoritative internal scene ownership, cheap final present.”

### 6. Resize and display migration are first-class present concerns

From [wp_06_resize_scale_display_migration.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_06_resize_scale_display_migration.md):

- drawable pixels are already the right authority for actual render targets
- Zide's current two-stage resize flow is structurally good:
  - immediate metric/UI-scale refresh
  - deferred PTY row/column resize
- display migration and scale changes are common in the live environment and
  must be treated as hard composition invalidation boundaries

Implication:

- Any new scene target must be recreated/revalidated from drawable pixel size
  and must treat display/scale hops as explicit invalidation boundaries.

### 7. The diagnostic contract already points at the right future shape

From [wp_07_observability_validation_contract.md](/home/home/personal/zide/docs/research/terminal/wayland_present/wp_07_observability_validation_contract.md):

- startup contract logs are cheap and decisive
- suspicious-frame probes are useful when they are issue-scoped and
  emission-gated
- broad per-frame logging perturbs the live bug too much

Implication:

- The redesign should keep:
  - startup EGL/SDL contract logs
  - one renderer-owned suspicious-frame probe path
  - explicit state dumps
- and avoid broad permanent trace families

## Design Options

### Option A: Keep direct default-framebuffer composition

Shape:

- preserve current broad renderer model
- try to make direct default-framebuffer rendering safe under destructive swap
- continue using swap fallbacks and probe-driven validation

Pros:

- minimal architectural change
- lowest additional target memory

Cons:

- fights the actual Wayland/EGL contract instead of aligning with it
- keeps final present ownership ambiguous
- leaves the surviving bug class in the same seam family

Conclusion:

- reject as the main path

### Option B: Authoritative whole-scene offscreen composition

Shape:

- entire UI frame is composed into a renderer-owned scene target
- default framebuffer is used only for a final present draw/copy

Pros:

- correctness becomes independent of default-framebuffer retention
- scene ownership becomes explicit and renderer-owned

Cons:

- easy to implement badly as a full-redraw-everything design
- risks wasting work if narrow widget-local damage is ignored

Conclusion:

- architecturally sound, but incomplete unless it preserves narrow local
  damage/value inside the scene

### Option C: Hybrid retained widget targets + authoritative scene target

Shape:

- keep current narrow widget-local targets, especially terminal textures
- keep current terminal/editor damage ownership where it already works
- introduce a renderer-owned scene compose target as the authoritative frame
  image
- treat the default framebuffer as a one-frame sink only

Pros:

- aligns with the stack contract
- preserves the embedded/native performance bar
- gives explicit ownership:
  - terminal core owns publication
  - widget owns upload/composition prep
  - renderer owns scene truth and present
- maps well to the strongest reference patterns

Cons:

- requires a careful frame graph and invalidation contract
- requires retiring the current ambiguous direct-default ownership path cleanly

Conclusion:

- best current path for Zide

## Recommended Architecture

### Core decision

Zide should move to a hybrid architecture with:

- retained, narrow widget-local targets for terminal/editor content
- an authoritative renderer-owned scene composition target
- a disposable default-framebuffer present sink

### Ownership model

#### Terminal core

Owns only:

- publication generations
- render-cache truth
- dirty/damage semantics
- acknowledgement/retirement rules

It should not own present semantics or default-framebuffer behavior.

#### Widgets

Own only:

- consuming published render state
- local texture ownership
- partial/full upload planning
- drawing into a renderer-provided composition target

They should not define what counts as a valid final presented frame.

#### Renderer

Must explicitly own:

- scene target lifecycle
- scene invalidation policy
- final pre-present boundary
- default-framebuffer present step
- renderer-side present diagnostics

The renderer becomes the authority on “what scene is being presented,” not just
“when swap happens.”

### Scene target rules

- allocate from drawable pixel size only
- recreate/revalidate on:
  - pixel-size changes
  - display changes
  - display-scale changes
  - relevant scene-format changes
- treat display migration as a hard composition invalidation boundary

### Final present rules

- by the time the renderer touches the default framebuffer, semantic scene
  composition should already be complete
- the final step should be a simple present copy/draw
- post-swap default-framebuffer contents must never be treated as retained
  scene truth

### Fast-path rules

- preserve row/span-local terminal uploads
- preserve current widget-local partial planning where it is already correct
- flatten only at the scene composition boundary
- make full-scene rebuilds explicit and rare

## Recommended Migration Shape

This is not the final implementation plan yet, but the sequence should look
roughly like this:

1. Define and document the renderer-owned scene target contract.
2. Introduce the scene target without changing terminal publication ownership.
3. Route terminal/editor/widget drawing into the scene target.
4. Reduce the default-framebuffer path to final present only.
5. Move presentation acknowledgement semantics toward renderer-owned present
   truth rather than widget-local `texture_updated` truth.
6. Re-run the existing low-perturbation validation on the old `nvim`
   cursorline lane.
7. Only then decide which legacy swap-fallback experiments can be removed.

## Risks and Watchpoints

- A naive scene target implementation could regress performance by redrawing too
  much.
- Resize/display migration can invalidate scene targets more often than a
  single-monitor mental model suggests.
- Present acknowledgement semantics will need a careful transition to avoid
  reintroducing publication-retirement bugs.
- The current broken offscreen experiment must not be mistaken for the intended
  architecture; the direction is correct, but that implementation path is not
  authoritative.

## Validation Requirements

The implementation plan should preserve:

- startup SDL/EGL/Wayland contract logging
- one low-perturbation suspicious-frame present probe
- the old raw repro path for the surviving `nvim` cursorline ghost
- explicit state dumps where they add durable value

Acceptance should require:

- the old `nvim` cursorline lane no longer ghosts under the raw path
- no regression in narrow terminal/editor damage behavior
- no obvious smoothness collapse from brute-force full redraw behavior

## Decision

The best current path forward is:

Implement a hybrid presentation architecture in which Zide-owned widget targets
remain narrow and retained, a renderer-owned scene target becomes the
authoritative composed frame, and the default framebuffer is treated purely as
the final present sink on Wayland.

That is the design most consistent with:

- the actual SDL/Wayland/EGL contract
- Mesa/Khronos surface semantics
- the strongest native reference architectures
- Zide's embedded/native performance bar
- the current ownership map of Zide's renderer stack
