# Wayland Present Design Brief

## Purpose

Define the renderer/presentation redesign scope for the surviving Wayland
scrolling ghost bug, capture the facts already proven, and set the quality bar
and decision criteria before implementation work starts.

This document is intentionally high-level. Detailed investigation slices and
temporary reports belong in `WAYLAND_PRESENT_RESEARCH_TOPICS.md` and the
report files it points to.

## Current Issue

Zide still has a surviving Wayland presentation bug in the older `nvim`
text-buffer cursorline scrolling lane. Under smooth cursorline scrolling,
stale/ghosted text and guide lines survive on screen even though the renderer's
pre-swap output is correct.

The symptom is not the earlier `wiki_life` lane. That output-driven terminal
buffer bug was traced to publication ownership and fixed separately.

## Proven Facts

- The remaining live repro is the older `nvim` text-buffer cursorline scrolling
  ghost lane.
- Backend publication is no longer the active primary seam for this lane:
  `capturePresentation()` still sees `dirty=partial`, widget planning still
  chooses partial upload, and presented-generation acknowledgement retires those
  generations coherently.
- On suspicious frames, sampled rows/cells are correct through:
  - widget `phase=final`
  - renderer `phase=pre_swap_back`
  - renderer `phase=pre_swap_front`
- The visible result becomes wrong only at `phase=present`.
- Post-swap reads of both observed default-framebuffer sides agree on the wrong
  image, even when both pre-swap reads were correct.
- `finish_before_swap` and `finish_before_and_after_swap` did not materially
  improve the bug.
- `copy_back_to_front` helped somewhat, but did not fully fix it.
- SDL/EGL startup introspection on the failing Wayland path reports:
  - realized SDL GL `doublebuffer=0`
  - `EGL_RENDER_BUFFER = EGL_BACK_BUFFER`
  - `EGL_SWAP_BEHAVIOR = EGL_BUFFER_DESTROYED`
  - config `preserved_bit = 0`
- Therefore post-swap default-framebuffer contents must be treated as probes,
  not as preserved-buffer authority.

## Problem Statement

Zide's current renderer/present path still depends too heavily on assumptions
that are not reliable on the active Wayland/EGL stack. The current stack must
be redesigned so correctness does not depend on default-framebuffer preservation
semantics or ambiguous front/back behavior across swap.

## Design Goal

Produce a renderer/presentation architecture for Zide's current SDL + OpenGL +
Wayland stack that is:

- reliable under destructive-swap Wayland/EGL behavior
- native and lightweight, with no unnecessary compositor-facing churn
- compatible with Zide's embedded-style constraints
- fast enough to preserve smooth terminal/editor scrolling
- explicit about ownership between VT publication, widget texture updates,
  renderer composition, and final presentation

## Quality Bar

The target is best-in-class native terminal/editor rendering quality. Matching
or exceeding the practical robustness of `ghostty`, `kitty`, `foot`, and
`wezterm` is the bar, while preserving Zide's stronger embedded/resource
constraints.

## Constraints

- Zide is currently SDL + OpenGL based.
- Current live platform focus is Wayland.
- The architecture must not assume `EGL_BUFFER_PRESERVED`.
- The architecture must keep damage, redraw, and upload work narrow where safe.
- The architecture must stay explainable: each seam should have one clear owner.
- Debugging and observability should remain first-class, but instrumentation
  should not materially perturb the hot path.

## Non-Goals

- Do not treat the old mitigation path as the design solution.
- Do not optimize around a broken whole-frame offscreen experiment as-is.
- Do not broaden architecture complexity just to preserve old incorrect seams.
- Do not prematurely commit to a compositor- or driver-specific workaround
  without first defining the durable stack contract.

## Main Design Question

What is the most reliable and lightweight presentation architecture for Zide on
SDL/OpenGL/Wayland when swap is destructive and default-framebuffer semantics
cannot be treated as preserved state?

## Candidate Design Space

At a high level, the main options appear to be:

1. Keep direct default-framebuffer composition, but make the contract fully
   destructive-swap-safe.
2. Move to an authoritative offscreen composition target and treat the default
   framebuffer as a one-frame present sink only.
3. Use a hybrid model where most UI composition is authoritative offscreen, but
   some narrow paths remain direct only if they are proven harmless and simpler.

The research phase should decide which of these is architecturally correct for
Zide's constraints rather than assuming the answer up front.

## Required Deliverables

- A map of the presentation seams and their intended ownership.
- A research set covering stack contract, reference designs, and integration
  risks.
- A consolidated technical writeup that compares viable designs and explains the
  best path forward.
- A final implementation plan with explicit migration steps and validation
  strategy.

## Reference Families

- Terminal architecture references:
  - `reference_repos/terminals/ghostty`
  - `reference_repos/terminals/foot`
  - `reference_repos/terminals/kitty`
  - `reference_repos/terminals/wezterm`
  - `reference_repos/terminals/rio`
- Backend/present-path authorities:
  - `reference_repos/backends/sdl`
  - `reference_repos/rendering/mesa`
  - `reference_repos/backends/wayland`
  - `reference_repos/backends/wayland_protocols`
  - `reference_repos/rendering/khronos_refpages_md`
  - `reference_repos/rendering/egl_registry`
  - `reference_repos/rendering/opengl_registry`

## Exit Condition For Design Phase

The design phase is complete only when:

- all important seams have an explicit research topic
- temporary reports exist for each topic
- the findings are consolidated into one technical writeup
- the resulting implementation plan is concrete enough to choose a single path
  forward without re-opening first principles
