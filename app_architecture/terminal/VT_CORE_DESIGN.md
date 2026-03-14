# VT Core Design

Date: 2026-03-10

Status note, 2026-03-14:

- The initial VT/render rewrite phase is no longer the main active lane.
- The current phase is post-rewrite bug hunting, compatibility hardening, and
  native/FFI convergence against the rewritten architecture.
- Recently closed native compatibility bugs:
  - Codex inline resume history now feeds real primary scrollback on the
    rewritten path instead of collapsing to the visible pre-viewport band.
  - Zig `std.Progress` redraw now rewrites in place correctly because
    reverse-index (`ESC M`) dispatch no longer falls through a dead C1 control
    path.
  - Focused native input latency is back in the good pre-rewrite band because
    idle waiting now wakes on SDL events instead of sleeping blindly through
    focused input windows.

Purpose: define the exact ownership split for the next terminal-core redesign
lane so code changes do not drift between "session cleanup", "FFI cleanup", and
"embed-friendly cleanup".

This doc is the concrete follow-up to:

- `app_architecture/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`
- `app_architecture/terminal/vt_core_rearchitecture_todo.yaml`

## Main Goal

Turn Zide's terminal backend into a real embeddable VT engine with:

- a pure terminal emulation core
- a first-class FFI boundary
- transport-agnostic host integration
- renderer-agnostic snapshots and damage

Desktop PTY-backed Zide remains a supported host, but it must stop defining the
architectural center.

## Target Types

### 1. `TerminalCore`

This becomes the engine-owned center.

It owns:

- parser state
- protocol execution
- primary/alt screens
- history/scrollback
- selection semantics
- terminal modes
- OSC/CSI/DCS/APC state
- kitty graphics state
- title/cwd/semantic prompt/backend metadata that belongs to terminal semantics
- damage generation
- snapshot generation

It does not own:

- PTY
- host threads
- workspace tabs
- SDL/widget/render state
- process lifecycle policy

Expected direction:

- `src/terminal/core/terminal_session.zig` stops being the owner of the above
- the future public engine center should live under `src/terminal/core/` or
  `src/terminal/engine/`

### 2. `TerminalTransport`

This is the byte-stream boundary around the core.

It owns host-specific delivery of:

- input bytes into the terminal
- output bytes from the host side into the core
- resize notifications
- host lifecycle/wakeup integration

There should be multiple implementations:

- PTY transport
- external transport adapter
- test/replay transport

This is the key requirement for:

- Flutter hosts
- mobile SSH-backed sessions
- non-PTY embedded environments

`TerminalTransport` should not own terminal semantics. It only moves bytes and
host signals.

Important flood-handling bias:

- transport/read ingress should stay aggressive and non-semantic
- flood fairness should be solved by bounded parser/publication/render wake
  policy, not by teaching the reader to pace itself heuristically
- startup flood behavior may still need a host/runtime policy layer, but the
  transport itself should not become a second redraw scheduler

## Current Real-Config `nvim` Cursor-Step Authority

The current settled real-config `nvim` lane on `src/app_logger.zig` is now
clean enough to use as authority instead of generic "plugin-heavy `nvim` feels
broad" complaints.

Settled controls:

- narrow, non-shift:
  - `20G + l`
  - `20G + w`
- broad, shift-path:
  - `20G + h`
  - `20G + b`
  - `10G + j`
  - `15G + j`
  - `20G + k`

The important clarification is that the broad controls are already broad in the
PTY delta itself:

- `20G + w` is only a tiny status/cursor token update
- `20G + b` / `20G + h` rewrite real buffer body rows (`debug = 4`,
  `trace = 5`) plus the bottom status token

So the current question for that lane is not "why did backend publication widen
a tiny update?" It is:

- which real-config UI surface is causing those backward/leftward and vertical
  motions to emit broad body-plus-status terminal output
- and whether later shift-path publication is still too optimistic for that
  already-broad-but-structured update shape

The current replay evidence narrows that second question further:

- for the settled `20G+b` authority, baseline-to-final replay diff is
  internally consistent with `viewport_shift_rows=2` and
  `viewport_shift_exposed_only=true`
- so the next correctness suspicion is not simple damage undercounting
- it is the renderer-side texture-shift reuse seam, where copied terminal
  pixels are trusted for non-exposed rows during scroll-path updates

That is why the current renderer cut in this lane is a safety cut rather than a
damage-model cut: terminal texture scroll now uses a scratch render target
instead of copying from an FBO back into the same attached texture.

The latest live ghosting logs also clarify that this is not the only lane. The
active user-visible ghost case we are chasing right now is currently showing:

- `shift_rows=0`
- `shift_exposed_only=false`
- same-row dirty union growth under `origin=parser.ascii_run`

So the next diagnostic seam for that exact symptom class is still upstream
parser/grid write provenance rather than the scroll-texture path.

The current bug-scoped live probe for that seam is `terminal.ui.write_ascii_origin`.
It only logs broad `parser.ascii_run*` writes and includes a short preview of
the payload, which should let us tell whether the second same-row write is
body text, gutter/status text, or guide-style repeated columns.

That provenance pass is now effectively complete for the current live lane:

- backend damage matches backend diff truth on the bad rows
- dirty retirement is clearing, not carrying stale rows forward
- left-edge omitted-cell theory is ruled out for the sampled rows
- background-run construction is reading real resolved cell state

So the remaining bug is no longer best explained as backend under-damage or
background-run invention. The current live conclusion is mixed stale renderer
state.

## Current Live Renderer Conclusion

The active repro class is not foreground-only and not background-only. It now
includes:

- fast `nvim` motion ghosts
- palette/notification/UI-close ghosts
- `btop` graph foreground loss

The common pattern is that backend/publication selects and redraws the rows, but
some pixels recover only when a later unrelated redraw passes over them.

Current attribution is now below the direct glyph input lane:

- bad rows are overwhelmingly `direct_text` rows
- shaped-text work is usually absent on those rows
- special/box lanes exist, but they are minor on the active repros

`terminal.ui.row_glyph_sample` has now done its job for this lane:

- it logs up to three direct-glyph style-transition samples per affected row
  (`slot=0..2`)
- recent live traces show the expected body `gid/fg/bg` at `slot=1/2` even on
  visibly broken rows

So the next decisive live probe is now `terminal.ui.target_sample`:

- on broad partial rows it samples the terminal FBO before glyph flush
  (`phase=bg`) and after glyph flush (`phase=glyph`)
- it samples the same `slot=0..2` direct-glyph cells plus the `bg2` run-start
  cell when present
- those readback lines are also mirrored into `terminal.ui.row_render_pass` as
  `event=target_sample ...`, so the decisive probe still appears when the
  dedicated tag is missing from a live capture
- `phase=glyph` now also reports `diff_hits` and `diff_max`, comparing a 3x3
  in-cell sample grid against the stored `phase=bg` baseline for the same cell;
  this avoids false negatives when the cell-center pixel lands in background on
  ordinary ASCII glyphs
- marker-driven live captures (`Java`, `Scrolling`) now show non-zero
  `diff_hits` on sampled body cells during visibly broken frames, so sampled
  glyph ink is already present in the terminal FBO on that lane
- fast-scroll-only captures now also show sampled cells surviving the
  terminal-texture composite: `phase=window` reports non-zero `diff_hits` on
  the sampled body cells even during the high-volume artifact lane
- the live cut now extends one step later than that renderer-local sample:
  the stored `phase=final` grids are carried into `Renderer.endFrame()` and
  re-read after `SDL_GL_SwapWindow` as `phase=present`, so the active lane can
  distinguish "final backbuffer is right but the presented front buffer is
  wrong" from "the sampled cells were never correct in the first place"
- that presentation-side cut now also includes swap-context and one-frame
  history: `event=present_state ...` logs frame/focus/resize/swap-interval and
  drawable sizing around swap, while each `phase=present` sample now also
  carries `back_rgba/back_hits/back_max` and a paired
  `event=present_compare ...` line with `prev_cp/prev_hits` plus
  `prev_final_cp/prev_final_hits`, keyed by sampled screen location rather
  than codepoint, so stale presented reuse can be distinguished from a fresh
  bad post-swap image
- the decisive zebra captures now show the terminal draw path is clean on the
  sampled cells right up to swap: `phase=final diff_hits=0/9` remains true on
  the bad frames, but `phase=present` diverges immediately afterward while
  `event=present_state ...` stays stable (`focused=1 resized=0 swap_interval=1`
  on the reproduced frames)
- that divergence is not just a front-buffer quirk either: the same zebra
  frames report matching bad `back_rgba/back_hits` after swap, so the active
  suspicion is swap/buffer-rotation behavior rather than terminal FBO draw
  corruption or a pure front-buffer presentation glitch
- full-log review now also shows stale presented reuse after the first bad
  frame: once the wrong post-swap image appears, later `phase=present`
  samples can match both the previous frame's correct final baseline
  (`prev_final_hits`) and the previously presented bad image (`prev_hits`)
- that presentation-side mitigation experiment is now landed in temporary
  opt-in form too: `ZIDE_PRESENT_EDGE_FALLBACK=copy_back_to_front` makes
  `Renderer.endFrame()` blit the default `GL_BACK` buffer into `GL_FRONT`
  immediately before `SDL_GL_SwapWindow`, and `event=present_state ...` now
  carries `present_edge=off|copy_back_to_front` so captures say which swap-edge
  path was active
- that fallback has now been exercised on the live zebra lane and made no
  visible difference, so the simple pre-swap front/back equalization did not
  suppress the corruption
- the active next probe is now a wider row-band signature: broad sampled rows
  emit `event=target_band phase=window|final ... sig=...` before swap, and
  `Renderer.endFrame()` now emits `event=present_band ... sig/back_sig/final_sig
  ...` for the same row span after swap so captures can distinguish a coherent
  row-band mutation from a sparse per-cell mismatch
- that probe now also carries a representative full-height vertical lane for
  the user-reported scope-line column ghosts: each sampled broad row uses its
  middle direct sample column as an `axis=column` band and logs the same
  `window|final|present` signature chain for that vertical seam
- later local-column captures show that lane participating too: adjacent row
  bands still remap after swap, and local `axis=column` bands around the
  affected rows now diverge as well
- the next controlled mitigation experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=finish_before_swap`, which calls `glFinish()`
  immediately before `SDL_GL_SwapWindow` to test whether input-pressure failure
  is an in-flight present-queue problem
- `finish_before_swap` now has a real effect: it partially stabilizes the
  neighborhood remap under pressure (one row can stay correct and local column
  divergence drops), so present-edge timing is definitely part of the failure
- `ZIDE_PRESENT_EDGE_FALLBACK=finish_before_and_after_swap` has now been
  exercised too: it can reduce some frames further than `finish_before_swap`,
  but the decisive captures still show exact adjacent-row aliasing after swap
  on the bad lane, so full GL completion around `SDL_GL_SwapWindow` is not
  sufficient to suppress the remap
- the next present-edge experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0`, which disables swap interval at
  renderer init while leaving the same probes active so the next repro can
  distinguish "vsync/queued present pacing" from "post-swap corruption that
  survives even without swap throttling"
- `swap_interval_0` now has the strongest mitigation effect so far: on the
  latest repro lane the broad row/column bands can stay exact across multiple
  consecutive frames, with only smaller per-cell post-swap diffs surviving on a
  few sampled glyph cells, so queued/vsync present pacing is clearly part of
  the trigger
- `event=present_state ...` now also logs `swap_ms` and `present_gap_ms`; use
  those fields on the next repro to tell whether "no logs, then a burst" is a
  real long swap/present stall or just delayed visibility of otherwise normal
  frame logging
- latest `swap_interval_0` captures now say the burst pattern is not a long
  swap stall: the quiet-then-burst frames show tiny `swap_ms` with large
  `present_gap_ms`, so the next cut should treat that as a long gap between
  sampled present frames rather than `SDL_GL_SwapWindow` blocking for the whole
  interval
- the remaining `swap_interval_0` failures now also intersect the cursor lane
  explicitly: `event=overlay_touch branch=cursor ...` can coincide with a
  `phase=final` mutation on the sampled `bg2`/column seam before swap, followed
  by a worse post-swap version of the same neighborhood; a temporary
  `ZIDE_DEBUG_DISABLE_TERMINAL_CURSOR_OVERLAY=1` switch is now available to
  test whether the remaining failures are cursor-overlay driven
- that cursor-overlay experiment is now negative: `cursor_overlay_disabled=1`
  still reproduces the same adjacent-row remap under `swap_interval_0`, so the
  remaining failure survives with the terminal cursor overlay removed
- the next pacing experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_cap_60hz`, which keeps swap
  interval disabled but also caps present cadence from the app side after each
  frame so the next repro can distinguish "vsync path is buggy" from "too many
  presents queued under pressure"
- `swap_interval_0_cap_60hz` is now also negative: even with
  `present_gap_ms` held around one capped frame, the same row remap still
  reproduces, so simple app-side queue-depth reduction is not enough
- the next combined experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_finish_before_swap`, which keeps
  swap interval disabled but adds `glFinish()` before swap so the next repro
  can tell whether the residual no-vsync failure is still GL-completion related
  or already below the GL queue
- `swap_interval_0_finish_before_swap` also looks negative on the current lane:
  the residual no-vsync failure still reproduces with the same row/column band
  corruption profile, so simple pre-swap GL completion is not enough either
- the last cheap GL-side matrix point is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_finish_before_and_after_swap`,
  which keeps swap interval disabled and serializes both sides of swap before
  the investigation moves fully below the GL queue
- `swap_interval_0_finish_before_and_after_swap` is now also negative on the
  Wayland-only repro lane: the same adjacent-row remap still survives, so the
  next experiment should stop spending effort on GL-side swap serialization and
  instead test a more conservative terminal publication path from the app side
- the active Wayland-only experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture`,
  which keeps `swap_interval=0` but forces full terminal texture publication
  whenever we would otherwise take the partial texture-update path; this is
  intended to distinguish Wayland/SDL post-swap damage from a bug in our
  partial terminal texture publication path
- that force-full-on-partial mode now changes the symptom: the bad image can
  recover, but recovery can take seconds after input stops, which implies a
  clean frame can still skip terminal texture publication and leave recovery
  waiting for the next dirty redraw
- the active follow-up is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_every_frame`,
  which keeps `swap_interval=0` and forces full terminal texture publication
  even on otherwise clean frames; this is intended to tell whether the slow
  recovery is just waiting for the next dirty publish
- `swap_interval_0_force_full_terminal_texture_every_frame` is now much better
  on the live Wayland repro, which means aggressive republishing can actively
  heal the bad image rather than merely containing it
- the next narrowing experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recovery_500ms`,
  which keeps `swap_interval=0` and forces full terminal texture publication
  for 500ms after an otherwise-dirty frame; this is intended to test whether
  the improvement needs constant brute force or only a short post-activity
  recovery window
- `swap_interval_0_force_full_terminal_texture_recovery_500ms` is now much
  worse than the every-frame mode, so a tiny recovery window is not enough
- the active follow-up is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recovery_2000ms`,
  which keeps the same mechanism but stretches the bounded recovery window to
  2 seconds
- `swap_interval_0_force_full_terminal_texture_recovery_2000ms` is better
  again, but still loses footing slightly on long arrow-down `nvim`
  scrolling, which suggests recent input pressure is a better driver than
  dirty-history alone
- the active follow-up is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recent_input_2000ms`,
  which keeps `swap_interval=0` and forces full terminal texture publication
  while terminal input was seen within the last 2 seconds
- `swap_interval_0_force_full_terminal_texture_recent_input_2000ms` is now
  basically perfect on the live repro, so input-pressure-driven publication is
  the strongest lead so far
- the next narrowing experiment is now
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recent_input_1000ms`,
  which halves that input window to 1 second so we can find a cheaper fix
  candidate
- `swap_interval_0_force_full_terminal_texture_recent_input_1000ms` is also
  basically perfect on the live repro, so the next floor test is
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recent_input_500ms`
- `swap_interval_0_force_full_terminal_texture_recent_input_500ms` is also
  basically perfect on the live repro, so the next floor test is
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recent_input_250ms`
- `swap_interval_0_force_full_terminal_texture_recent_input_250ms` is now
  noticeably worse, so the current bracket is between `500ms` and `250ms`
- `swap_interval_0_force_full_terminal_texture_recent_input_375ms` is now
  basically perfect on the live repro too, after extending the recent-input
  pressure proxy to include held modifiers
- `swap_interval_0_force_full_terminal_texture_recent_input_300ms` is now
  noticeably more janky on the user's real `nvim` smooth-scrolling plugin, so
  the useful bracket is currently `375ms` good and `300ms` worse
- that input-pressure publication policy is now promoted into the default app
  path with a `375ms` recent-input window, while the older
  `ZIDE_PRESENT_EDGE_FALLBACK=swap_interval_0_force_full_terminal_texture_recent_input_*`
  modes remain available as explicit debug/experiment overrides
- the default policy is now configurable from Lua via
  `terminal.presentation.recent_input_force_full` and
  `terminal.presentation.recent_input_force_full_ms`
- current war-room scope is now narrower again:
  - the original fast-scroll row-remap lane is still best explained as a
    post-final/present-side failure under pressure
  - the newer `wiki_life` repro inside an `nvim` terminal buffer is now fixed
    by the `setSyncUpdatesLocked` publication-ownership change
  - raw debugging for the remaining lane should currently use
    `ZIDE_DEBUG_DISABLE_TERMINAL_PRESENT_MITIGATION=1`, because the active
    question is no longer "which mitigation window feels best?" and no longer
    "which publication entrypoint is wrong for `wiki_life`?", but whether the
    remaining old `nvim` text-buffer scroll ghost is downstream in renderer
    consumption / present
- the active root-cause instrumentation is now trimmed again for the remaining
  live lane:
  - `terminal.ui.target_sample` is the active tag
  - the widget still registers the same sampled cells/bands and final baselines
  - but the renderer now emits only the suspicious frame cut:
    `present_state`, `phase=pre_swap_back`, `phase=present`, and matching
    row/column bands when it actually detects a present-side mismatch
  - overlay attribution now uses its own dormant tag,
    `terminal.ui.overlay_probe`, so cursor/selection chatter no longer
    pollutes the active present-side capture
  - the probe selector is now also biased toward the real `nvim` text-buffer
    lane, but in a cheaper form again: one cursor-centered cross probe watches
    `cursor.col ± 5` on the cursor row plus `cursor.row ± 5` at the cursor
    column, rather than the heavier row-by-row neighborhood scan
  - the widget also keeps the target-probe baselines alive silently now:
    `bg/glyph/window/final` captures still populate the final comparison data
    even though the per-frame target-sample writes were removed from this lane
  - the current swap-semantics cut is now richer too: suspicious frames capture
    both `GL_FRONT` and `GL_BACK` immediately before swap, so the next live log
    can compare pre-swap front, pre-swap back, and post-swap front/back on the
    same sampled cells/bands
  - SDL setup/swap validation is now less blind too:
    - critical SDL GL calls (`SetAttribute`, `MakeCurrent`, `SetSwapInterval`,
      `SwapWindow`) no longer silently ignore failure
    - startup now logs the realized SDL GL context attributes after creation,
      so Wayland runs can be compared against the actual negotiated context
      rather than only the requested one
    - the latest live Wayland run now reports `doublebuffer=0` on that
      realized context, which is a direct warning against assuming the default
      framebuffer behaves like the double-buffered surface we requested
  - local upstream docs are now staged for agentic use too:
    - SDL source now lives under `reference_repos/backends/sdl`, which gives
      the Wayland/EGL implementation files directly (`src/video/SDL_egl.c`,
      `src/video/wayland/SDL_waylandopengles.c`,
      `src/video/wayland/SDL_waylandwindow.c`, etc.)
    - official Khronos EGL/OpenGL refpages mirrored under
      `reference_repos/rendering/khronos_refpages_md`
    - Mesa source/docs are now cloned sparsely under
      `reference_repos/rendering/mesa`, with the EGL tree and docs present for
      this lane (`docs/egl.rst`, `src/egl/main/*`, `src/egl/wayland/*`)
    - official upstream source repos cloned under
      `reference_repos/backends/wayland`,
      `reference_repos/backends/wayland_protocols`,
      `reference_repos/rendering/egl_registry`, and
      `reference_repos/rendering/opengl_registry`
    - reproducible fetch path: `scripts/setup_khronos_refpages_md.sh`
    - the most important local contract finding from those refs so far is that
      `eglSwapBuffers` leaves the color buffer undefined unless
      `EGL_SWAP_BEHAVIOR == EGL_BUFFER_PRESERVED`; post-swap reads are useful
      probes, but not proof of preserved-buffer semantics on Wayland/EGL
    - SDL’s own local docs also show the next honest introspection path exists
      without leaving SDL:
      - `SDL_EGL_GetCurrentDisplay`
      - `SDL_EGL_GetCurrentConfig`
      - `SDL_EGL_GetWindowSurface`
      - `SDL_GetWindowProperties` for Wayland/EGL window handles
    - that introspection cut is now live in startup too:
      - `sdl.window` emits `event=wayland_handles ...`
      - `sdl.gl` emits `SDL EGL contract ...`
      - the current log includes queried `EGL_RENDER_BUFFER`,
        `EGL_SWAP_BEHAVIOR`, `EGL_SURFACE_TYPE`, `EGL_CONFIG_ID`, surface
        `width/height`, and EGL `vendor/version/client_apis`
    - the curated Khronos mirror now also includes the missing context/config
      query pages we need for design work:
      - `eglCreateContext`
      - `eglGetConfigAttrib`
      - `eglGetError`
      - `eglMakeCurrent`
      - `eglQueryContext`
      - `glReadPixels`
  - suspicious frames now also emit `event=present_gl_state`, which records
    pre/post default-framebuffer GL state (`READ_BUFFER`, `DRAW_BUFFER`, and
    framebuffer bindings) around `SDL_GL_SwapWindow`
  - the broken whole-frame offscreen compose experiment has now been removed;
    the design authority for the replacement path lives in
    `WAYLAND_PRESENT_TECHNICAL_WRITEUP.md`
- the latest live probe pass sharpened that instrumentation again:
  - the broad sampled partial rows stayed coherent across
    `phase=bg/glyph/window/final/present`
  - but the visible defect in that run landed on narrow one-column
    guide/scope rows, which the original target-probe selector ignored because
    it only armed on broad direct-text rows
  - the current probe selector now also seeds a cheap fallback sample on narrow
    box/guide rows so those rows can ride the same `final/present` readback cut
- that retargeted probe has now paid off too:
  - the active live lane currently hits narrow guide rows around
    `rows 19..22 col 6`
  - those rows are correct through `phase=final`
  - then at least one bad frame shows them wrong at `phase=present`
- that ambiguity is now resolved too:
  - `phase=pre_swap_back` samples those same rows/bands from the backbuffer
    immediately before `glSwapWindow`
  - on the live bad rows, `phase=pre_swap_back` is still correct while
    `phase=present` is wrong
  - the remaining old `nvim` text-buffer scrolling ghost is therefore back on
    the swap / Wayland presentation seam rather than backend publication or any
    pre-swap renderer draw path
- the newer `pre_swap_front` cut sharpens that conclusion further:
  - on live ghost frames, `phase=pre_swap_front` and `phase=pre_swap_back` are
    both correct before swap
  - then both post-swap reads agree on the same wrong image
  - so the next active question is no longer "which buffer was stale before
    swap?", but whether default-framebuffer semantics on this Wayland/EGL lane
    collapse or mutate across swap itself
- the whole-frame offscreen compose experiment is currently invalid for
  classification because it produces a different broken lane before swap, so
  the next honest classifier should stay on the direct-default path and vary
  only the swap boundary itself
- the next step is now narrower than another broad swap matrix:
  - inspect the new startup EGL contract log on the active Wayland path
  - specifically: reconcile the realized `doublebuffer=0` report against the
    queried `EGL_RENDER_BUFFER`, `EGL_SWAP_BEHAVIOR`, `EGL_SURFACE_TYPE`, and
    whether the chosen config even advertises preserved-swap support
  - use the now-complete local reference set for the design pass rather than
    fetching more authorities first: terminal-side architecture refs
    (`ghostty`, `foot`, `kitty`, `wezterm`, `rio`) plus backend authorities
    (SDL source, Mesa EGL tree, Wayland/protocol repos, and the expanded
    Khronos refpages)
  - only after that decide whether the durable renderer fix should abandon any
    dependence on default-framebuffer preservation semantics
- the latest direct-default swap A/B already sharpened that further:
  - `finish_before_swap` and `finish_before_and_after_swap` did not materially
    improve the surviving old scrolling ghost
  - `copy_back_to_front` did help somewhat: the bug still survives, but it
    takes more rendering iterations to force it
  - that currently points more toward front/back/default-framebuffer ownership
    semantics on this Wayland lane than toward generic GPU submission timing
- the current focused instrumentation now sits inside that helpful path:
  - `pre_fallback_back` / `pre_fallback_front` are sampled before the explicit
    back-to-front blit in `copy_back_to_front`
  - the existing `pre_swap_back` / `pre_swap_front` samples are after the blit
    but still before swap
  - the next useful question is therefore: on a `copy_back_to_front` run, what
    exactly does the explicit blit change on the sampled cells/bands before the
    remaining post-swap corruption still appears?
- that probe path is now also lighter-weight:
  - the older always-log `bg/glyph/window/final` trace is no longer emitted on
    every frame for this lane
  - the goal is to preserve the decisive present-side proof while taking less
    timing out of the scrolling repro
- the next explicit question for the remaining old `nvim` text-buffer scroll
  ghost lane is: if backend publication and widget partial planning are already
  correct, where does the visible stale state first diverge between row/glyph
  submission, terminal-texture contents, final backbuffer, and presented
  frontbuffer?
- that earlier handoff question is now materially answered:
  - generation lineage across session/workspace poll, frame snapshot, widget
    prepare/plan, and presented-generation retirement is coherent enough that it
    no longer looks like the primary seam
  - the decisive raw `wiki_life` cut moved one step downstream into
    `view_cache` publication ownership:
    - `view_cache_publish_final` can emit a partial-dirty generation `N`
    - then emit a newer clean generation `N+1` before widget capture
    - and `capturePresentation()` then sees only `N+1 dirty=none`, so widget
      texture planning correctly decides `plan_full=0 plan_partial=0` while the
      on-GPU texture is still stale
  - the contract implication is stricter than “keep generations coherent”:
    unpresented dirty publication is pending render work and must survive later
    clean publication until it is either presented/acked or conservatively
    promoted
  - current fix shape:
    - if a newer clean publication would overwrite an unpresented dirty cache,
      `view_cache` now preserves that pending dirty metadata on the newer cache
    - if the pending dirty cache depended on viewport-shift reuse, the newer
      cache is conservatively promoted to full damage instead of carrying a stale
      shift assumption forward
  - the latest raw repro showed that this still was not the whole seam:
    - the disappearing dirty work is first being published on the already
      presented generation
    - then a later clean `N+1` cache replaces it
    - so the preserved-pending-damage rule never even gets a chance to fire on
      that lane
  - the active question is therefore now generation ownership at publication
    entrypoints, not retirement:
    - which caller is issuing same-generation dirty
      `updateViewCacheNoLock(...)` work before the outer generation-bump path
      runs?
    - `terminal.generation_handoff` now carries `source=...` tags on
      `view_cache_*` stages plus a dedicated
      `stage=view_cache_same_generation_dirty` log for that exact question
  - that question is now answered for the active live lane:
    - the caller was `setSyncUpdatesLocked`
    - DEC synchronized-updates toggles were republishing dirty cache state inline
      on the already-presented generation
    - the following normal parse-thread publish then advanced to `N+1 dirty=none`
      and hid the stale texture seam from the earlier pending-damage fix
  - current rule:
    - `setSyncUpdatesLocked` must not republish dirty state on the currently
      presented generation
    - it now only advances generation and republishes when there is already
      unpresented or dirty published state to carry forward
  - that fix has now done its job for the `wiki_life` lane
  - the next question is no longer “which caller is doing this?” but whether the
    remaining old scrolling ghost persists even when:
    - published cache state is partial-dirty
    - widget planning still chooses `plan_partial=1`
    - presented-generation ack retires those generations cleanly
  - current answer: yes, so the remaining seam is now downstream of backend
    publication truth and widget update-plan choice
- raw repros are still available without code edits via
  `ZIDE_DEBUG_DISABLE_TERMINAL_PRESENT_MITIGATION=1`, which disables the
  default mitigation path so the original post-swap Wayland bug can still be
  chased directly
- held keyboard modifiers were also found to block recovery under the
  recent-input modes because the original proxy only watched recent terminal
  input timestamps; the draw-side condition now treats active modifier state as
  ongoing pressure too, so holding `Ctrl+Shift` no longer lets the recent-input
  window expire
- overlay attribution still exists for targeted follow-up work, but it no
  longer rides on the active present-side tag: `drawOverlays(...)` emits
  `event=overlay_state ...` plus
  `event=overlay_touch branch=selection|hover_underline|cursor|ime ...` on
  `terminal.ui.overlay_probe`
- `Ctrl+Shift+F12` now also dumps the terminal widget's current visible
  viewport cache to `zide_terminal_view_dump.txt` in the process cwd. The dump
  is fixed-width ASCII with row numbers, a column ruler, `resolved_bg_runs` per
  visible row, and a `non_ascii_cells` footer so a visibly deformed cell or
  stale highlight row can be mapped back to the renderer-side row/col probes,
  including alt-screen content

The current design implication is:

- do not keep pushing on backend damage/publication by default for this lane
- do not keep pushing on background-run construction by default for this lane
- focus the next renderer cut on offscreen target write/composite behavior and
  only return to lower layers if new evidence contradicts the current
  attribution

## Multi-Span Row Damage Direction

The current backend damage model is too weak for the real-config ghosting lane.
Today the terminal keeps only:

- `dirty_rows[row]`
- `dirty_cols_start[row]`
- `dirty_cols_end[row]`

That means each dirty row can represent only one union span. For the current
`nvim` symptom class, that is exactly where quality is lost:

- one small earlier region on the row is dirtied first
- a later broad body-text write lands farther right on the same row
- backend damage collapses both into one large row union

The next backend-quality step should therefore be structural, not heuristic:

- row damage should support multiple spans per row
- overflow/coarsening should be explicit and local to that row
- publication/refinement/rendering should consume backend-authored spans rather
  than reconstructing them heuristically later

### Proposed Shape

Start with a fixed-cap per-row span set in the backend:

- `dirty_rows[row]` remains as the cheap row activity bit
- replace `dirty_cols_start/end[row]` as the primary truth with:
  - `row_dirty_span_counts[row]`
  - `row_dirty_span_overflow[row]`
  - `row_dirty_spans[row][N]`

Initial design constraints:

- keep `N` small and fixed first, for example `4`
- merge overlapping/touching spans in-row
- if a row exceeds `N`, mark only that row as overflow and collapse that row to
  one union span
- do not collapse unrelated rows or the whole frame because one row overflowed

### Ownership Rules

Best-quality contract for this lane:

- `TerminalGrid` owns authoritative multi-span dirty truth
- `snapshotView()` exports that truth without reinterpreting it
- `view_cache` carries/refines spans but does not invent them
- row-hash refinement remains optimization-only
- renderer partial planning consumes spans directly

### Migration Order

Implement this in reviewable backend-first steps:

1. Add multi-span data structures to `TerminalGrid` while keeping the old
   single-span fields as compatibility/export mirrors.
2. Teach `markDirtyRange...()` to append/merge spans instead of widening one
   union span immediately.
3. Export spans through snapshot/view-cache/publication.
4. Switch renderer partial planning to consume spans.
5. Only then retire the old single-span row truth.

### First Authority To Lock

Before implementation, lock one focused authority for:

- small earlier row-local region
- later same-row body rewrite
- expected result: two preserved row-local spans, not one huge row union

That authority is now the right next backend target for the ghosting lane.

The current before-state is now also locked in a backend unit test at
`src/terminal/model/screen/grid.zig`: the same-row sequence currently collapses
from `2..5` plus `10..18` down to one union span `2..18`. That is the exact
behavior the future multi-span row model is meant to replace.

The first migration checkpoint after that is now landed too:

- `TerminalGrid` owns fixed-cap per-row span storage
- `snapshotView()` exports that span truth
- `view_cache` / `render_cache` preserve it end-to-end
- the old `dirty_cols_start/end` union fields still exist only as compatibility
  mirrors for now

The next backend publication checkpoint is now landed too:

- projected diff preserves multiple same-row spans instead of collapsing back to
  one `rowDiffSpan(...)`
- row-hash refinement preserves/discovers multiple row-local spans and rebuilds
  the old union bounds only as compatibility mirrors
- selection-dirty expansion and partial-damage widening now keep the new
  per-row span truth in sync instead of mutating only `dirty_cols_start/end`

The next renderer checkpoint is now landed too:

- partial-plan construction in `terminal_widget_draw_texture.zig` now prefers
  backend row spans directly
- the old `dirty_cols_start/end` union bounds remain only as fallback when span
  truth is absent
- partial background/glyph draw loops now also iterate those per-row spans
  directly instead of redrawing one union box per row
- that means backend-authored multi-span damage now survives all the way into
  the live partial draw path instead of being forced back through a one-span
  row box at the renderer seam

That means the next implementation step can move from storage/export into
damage/publication consumption without guessing whether the backend is already
losing span truth before the renderer sees it.

### 3. `PtyTerminalSession`

This is the desktop-host runtime wrapper.

It owns:

- PTY creation/start/stop
- read/write pumping
- child exit observation
- optional threads
- host polling and pressure hints

It wraps:

- `TerminalCore`
- one PTY transport implementation

This is the likely future role of today's `TerminalSession`.

### 4. `TerminalSnapshot`

This remains renderer-agnostic and becomes more explicitly core-owned.

It should expose:

- rows/cols
- flat cell state
- cursor state
- damage summary
- title/cwd metadata needed by hosts
- selection state needed by hosts/renderers
- kitty image placement metadata needed by renderers

The snapshot contract should be valid for:

- SDL/OpenGL renderer
- Flutter renderer
- FFI consumers
- replay/test tooling

### 5. `TerminalInputEncoder`

This remains a peer subsystem.

It consumes:

- terminal mode state
- key/mouse/text events

It emits:

- encoded terminal input bytes

It should be usable:

- from PTY-backed desktop hosts
- from FFI hosts
- without pulling in session/runtime code

## Ownership Map

### Core-owned behavior

These behaviors must move toward `TerminalCore` ownership:

- parser feed
- protocol dispatch
- screen mutation
- history/scrollback mutation
- selection mutation semantics
- alt-screen behavior
- terminal mode state
- protocol-triggered title/cwd/clipboard metadata
- kitty graphics protocol state
- snapshot generation

### Host/runtime-owned behavior

These must stay outside the core:

- PTY open/start/stop
- thread creation
- child process shutdown
- desktop polling cadence
- workspace tab management
- SDL widget gesture orchestration
- GPU upload policy

### Shared boundary behavior

These must be explicit contracts:

- feed terminal output bytes into the core
- request encoded input bytes from host events
- consume snapshots and damage
- drain host-visible events
- resize core state

## Event Model

The core should own a narrow event queue for host-visible state changes.

Candidate core-visible events:

- title changed
- cwd changed
- clipboard write request
- bell
- child exit observed by host wrapper
- wake/dirty

Important distinction:

- `bell`, `title`, `cwd`, `clipboard` are terminal/core-facing semantics
- `child exit` is host/runtime-facing and may be injected into the same exported
  event stream by a host wrapper

## FFI Direction

The current `zide_terminal_ffi.h` surface is still effectively session-backed.

Future shape:

### Core-facing operations

- create/destroy core-backed handle
- feed output bytes
- resize
- encode/send key/mouse/text
- snapshot acquire/release
- scrollback acquire/release
- event drain/free
- state getters

### Optional host/runtime operations

- create PTY-backed host session
- start child
- poll runtime
- query child exit

This should become two layers in the API model even if they are initially
exported from one shared library:

- core API
- optional PTY host API

That keeps Flutter and mobile consumers from depending on PTY/session semantics
they do not need.

### 2026-03-10 first internal split

The first code cut for that FFI direction is now landed:

- shared terminal FFI ABI types, handle state, event/string helpers, and
  glyph-class metadata helpers live in `src/terminal/ffi/shared.zig`
- PTY-host/runtime-facing operations live in `src/terminal/ffi/host_api.zig`
- core-facing snapshot/scrollback/metadata/event/text-export operations live in
  `src/terminal/ffi/core_api.zig`
- `src/terminal/ffi/bridge.zig` is now a thin facade over `core_api` +
  `host_api`

The exported C ABI is unchanged in this slice. The gain is internal ownership:
host/runtime operations are no longer mixed inline with snapshot/scrollback/
metadata/event export logic in one large bridge implementation.

### 2026-03-10 no-PTY transport-backed FFI feed path

The first non-PTY transport shape is now also landed internally:

- `src/terminal/core/terminal_transport.zig` now has an in-memory external
  transport implementation alongside the PTY-backed transport facade
- FFI-created terminal sessions attach that external transport by default
- `zide_terminal_feed_output(...)` now enqueues bytes into that transport and
  runs the normal session poll path, instead of bypassing backend transport

### 2026-03-11 first render-publication behavior change

`VTCORE-05` is no longer prep-only.

The first real publication behavior change is now landed:

- live-bottom full-region scroll publication can use viewport-shift exposure
  instead of widening damage to the whole viewport
- the replay contract for that case is now harness-owned rather than relying on
  mixed baseline VT input plus direct scroll actions
- row-hash refinement is also skipped for scroll-shift publication, so that
  row-position hashing does not undo a valid exposed-row shift plan

This matters because it is the first backend publication optimization locked by
replay authority instead of only by unit tests or visual anecdotes.
  ownership through a direct parser-only shortcut

This keeps the no-PTY host path closer to the future embed/mobile shape while
preserving the existing exported FFI API.

That path is now also core-tested:

- terminal session tests cover external transport enqueue/poll
- metadata/aliveness are asserted through the same core session surface used by
  other hosts
- external transport now has an explicit "closed" state instead of only
  "attached vs detached"

It is also no longer FFI-only:

- the replay harness now uses external transport for normal non-reply fixtures
- PTY attachment remains only for the reply-capture subset that genuinely needs
  a writable transport sink
- higher-level callers now go through `TerminalSession` host-wrapper methods for
  external transport attach/enqueue/close instead of reaching into
  `terminal_transport` directly for that path
- reply-capture PTY attachment in the replay harness now also goes through
  `TerminalSession` host-wrapper methods instead of raw transport assembly
- at this point higher-level setup callers no longer need raw
  `terminal_transport.attach*/detach*` for normal session assembly paths

The external-host lifecycle contract also moved forward:

- terminal FFI now exposes `zide_terminal_close_input(...)` for no-PTY hosts
  that want to signal end-of-stream without destroying the terminal
- the derived event contract now includes `alive_changed`
- the mock-service Python smoke now validates that closing external input:
  - flips metadata `alive` to false
  - emits an `alive_changed` event
  - preserves snapshot readability for final rendered content

Embedded-host wake semantics also moved forward:

- the derived terminal event stream now emits `redraw_ready` whenever terminal
  snapshot generation advances
- this gives non-PTY hosts a minimal "pull snapshot now" wake signal without
  inventing a second damage model in the FFI layer
- damage and generation still remain authoritative in snapshot acquisition;
  `redraw_ready` is only a scheduling hint for host event loops
- host-side `resize(...)` now also goes through that derived wake path, so
  PTY-backed foreign hosts and no-PTY embedded hosts both get an immediate
  redraw signal after visible size changes

This matches the general shape used by stronger reference terminals:

- Ghostty's termio/renderer split wakes the renderer after stream-handling and
  mailbox publication, not just at process start
- Alacritty marks the terminal/window dirty and requests redraw after actual
  visible-state changes, especially resize and PTY-driven updates

So the current Zide FFI direction is:

- no synthetic wake on `start(...)` alone
- wake on visible-state transitions such as streamed output, poll-driven PTY
  updates, and resize

The `TerminalSession` root also shed another non-runtime owner:

- the input-mode query/toggle surface now routes through
  `src/terminal/core/session_interaction.zig`
- the root session facade still exports the same API, but it no longer carries
  that interaction/mode-management block inline

Protocol execution also moved another step toward core ownership:

- saved-cursor restore and alt-screen core state transitions now live behind
  `src/terminal/core/terminal_core_modes.zig`
- `session_protocol.zig` now only layers the remaining session-owned side
  effects around that core transition, such as selection clearing and input
  snapshot publication
- RIS/reset core mutation now also lives behind
  `src/terminal/core/terminal_core_reset.zig`, with `session_protocol.zig`
  keeping only the session-owned input-mode snapshot republish step
- hyperlink allocation, kitty image clearing, and scroll-region mutation now
  also live behind `src/terminal/core/terminal_core_protocol.zig`, leaving
  `session_protocol.zig` closer to a session-owned publication/selection wrapper
  instead of another mixed core-mutation owner
- the remaining session-owned alt-screen/reset side effects now also live in
  `src/terminal/core/session_mode_effects.zig`, making those selection/input-
  snapshot/presentation consequences explicit instead of leaving them embedded
  inline in `session_protocol.zig`
- alt-screen exit presentation timing now also routes through
  `src/terminal/core/session_rendering.zig`, so mode-side effects no longer
  mutate render/publication timing state inline

## Compatibility Strategy

We do not go from zero to hero in one patch.

Migration approach:

1. define `TerminalCore` contract in docs
2. introduce a new internal core type without changing behavior
3. make current `TerminalSession` wrap that core
4. move protocol execution and state ownership onto the core
5. move FFI to target the core boundary first
6. keep PTY-backed desktop behavior working through the wrapper

## Progress

### 2026-03-10 first code cut

The first `VTCORE-01` extraction is now landed internally:

- `src/terminal/core/terminal_core.zig` owns the engine-centered terminal state
- `TerminalSession` now wraps `core: TerminalCore`
- PTY/runtime/thread/render-publication ownership stays in `TerminalSession` for now

This first cut moved these owners under `TerminalCore` without changing behavior:

- primary/alt screens and active-screen state
- history/scrollback
- parser state
- OSC title/cwd/clipboard/hyperlink state
- semantic prompt and user vars
- kitty image state
- palette/default-color state
- saved charset and clear-generation state

This is intentionally not the end-state. Protocol execution and FFI still route
through `TerminalSession`, but they now do so against a real internal core owner
instead of one flat session struct.

Session construction also moved one step toward host-wrapper ownership:

- `src/terminal/core/session_runtime.zig` now owns the `TerminalSession`
  allocation + runtime-state assembly path
- `terminal_session.zig` now delegates `initWithOptions(...)` to that runtime
  owner instead of constructing the whole session inline
- replay/test-only debug helpers now also live in
  `src/terminal/core/terminal_session_debug.zig`, so that non-runtime surface is
  no longer embedded directly in the root session file
- dead root-session local helper residue has also started disappearing: unused
  screen-mode/hash/inactive-screen helpers are gone, and the remaining
  test-facing view-cache shim now delegates through
  `src/terminal/core/session_rendering.zig`
- the remaining scroll-refresh and OSC clipboard copy wrappers also now
  delegate through `src/terminal/core/session_rendering.zig` and
  `src/terminal/core/session_queries.zig`, instead of carrying that
  orchestration inline in `terminal_session.zig`
- backlog hinting now also routes through `src/terminal/core/session_runtime.zig`
  instead of `session_rendering.zig`, so render/publication ownership no longer
  depends on transport ingress state
- host-facing metadata, liveness, and close-confirm signal queries now also
  live under `src/terminal/core/session_host_queries.zig`, leaving
  `session_queries.zig` focused on terminal-data query surfaces such as OSC
  clipboard and hyperlink export
- workspace/runtime input-pressure hinting now also routes through
  `src/terminal/core/session_runtime.zig` instead of staying inline in the root
  session facade
- the first explicit `view_cache` split is now landed too: pure publication/diff
  helpers live under `src/terminal/core/view_cache_publication.zig`, so
  `view_cache.zig` is beginning to separate projection from publication
  planning without changing behavior
- selection projection now also lives under
  `src/terminal/core/view_cache_selection.zig`, so `view_cache.zig` is no
  longer carrying both selection projection and publication/diff helpers inline
- viewport-shift and full-vs-partial publication planning now also lives under
  `src/terminal/core/view_cache_plan.zig`, so `view_cache.zig` is losing more
  publication-policy ownership instead of keeping it mixed with projection
- row-hash refinement now also lives under
  `src/terminal/core/view_cache_refinement.zig`, making that optional
  publication-narrowing step explicit instead of leaving it embedded in the
  base view-cache update path
- selection-change dirty expansion now also lives under
  `src/terminal/core/view_cache_selection_dirty.zig`, so selection-driven
  damage widening is no longer embedded in the base `view_cache` update path
- base dirty/damage assignment and partial-damage widening now also lives under
  `src/terminal/core/view_cache_damage.zig`, so `view_cache.zig` is closer
  again to projection/orchestration than publication policy
- presented-generation acknowledgement and damage retirement now also lives
  under `src/terminal/core/session_rendering_retirement.zig`, so
  `session_rendering.zig` no longer mixes capture/feedback with retirement
  policy inline
- replay-backed redraw-contract coverage has now started too: the replay
  harness supports a presented baseline phase plus explicit damage assertions,
  and the first fixtures lock narrow partial publication for gutter rewrites
  and indent-guide rewrites instead of leaving those redraw shapes covered only
  by unit tests
- replay-backed redraw coverage now also includes dense clear+repaint loops,
  locking the current contract that `ED 2` plus a full visible repaint stays on
  the partial path with full-width viewport damage after a presented baseline
- replay-backed redraw coverage now also includes live-bottom full-region
  scroll, locking the current contract that viewport-shift publication still
  carries widened full-viewport damage bounds while separately tracking
  `viewport_shift_rows`
- replay-backed redraw coverage now also includes a multi-row narrow rewrite
  case that currently widens to full-row damage across the viewport, which is
  exactly the kind of over-broad invalidation we want the later publication
  lane to reduce for gutter/scope-guide-heavy TUIs
- replay-backed redraw coverage now also includes a denser built-in `nvim`
  movement probe (`redraw_nvim_dynamic_builtin_probe.*`) with `statuscolumn`,
  `signcolumn`, `foldcolumn`, `cursorline`, `cursorcolumn`, and a dynamic
  statusline enabled from startup; its observed backend contract is broad, but
  it still preserves the distant statusline row in the same non-shift frame,
  which is useful because it shows backend publication can already carry one
  secondary remote region when the upstream dirty-row truth contains it
- replay-backed redraw coverage now also includes two probes captured against
  the local real Neovim config (`redraw_nvim_real_config_probe.*` and
  `redraw_nvim_real_config_symbols_probe.*`); both preserve remote chrome in
  non-shift frames, and the symbol-aware probe is broad across almost the full
  viewport, which is useful because it shows at least one plugin-heavy config
  path is genuinely emitting broad body-plus-chrome redraws rather than merely
  dropping a remote invalidation region
- deeper live tracing on the same plugin-heavy lane now also shows the
  broadening mechanism more directly: the offending rows are being widened in
  `TerminalGrid.markDirtyRange(...)` by unioning multiple same-row requests,
  not by `view_cache` refinement, widget planning, or skipped dirty retirement
- a scripted capture wrapper now exists for that same lane in
  `tools/terminal_capture_nvim_real_config_cursor_repro.py`, which automates
  the current dashboard -> `:e src/app_logger.zig` -> settle -> slow `j`
  cursor-step repro against the real local Neovim config
- that automation now also has a replay-safe reduced mode (`--open-directly`,
  `16x100`, one aggregate late cursor-step update), and the resulting
  single-session authority is now checked in as
  `redraw_nvim_real_config_cursor_step_probe.*`
- a later-step tuned variant is now also checked in as
  `redraw_nvim_real_config_cursor_step_probe_tuned.*`; it waits longer before
  capturing the first step and keeps one later update chunk, which makes it a
  better automated base for the next narrowing pass even though it is still
  broad overall
- the sharper automated base is now the heavier
  `redraw_nvim_real_config_cursor_step_app_logger_tuned.*` authority captured
  against the real `src/app_logger.zig` file; it comes back as a partial
  viewport-shift-exposed update (`rows 7..15 cols 0..99`, `shift_rows=9`),
  which is closer to the live ghosting lane than the smaller synthetic sample
- follow-up scripted `app_logger.zig` captures now tighten that scope further:
  the attempted "pre-shift" variants still replay as shift-path updates too,
  including a single-step `20Gzt` capture that comes back as
  `viewport_shift_rows=3`, `viewport_shift_exposed_only=true`
- the low-level grid trace on that one-step case now attributes the broad rows
  directly to `origin=scroll_region_up_full`
- a lower-level idle control narrows that further: an open-direct
  `app_logger.zig` capture with `20G` and no cursor-step at all still replays
  as a smaller shift-path update (`rows 14..15`, `shift_rows=2`), again
  attributed to `origin=scroll_region_up_full`
- a longer-settle split now separates startup churn from real movement:
  - idle after a long settle goes empty
  - same-line `l` after settle stays narrow and non-shift
    (`row 15 cols 75..76`, `shift_rows=0`)
  - same-row `w` after settle also stays narrow and non-shift
    (`row 15 cols 11..21`, `shift_rows=0`)
  - vertical `j`/`k` cases in the same settled lane still publish broad
    full-width shift-path updates
  - left/backward motion is asymmetric there too: `h` and `b` still blow out
    to the same bottom-band shift class, while `l` and `w` stay narrow
- current interpretation:
  - the scripted real-config `app_logger` lane is good authority for
    shift/scroll ghosting
  - it is currently dominated by async post-open shift churn
  - after the long settle, movement class matters: forward/rightward motions
    (`l`, `w`) are true narrow non-shift controls, while backward/leftward or
    vertical motions (`h`, `b`, `j`, `k`) currently belong to the broad
    bottom-band shift-path class
  - it is not yet valid authority for the user-reported true small-move
    non-shift ghosting path
  - the next missing capture is therefore a genuine pre-shift real-config
    cursor-step authority
- replay harness fixture metadata loading was widened from `64 KiB` to
  `1 MiB` so legitimate plugin-heavy redraw fixtures like this can be loaded
  directly instead of forcing another side channel
- stale private root-session shims for SGR application and key-mode flag reads
  are now removed too, keeping the root session file closer to a real facade
  instead of a pile of dead internal forwarding

### 2026-03-10 protocol split follow-up

The next extraction-only step moved pure engine-side protocol helpers behind
`src/terminal/core/terminal_core_protocol.zig`.

This module currently owns the protocol behaviors that are already clearly
core/model-centered:

- screen erase/insert/delete helpers
- palette lookups
- core cursor and cell queries
- cursor style changes
- tab-stop-at-cursor
- DECRQSS reply formatting that only depends on core state

`session_protocol.zig` now remains focused on the still session-coupled pieces:

- parser feed/dispatch entrypoints
- alt-screen transitions
- selection/cache invalidation coordination
- runtime-facing protocol side effects

### 2026-03-10 dispatch split follow-up

Parser/control dispatch ownership is now partially split again:

- `src/terminal/core/terminal_core_dispatch.zig` owns control, CSI, OSC, APC,
  DCS, codepoint, and ASCII dispatch entry helpers
- `session_protocol.zig` now keeps the session-coupled pieces that still depend
  on session-owned locking and publication

The main remaining reason parser feed still lives in `session_protocol.zig` is
that byte feed currently owns:

- state mutex acquisition
- output generation increments
- view-cache publication updates

That is the next real boundary to cleanly separate if we want parser feed to
become fully core-owned.

### 2026-03-10 feed split follow-up

Parser byte feed is now split one step further:

- `src/terminal/core/terminal_core_feed.zig` owns the actual parser feed call
- `src/terminal/core/terminal_core_feed.zig` now also returns an explicit
  `FeedResult` carrying publication-relevant state
- `session_protocol.zig` now only wraps that feed with:
  - state mutex ownership
  - delegation of generation/view-cache publication to
    `src/terminal/core/session_rendering.zig`

This makes the remaining session-owned part of parser feed explicit: it is not
parsing anymore, it is lock and publication choreography.

### 2026-03-10 first transport contract

The first internal `TerminalTransport` contract is now landed in
`src/terminal/core/terminal_transport.zig`.

Current scope:

- PTY open/start wiring
- transport resize delivery
- has-data checks
- child-exit polling
- aliveness checks
- foreground-process label and close-confirm metadata
- transport deinit

Current PTY-backed runtime code now consumes that contract in:

- `session_runtime.zig`
- `resize_reflow.zig`
- `session_queries.zig`

This was intentionally not the final transport split at first: host lifecycle
and metadata were moved behind the contract before byte IO.

### 2026-03-10 writer contract follow-up

The transport boundary now also owns the main locked writer contract:

- `terminal_transport.Writer` replaces the old raw `Pty` writer guard
- input send paths now call transport-owned writer methods for:
  - key actions
  - key action events
  - keypad sends
  - char actions
  - char action events
  - mouse reports
  - plain text sends
  - raw byte writes

This means the common protocol/input write surface no longer depends on a raw
`Pty*` shape.

What still remains PTY-direct:

- a smaller set of transport setup/existence paths

### 2026-03-10 read path follow-up

The transport boundary now also owns the common read side:

- `terminal_transport.Transport.read(...)`
- `terminal_transport.Transport.waitForData(...)`

Current PTY-backed runtime code now uses those methods in:

- `io_threads.zig`
- `pty_io.zig`

This means the main byte pump no longer depends on raw `Pty` ownership in the
runtime helpers. The remaining PTY-direct uses are narrower and mostly about
transport existence checks plus setup paths that have not been re-cut yet.

### 2026-03-10 transport presence follow-up

The remaining low-risk presence gates are now also routed through
`terminal_transport` helpers:

- `terminal_transport.Writer.exists(...)`
- `terminal_transport.Transport.exists(...)`

Current session-side users no longer peek at `self.pty` directly just to answer
"is there a writable transport?" for the mouse-report and OSC 5522 paste-event
paths.

The protocol-side OSC 5522 reply/read path now also uses the locked transport
writer contract instead of reaching into raw `self.pty` ownership directly.

### 2026-03-10 attach/detach follow-up

PTY setup now also has a transport-owned attach/detach seam:

- `terminal_transport.attachPty(...)`
- `terminal_transport.detachPty(...)`

Current users:

- `terminal_transport.openPty(...)`
- `replay_harness.zig` reply-capture setup

That removes another direct `session.pty = ...` / `session.pty = null` setup
pair from callers outside the transport owner.

## Immediate Naming Direction

These names are recommended to avoid ambiguity:

- `TerminalCore`
- `TerminalCoreSnapshot`
- `TerminalCoreEvent`
- `TerminalTransport`
- `PtyTerminalSession`

Avoid continuing to use `TerminalSession` as the name of the engine center once
the new boundary exists.

## Non-goals

- no Flutter-specific rendering API
- no renderer rewrite in this lane
- no protocol behavior change just to fit the new names
- no broad workspace/UI redesign mixed into the core move

## First Code-Cut Intent

The first implementation slice should be:

- introduce a new internal `TerminalCore` owner
- move no UI behavior
- keep current PTY-backed session behavior identical
- leave FFI surface stable for that slice

That gives the redesign a real center without forcing a full bridge rewrite in
the same patch.
