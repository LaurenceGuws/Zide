# Renderer Backend Current State

Purpose: describe the renderer/backend contract Zide currently has, not the one
it wants.

This is the current-state companion to
`app_architecture/ui/RENDER_BACKEND_CONTRACT.md`.

## Executive Truth

Zide is in a much better place than before, but it does not yet have a
best-in-class backend abstraction.

OpenGL and Metal now both exist as real lanes, but the shared renderer still
knows too much about both implementations.

So the honest answer to "would Vulkan be easy to add?" is:

- easier than before
- not yet easy

**Vulkan fit audit (2026-04-06):** See `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md` (executive
verdict updated to match post-deferral code). Verdict: a Vulkan backend is **not**
yet “routine” against the **current** code. The audit’s “GL immediate vs Metal
deferred `SurfaceDraw`” finding is **superseded**: OpenGL now defers the full
surface queue too. Remaining dominant risks: uneven presentable maturity,
renderer-hosted dual backend bundles, flush/ordering around mixed draw paths, and
atlas/terminal/chrome composition. **Gate status and readiness** (Vulkan vs
Android platform vs Android rendering) live in `RENDER_BACKEND_CONTRACT.md`
§ “Gate status (code truth)” and § “Readiness (authoritative)”.

## Adoption Answer

The direct answer to "what is still standing between us and Vulkan/Android
rendering adoption?" is:

- not terminal correctness anymore
- not shell chrome ownership anymore
- still the shared backend contract itself

In current-state terms, the remaining blockers are:

1. `SurfaceDraw` submission story is now unified — **Gate 1 met (2026-04-08)**

- OpenGL defers all `SurfaceDraw` variants in a per-frame queue and replays at
  explicit flush boundaries plus `submitFrame`, matching Metal's deferred surface
  phase at the product level
- flush discipline is now enforced at every immediate-draw site:
  `drawTextureRect`, `flushTerminalBatch`, and `GlyphCache.flush` all drain the
  surface queue before any immediate GL work
- `gl_presentable_runtime::updateRetainedPresentable` flushes the surface queue
  at body-end before restoring the scene target, so kitty-above images and other
  deferred draws land in the retained FBO instead of leaking to the scene target
- no remaining call site allows an immediate GL draw to jump ahead of a queued
  `SurfaceDraw`

2. Presentable behavior is cleaner but still uneven

- parity has improved
- ownership is cleaner
- but retained/direct/snapshot lifecycle is still not neutral enough that a
  Vulkan or Android renderer would feel routine

3. Backend runtime storage still widens under shared ownership

- the runtime bundle is cleaner than before
- it is still a renderer-hosted widening pattern
- this has narrowed slightly again on the Metal lifecycle lanes:
  the generic surface queue and the terminal-presentable composition queue now
  live under backend context instead of as separate renderer-hosted runtime
  lists beside the backend context/frame slots
- the live Metal frame slot now follows that same rule too, so acquire/submit/
  abandon state is kept with backend context instead of as another renderer-
  hosted runtime peer

4. Remaining ordering pressure is now concentrated, not solved

- shell chrome has been carved out behind `renderer_chrome_band_host.zig`
- terminal has been carved out behind terminal/presentable seams
- the remaining loud generic families are editor banding and sample/diagnostic
  section banding

That sample/diagnostic pressure is narrower again because `font_sample_view.zig`
no longer rides the editor presentable lane. Diagnostic/sample rendering stays
direct.

The editor widget draw path is now honest about the same truth: it no longer
keeps a dead retained/direct branch inside `editor_widget_draw.zig`. The live
editor path is direct-only.

The shared presentable contract is tighter too: the dead `.editor` presentable
surface is gone, so the live shared presentable contract is terminal-only
again. If editor retained presentation returns later, it must come back as a
reviewed lane instead of a dormant branch inside the generic presentable
contract.

Terminal presentable ownership is cleaner too: the terminal widget no longer
spells out backend `begin/end` lifecycle directly. That update cycle now
terminates in `renderer_presentable_host.zig`.

The naming now matches that ownership truth too: the host seam uses
`terminalPresentable*` names instead of generic `presentable*` names, which is
more honest while terminal is the only live shared presentable family.

That has improved slightly again at the shared lifecycle boundary too:
backend dispatch no longer exports `beginPresentable(...)` /
`endPresentable(...)` as first-class shared presentable verbs. The live shared
host seam now asks for exactly one thing there: "attempt one retained terminal
presentable update cycle." OpenGL still satisfies that by opening a retained
target, running the update body, and restoring composition state; Metal still
reports that no retained update cycle exists and stays on the snapshot plus
composition path.

That has improved slightly again on the OpenGL side too: terminal presentable
target-slot access now routes through `gl_backend` helpers instead of
`gl_presentable_runtime.zig` reaching directly into
`renderer.backend.runtime.opengl.presentable_targets`.

So the remaining presentable blocker is now more precise than before: OpenGL
still owns a real retained update target, while Metal still owns a terminal
snapshot plus composition replay queue. The shared API is cleaner, but the
lifecycle model is still materially uneven.

That is a much better answer than the repo had before, but it is still a
blocking answer.

One more caller-surface leak is gone: generic app/widget solid and outline
fills no longer bounce through `Shell.drawRect(...)` /
`Shell.drawRectOutline(...)`. Those callers now terminate in
`renderer_surface_host.zig` directly. This does not solve the remaining
surface-phase timing contradiction, but it does remove another broad
convenience seam between product code and the shared surface host.

## What Is Good

### Capability naming is better

`RendererCapabilities` now lives in
`src/ui/renderer/capability_contract.zig` and describes real runtime behavior
such as:

- scene composition mode
- terminal presentation mode
- screenshot mode
- text rendering mode
- atlas storage mode
- raw image texture support

That is a meaningful improvement over backend-label theater.

That has improved slightly again: the capability enums/struct are no longer
owned by `renderer.zig`, and backend modules now report capability truth
through that shared contract instead of the renderer root hardcoding every
OpenGL/Metal capability combination itself.

### Metal is no longer hypothetical

The Metal lane now has real implementation coverage for:

- frame acquisition/submit
- atlas ownership
- raw image drawing
- terminal snapshot/presentable behavior
- live terminal interaction and partial-update paths

That makes OpenGL and Metal useful comparison pressure instead of paper plans.

## Where The Contract Still Fails

### 1. `Renderer` still stores concrete backend runtime state

In `src/ui/renderer.zig`, the shared renderer now owns one dedicated backend
host containing:

- `backend.ops`
- `backend.runtime`

That is cleaner than carrying separate backend dispatch and backend runtime
peer fields on the renderer root, and it is a worthwhile host-shape
improvement.

But it is still backend-native runtime state living under shared renderer
ownership. The runtime host no longer materializes both OpenGL and Metal state
side-by-side; it now stores only the selected backend runtime and no longer
embeds it inline on `Renderer`. The selected runtime also no longer lives
behind a renderer-owned backend-tagged union surface; it now sits behind one
opaque selected-runtime handle plus backend kind, with implementation state
such as:

- OpenGL:
  - `backend.runtime.opengl.context`
  - `backend.runtime.opengl.resources`
  - `backend.runtime.opengl.targets`
- Metal:
  - `backend.runtime.metal.backend_context`
  - `backend.runtime.metal.preview_source`
  - `backend.runtime.metal.diagnostic_font`

Current pressure is narrower than it used to be:

- shared code outside backend modules no longer meaningfully reads this bundle
  directly
- `Renderer` no longer materializes both backend states at once
- `Renderer` no longer embeds selected concrete backend runtime inline either
- runtime storage init/deinit no longer runs directly out of
  `Renderer.init()` / `Renderer.deinit()`; it now routes through backend
  runtime ops
- shared code no longer reaches directly into `renderer.backend.ops` /
  `renderer.backend.kind`; that now terminates at `renderer_backend_host.zig`
- backend-host construction also no longer lives open-coded in
  `Renderer.init()`; it now routes through `renderer_backend_host.zig`
- the remaining blocker is that `Renderer` still owns the backend host surface
  itself (`kind` + ops + opaque runtime handle)

Android host/bootstrap work now makes that blocker immediate instead of
theoretical:

- a third backend would still pressure this renderer-owned backend-host story
- Android rendering is now blocked here, not by host-surface ambiguity

That means the renderer root is still partly the backend implementation center,
not just the backend-neutral host/facade.

This has improved slightly because backend-native state is now grouped under a
single backend host instead of being scattered as unrelated renderer peers.

But it is still not the end-state. Shared renderer lifecycle, teardown, and
submission logic still depend on backend-native state shape directly.

This has improved slightly again at the root shape too: backend-facing ops and
backend-native runtime no longer sit on `Renderer` as two separate peer
surfaces. They now live under one backend host, which makes the remaining
ownership problem narrower and more explicit.

This has improved slightly again: backend teardown now runs through backend
modules instead of `Renderer.deinit()` spelling out both OpenGL and Metal
cleanup inline.

This has improved slightly once more: backend startup/init now also runs
through backend modules instead of `Renderer.init()` and
`runStartupBackendSmoke()` spelling out both OpenGL and Metal boot logic
inline.

This has improved slightly again: Metal-only maintenance helpers such as
queued-surface cleanup and diagnostic-font cleanup now live on the Metal
backend instead of `Renderer` carrying those backend-specific chores itself.

This has improved slightly again on the OpenGL side too: shared draw/text code
now goes through `gl_backend` helpers for white-brush access, batch pipeline
binding, VBO growth, texture-kind uniform updates, and text-render uniform
sync instead of reaching directly into `renderer.opengl_runtime` for each of
those actions.

This has improved slightly again on the Metal side too: shared Metal-facing
renderer code now goes through `metal_backend` helpers for runtime-context
lookup, queued-surface append, and queued-surface count instead of open-coding
those `renderer.metal_runtime` storage details at each call site.

That has improved slightly again: renderer/font call sites that only need
Metal atlas hooks, glyph-atlas readiness, or snapshot-presentable status now
also route through renderer-level `metal_backend` helpers instead of manually
unwrapping the backend context at each call site.

That has improved slightly again: the shared renderer root no longer passes the
Metal queued-surface list directly into the sampled-text builders for sampled
text runs and terminal cell runs. Those queue handoffs now route through
`metal_backend` helpers too.

That has improved slightly again in the Metal frame path: frame-slot access and
queued-surface replay now route through `metal_backend` helpers instead of
`metal_frame_runtime.zig` directly mutating and iterating the
`renderer.metal_runtime` storage fields itself.

That has improved slightly again at the renderer root: the Metal diagnostic
font cache/ensure path now lives behind `metal_backend` instead of the
renderer root carrying its own backend-specific diagnostic-font initializer and
cache management logic.

That has improved slightly again at the renderer root: Metal snapshot
presentable draw and raw-image enqueue paths now also route through
`metal_backend` helpers instead of the renderer root assembling those backend
draw requests inline.

That has improved slightly again at the renderer root: even the one-off Metal
smoke frame and the basic Metal `SurfaceDraw` variant packaging now route
through `metal_backend` helpers instead of `Renderer` spelling out those
backend-specific assembly details itself.

The presentable contract has improved slightly again too: the Metal terminal
snapshot-presentable path now participates in the shared presentable contract
through `metal_backend` entrypoints, instead of
the terminal presentation runtime carrying a separate Metal-only bypass branch
for availability, ensure, draw, and scroll.

That has improved slightly again on the widget-side contract too: the tiny
terminal-specific presentable wrapper is gone, and
`terminal_widget_presentation_runtime.zig` now talks to the renderer
presentable contract directly instead of bouncing through one more forwarding
module.

That has improved slightly again at the app boundary too: **Metal glyph-atlas
readiness, atlas preview source, atlas-upload diagnostics, and terminal font
Metal atlas hooks** are **`Renderer` methods** that delegate into
`metal_backend`, and **`app_shell` does not re-export or forward** those
concerns. macOS diagnostic/smoke runtimes and the Metal text diagnostic view
call `shell.rendererPtr()` (and `ui/font_sample_view.zig` asks the renderer for
hooks) instead of growing another Shell seam or importing `metal_backend` from
UI modules.

That has improved slightly again inside the Metal state bundle too: atlas
preview/debug state now lives under `metal_runtime.preview_source` instead of
as a separate backend-specific field on the renderer root.

That has improved slightly again on the presentable-storage side too: the
OpenGL retained-presentable cache is no longer stored as a direct renderer-root
field. It now lives under `opengl_runtime.presentable_targets`, which is a
better fit for the truth that the richer retained-presentable lifecycle is
currently an OpenGL-owned implementation shape.

However, retained **editor** presentation is no longer part of the live shared
presentable contract. The direct editor path was restored after IDE geometry
testing exposed a mismatch between retained editor presentation and the shared
layout/presentation story. After fixing pane-width/layout truth, we retried the
retained path and it still regressed live editor behavior, so the widget stays
on the direct path and the dead shared `.editor` presentable arm has been
removed. If editor retained presentation returns later, it must return as a
fresh reviewed lane rather than a dormant shared contract branch.

Part of that mismatch was more basic than retained-target ownership: editor
column/layout truth was still partly derived from full-window width instead of
the actual editor pane width. That has now been corrected in the widget/runtime
lane, which sharpens the remaining retained-editor problem instead of letting
pane-width lies masquerade as a retained-presentable-only bug.

That has improved slightly again inside the OpenGL presentable path too:
retained-target lookup now routes through small backend-owned slot helpers
instead of open-coding terminal/editor target storage access at each
presentable operation site.

That has improved slightly again at the shared facade boundary too: the
renderer-owned presentable facade methods now live in
`renderer_presentable_host.zig` instead of `renderer.zig` directly. This does
not make the presentable lifecycle fully backend-neutral yet, but it removes
another small renderer-root ownership seam from that surface.

Backend-runtime truth has improved slightly again too: direct
`renderer.backend_runtime.*` reaches are now effectively confined to
backend-owned modules. The remaining runtime-storage blocker is not shared
widget/app leakage anymore; it is that the renderer root still physically owns
the backend runtime bundle shape.

That has improved slightly again on the caller-facing lifecycle edge too: the
renderer root no longer exports `beginPresentable(...)` / `endPresentable(...)`
as if those were stable product verbs. The widget/view callers that actually
perform retained-surface updates now route to
`renderer_presentable_host.zig` directly for that edge, which is more honest
than pretending the renderer root owns a backend-neutral begin/end lifecycle
when Metal still does not.

That has improved slightly again on the terminal lane specifically: the
terminal widget no longer sequences `beginPresentable(...)` /
`endPresentable(...)` itself. It now asks `renderer_presentable_host.zig` to
run one terminal presentable update cycle, which is a better ownership story
for backend lifecycle primitives that are only meaningful on OpenGL today.

That has improved slightly again on the rest of the facade too: the renderer
root no longer exports the remaining presentable forwards
(`ensurePresentable`, `presentableAvailable`, `drawPresentable`,
`scrollPresentable`, `presentableInfo`). Widget/view/diagnostic callers now
route to `renderer_presentable_host.zig` directly for the shared presentable
contract surface, which makes the ownership boundary plainer: the renderer root
no longer claims to own a facade that already lives elsewhere.

That has improved slightly again on the draw/resource side too: persistent
image upload/draw/destruction and raw-image submission no longer live as public
methods on the renderer root. Those callers now route through
`renderer_draw_host.zig`, which is more honest than pretending `Renderer`
itself owns that caller-facing draw/resource facade when the grouped draw
contract was already the real owner.

That has improved slightly again at the tiny edge too: even the old
`clearToThemeBackground()` renderer-root forward is gone. The one remaining
caller (font sample) now talks to `renderer_draw_host.zig` directly instead of
asking the renderer root to proxy that draw-contract verb.

That has improved slightly again on the terminal draw side too: terminal rect
and glyph submission no longer live as public methods on `Renderer`. Terminal
text/grid/presentation code now routes through `renderer_terminal_draw_host.zig`
instead, which makes that contract read like one explicit host seam rather
than one more renderer-root facade over backend draw ops.

That has improved slightly again on the shared text side too: general text draw
entrypoints (`drawText`, monospace/background variants, icon text, char draw,
and icon measurement) no longer live as public forwards on `Renderer`.
Shell/UI/editor callers now route through `renderer_text_host.zig` instead,
which is more honest than keeping one more renderer-root facade over
`text_runtime`.

That has improved slightly again inside the backend dispatch contract too: the
old mixed `backend_ops.draw` bucket has now been split into smaller groups with
clearer meaning:

- `clip`
- `terminal_draw`
- `image_draw`
- `surface`

That is more honest than one draw grab bag mixing clip state, terminal cell
primitives, persistent/raw image operations, and generic surface submission.

That has improved slightly again on the leftovers too: the old backend
`clearThemeBackground` hook is gone. It only existed as a special-case clear
path for one caller, and plain `drawRect(...)` semantics were the more honest
contract path.

That has improved slightly again on the surface-submission side too: the
`surface` contract now terminates in dedicated backend modules
(`gl_surface_runtime.zig` / `metal_surface_runtime.zig`) instead of routing
back into the larger backend files. That seam is now the normal place to adjust
OpenGL/Metal surface queue behavior without widening `renderer.zig`.

That has improved slightly again on enforcement too: the shared `SurfaceDraw`
payload is no longer exported from `renderer.zig`, and
`renderer_surface_host.recordSurfaceDraw(...)` is now host-private. Product
code still has the higher-level solid/image/presentable helpers, but it can no
longer quietly depend on direct generic `SurfaceDraw` construction as if that
were a stable public renderer API.

The remaining truth is now plain:

- OpenGL surface submission queues **all** `SurfaceDraw` variants and replays
  them at `flushQueuedSurfaceDrawsNow` boundaries plus `submitFrame`
- Metal surface submission still means "record this draw for the submit-time
  surface phase"
- Metal terminal presentable composition now also has a second, narrower queue:
  terminal presentable backdrop fills and terminal presentable blits are
  recorded separately and replayed after terminal snapshot capture, not mixed
  into the generic surface phase

And the remaining caller set is already narrow enough that this is no longer a
caller-sprawl problem. The active shared `SurfaceDraw` producers are mainly:

- generic UI/editor/shell fills through `renderer_surface_host.zig`
- text-runtime generic background clears
- presentable/snapshot blits
- raw image / atlas samples that already fit the shared payload model

Terminal pane / viewport fills are no longer part of that shared caller set.
They now route through the presentable seam as terminal presentable backdrop
work, which also lets Metal keep them adjacent to terminal presentable blits in
one narrower composition queue after snapshot capture.

So the backend-fit blocker is now concentrated:

- the same narrow shared payload reaches both backends
- surface-phase **submission** is now aligned: both backends treat
  `recordSurfaceDraw` as deferred work; OpenGL executes it in FIFO order at
  `flushQueuedSurfaceDrawsNow` (wired through `renderer_text_host` and a few
  explicit widget boundaries) and again at `submitFrame`

The old “GL solids immediate, Metal deferred” contradiction at the surface
contract is closed. What remains is **composition hygiene**: any path that
records surface fills/blits and then draws through `draw_ops` or `text_draw`
without the text host must insert `flushQueuedSurfaceDrawsBeforeDependentSurfaceWork`
on OpenGL (editor decorations, font sample preview text, etc.). That is a
caller-bypass problem, not a backend fork on `.solid`.

OpenGL and Metal surface-phase helpers still distinguish fills from blits
internally for atlas/raw-image lifetimes.

Observability: present traces report `gl_surface_solid_enqueue` (solids accepted
into the GL deferred queue) and `gl_surface_queued_replay` (draws executed on
replay).

That split also exposed the next hard truth more clearly: generic blits are
still not a free submit-time subset. Kitty images can interleave with terminal
text, and shell/tab icons still draw before adjacent labels at the same call
site. So raw-image/atlas blits still carry local ordering dependencies even
though they are not fills. The only relatively isolated blit family left is
retained presentable/snapshot draw, which already belongs to the presentable
contract and is too narrow to close the shared `SurfaceDraw` timing gap on its
own.

The remaining **composition** problem is still structured into a few families
where one visual band mixes surface-recorded fills with immediate texture or
outline work:

- shell/UI chrome bands (`status_bar`, `tab_bar`, `shared_top_bar`,
  `side_nav`, caption/notice/confirm surfaces)
- editor row/gutter/current-line banding (draw-list ordering + explicit GL
  flushes at row boundaries)
- sample/diagnostic sections (section fills + `text_draw` preview paths that
  bypass the text host)

The next semantic cuts should strengthen those band phases and remove bypass-path
flush debt, not revisit per-backend `.solid` timing.

The shell/UI chrome family is the clearest next candidate, but it is also the
first place where the stronger-phase requirement is undeniable: ordinary UI
text draw paths (`drawText`, `drawTextOnBg`, icon text, and most app-font draw
work in `text_runtime.zig`) are still immediate texture draws, not recorded
surface-phase work. So shell chrome cannot move as "just the fills" without
splitting labels/icons from their band backgrounds again. The next real cut in
that family therefore needs either:

- a stronger band/composition phase that owns both fill and dependent text
- or a narrower shell-chrome subset whose dependent work is already recorded
  together

The narrower-subset audit did not find a free lane yet. Config reload notice,
terminal close-confirm UI, and caption buttons all still combine fills with
immediate text and/or immediate outline/icon primitives at the same call site.
So shell chrome remains a real phase-design problem, not a hidden
micro-refactor.

The current best direction is now clear enough to state: shell/UI chrome needs
its own band-composition seam. That seam should own one local ordering unit for
background fills plus the dependent text/icon/outline work that currently sits
next to those fills at the same call sites. In other words, the next useful
design cut is not "delay chrome fills"; it is "stop expressing chrome bands as
one fill path plus one unrelated immediate text path."

That should stay intentionally narrower than a whole new generic UI draw
system. The pressure is specifically on:

- status bar
- tab bar
- shared top bar
- side nav
- nearby notice/confirm/chrome surfaces where the same band logic applies

If that seam proves out, it may later inform editor/sample banding too. It
should not be born as a repo-wide replacement for all generic UI draw paths.

There is now one small proof point in code: a narrow widget-side chrome band
host exists and the status bar, tab bar, shared top bar, and side nav have
been routed through it. That is still an organizational seam, not a solved
backend phase. Its value is that those chrome families now have one explicit
local composition surface to grow, instead of staying expressed only as
unrelated shell draw calls.

The config-reload notice now also rides that seam. The terminal close-confirm
card does not. That split is intentional: the band host is for strip/chrome
composition, not for generic popup/modal ownership.

The seam has also graduated out of `widgets/` and into the renderer host area
as `renderer_chrome_band_host.zig`. That is an ownership correction, not a
claim that shell chrome already has a solved backend-neutral phase.

It now also terminates directly in renderer surface/text hosts rather than
routing back through `Shell` forwards. That reduces one more fake layer between
chrome composition intent and the renderer host surfaces it really uses.

That seam is slightly more honest again now: band-local `drawText(...)` /
`drawIconText(...)` use explicit bg-aware text entrypoints, so chrome labels and
icons no longer implicitly rely on transparent text defaults while the seam
already carries a band background color.

It is slightly stronger again too: those band text/icon operations are now
queued and flushed explicitly at band end (`Band.flush()`), instead of relying
only on immediate interleaving at each call site.

It now has a tiny host-level consumption boundary too: `Band.flush()` is
wrapped by `beginBandCommandGroup` / `endBandCommandGroup` in renderer host
space. That boundary is a no-op today, but it gives this seam one explicit
group handle for future phase integration.

Band-local text op storage has also moved from a fixed-capacity array to
dynamic list storage. That removes the previous overflow fallback that escaped
the local queue path by drawing immediately.

Replay routing is now owned by the shared text phase host:
`Band.flush()` delegates through `renderer_text_phase_group_host` using
`.chrome_band` group replay instead of issuing text host calls directly.

That shared replay seam has focused unit coverage for group wrapping and
recorded op replay order.

Band group boundaries are observable in present trace
(`band_group_begin_count` / `band_group_end_count`) via the shared text phase
group begin/end contract.

Milestone B closure planning now has a frozen target contract too: one shared
text phase group shape (typed ops + explicit begin/end groups + trace parity)
with three required adopters (chrome band, sample section, editor row-band).
That removes ambiguity about "what counts as done" for this lane.

That contract has its first concrete unification checkpoint now (`B-DONE-2`):
chrome-band and sample-section replay share one typed group/replay host surface
in `renderer_text_phase_group_host.zig`.

`B-DONE-4` has now removed the seam-local replay adapters, so chrome and sample
call the shared host contract directly.

Editor adoption is now complete for this checkpoint (`B-DONE-3`): both editor
draw-list row-band flush and immediate/fallback row-band execution are wrapped
in explicit `.editor_row_band` group boundaries via the same shared host seam,
with trace counters and mismatch warnings wired.

Observability parity is now closed too (`B-DONE-5`): chrome, sample, and editor
row-band groups all expose begin/end counters and mismatch warnings under one
consistent naming family.

Regression coverage is now stronger too (`B-DONE-6`): unified host seam tests
explicitly assert empty/non-empty replay behavior, op-kind order, bg payload
propagation, and editor row-band group forwarding.

Stale API cleanup is now done too (`B-DONE-7`): quasi-public bypass helpers were
reduced and product callers no longer depend on retired chrome/sample adapter
surfaces.

This closure lane is now complete too (`B-DONE-8`): text phase group adoption
and closure deltas are reflected in contract/current-state/todo docs, and this
family is no longer the primary Adoption Gate blocker.

That seam is now clean enough that further expansion would be fake progress
unless it graduates into a real recorded band-composition phase. Until that
happens, it should be treated as a renderer-host composition helper for the
current shell chrome family, not as a solved backend-neutral contract.

That also means the remaining generic `SurfaceDraw` timing pressure is no
longer led by shell chrome. With terminal presentable fills moved out and shell
chrome routed through the chrome-band seam, the primary remaining ordering
family is now editor banding and editor-adjacent overlay fills. The
sample/diagnostic section lane is still active, but it is the narrower
secondary family now.

Those are the places where background-plus-dependent-text ordering still most
directly pressures the generic surface phase.

Those two families should not be treated as one problem shape, though:

- editor already has a local row/segment composition path through its draw list
  and cached presentable flow; its pressure is about where the remaining direct
  `renderer_surface_host.drawRect(...)` calls still escape that local ordering
  story
- font/sample sections are much simpler explicit band draws followed by
  dependent text; if a new seam is proven there, it should stay narrow and not
  pretend to solve editor composition automatically

That split is now sharper from code inspection too:

- editor pressure is specifically row-band/gutter/current-line fill work in
  `editor_widget_draw.zig` that still pairs with immediate text/overlay
  rendering in the direct/fallback path
- that editor lane is at least slightly more explicit now: direct/fallback
  segment-base painting routes through one helper in `segment_paint.zig`
  instead of staying as scattered immediate rect calls in
  `editor_widget_draw.zig`
- pane-level editor background/gutter clears now follow that same rule too:
  they run through one explicit helper in `segment_paint.zig` instead of
  sitting as stray generic surface calls at the widget draw entrypoints
- the fallback line-base path is also explicit now: it no longer mixes
  immediate base fills with a one-op draw-list flush just to render the line
  number/current-line label
- cached/list-side segment-base painting now also follows that same rule
  through `segment_paint.zig` instead of open-coding its own row/gutter/
  current-line rect sequence in the widget draw body
- that makes the next editor requirement explicit too: one editor row-band
  composition unit still needs to own base fills, line number label,
  selection/search overlays, text runs, and cursor/caret decoration as one
  local ordering story
- there is now stronger proof of that in code:
  - the fallback editor path runs through one explicit immediate row-band
    composition helper in `segment_paint.zig`
  - the cached/list editor path runs through one explicit draw-list row-band
    composition helper there too, instead of spelling that payload inline in
    the widget draw body
- that is still not full timing closure because the immediate and draw-list
  row-band lanes remain distinct concrete implementations
- two remaining editor visuals are now explicitly outside that row-band
  contract by ownership rather than accident:
  - IME/composition text + underline are cursor-anchored interaction overlays
  - scrollbars are pane-level final overlays
- that keeps the remaining editor timing pressure focused on row-band local
  ordering rather than those overlay families.
- the next editor-local split is now more specific too:
  - fallback highlighted text still emits through direct text/decor functions
    in `editor_widget_draw_text.zig`
  - cached/list rendering emits the same semantics through draw-list text/rect
    ops there
- traversal, decoration geometry, and expanded styled-text run splitting are
  now shared there, so further local editor cleanup is only honest if it
  removes that final emitter split or changes the real surface/timing
  contract.
- the remaining backend-runtime storage blocker is now more specifically
  OpenGL-shaped than Metal-shaped:
  - Metal live frame/surface/presentable queue state now lives under backend
    context
  - OpenGL has improved one step: retained presentable targets and offscreen
    scene-target lifecycle now live under one explicit
    `opengl_runtime_state.TargetRuntime` stratum
  - OpenGL improved again: GL shader/VBO/text resource ownership now lives
    under one explicit `opengl_runtime_state.ResourceRuntime` stratum too
  - the remaining OpenGL runtime shape is now three explicit backend-native
    strata in one state object:
    - SDL GL context ownership
    - GL shader/VBO/text resource ownership
    - retained target / scene-target lifecycle
- that is materially narrower than before, but not closure. The next honest
  OpenGL runtime cut now has to be semantic, not just first-pass storage
  disentangling.
- presentable lifecycle is slightly cleaner too: the OpenGL presentable runtime
  no longer carries an internal begin/end retained-update split behind the
  shared host contract. It now exposes one retained update-cycle verb
  directly, matching the current contract surface more honestly.
- the Metal side now states the opposite truth in its own runtime too:
  lack of retained update-cycle semantics is no longer an anonymous false stub
  in backend dispatch; it is named in `metal_presentable_runtime.zig`.
- the shared terminal presentable host now carries that distinction more
  honestly too: retained-update attempts return an explicit status instead of a
  boolean that used to collapse "unsupported lifecycle model" and
  "retained target unavailable" into the same false path.
- shared code no longer asks for a backend lifecycle enum there at all. The
  terminal runtime now simply attempts the retained update-cycle contract and
  receives `.updated`, `.unavailable`, or `.unsupported`.
- the top-level terminal presentation entry is now slightly cleaner too:
  `terminal_widget_presentation_runtime.zig` no longer chooses direct-vs-
  retained execution first in its own body. That present-path decision now
  routes through one host-owned seam in `renderer_presentable_host.zig`
  (`runTerminalPresentPath(...)`), while the existing direct and retained
  execution bodies remain behavior-identical behind it.
- terminal widget code no longer asks the renderer root for
  `terminalPresentationMode()` / `usesDirectTerminalPresentation()`. That
  terminal-present path decision now lives in `renderer_presentable_host.zig`
  with the rest of the terminal presentable seam, and the host now resolves it
  from backend presentable ops instead of inferring it from capability
  metadata.
- draw metrics no longer need `renderer_presentable_host.zig` to proxy
  capability state either; they read `RendererCapabilities.terminal_presentation_mode`
  directly, leaving the presentable host focused on the presentable contract.
- the editor styled-text split is slightly narrower now too:
  `editor_widget_draw_text.zig` uses one shared highlighted-token traversal for
  both immediate and draw-list paths. The remaining split is still real, but
  it is now at the emitter layer rather than duplicated traversal policy.
- that split is slightly narrower again: underline / undercurl /
  strikethrough geometry now also runs through one shared helper there. The
  remaining editor styled-text difference is increasingly about emitter target,
  not separate geometry/traversal policy.
- that is narrower again too: expanded styled-text run splitting over
  tabs/wide-glyph spans now shares one helper. The remaining editor styled-text
  split is now more clearly at the final immediate-vs-draw-list emission edge.
- unstyled selection/bg text-run splitting is now shared there too.
- that final local editor emitter split has now been removed as well:
  `editor_widget_draw_text.zig` uses one small emitter seam for both immediate
  and draw-list text/decor emission, so editor-local styled text is no longer
  the main remaining blocker.
- the shared timing blocker is sharper too: ordinary UI/editor text still runs
  through immediate `text_runtime.zig` paths that mutate `text_render.bg_rgba`
  and emit texture draws immediately. Even editor draw-list flush ultimately
  resolves into that same immediate text path. So the remaining blocker is not
  just generic fills; it is that fills and their dependent text still do not
  share one backend-neutral phase boundary.
- sample pressure is specifically section-fill plus bg-aware text preview work
  in `font_sample_view.zig` / `font_sample_section_host.zig`, including the
  custom-font sample path that still terminates through direct texture draws
- that sample lane is slightly cleaner now because the section seam no longer
  depends on mutating `renderer.text_render.bg_rgba` globally just to make
  preview text honor section background. The background is now explicit at the
  sample draw site.
- that sample seam is now slightly stronger too: section labels/headers are
  recorded and replayed through the shared text phase host seam using the
  `.sample_section` group instead of inline per-call text emission.
- that seam is now observable too: present trace carries sample section group
  begin/end counts, and replay ordering is unit-tested at the sample phase
  host seam.

There is now a first proof of that narrower sample path too: the font sample
view has its own tiny section-composition seam. That is intentionally not a
general editor/ui band abstraction. Its value is only that the sample lane no
longer needs to be discussed as if it were the same problem as editor
segmentation.

That is the loudest remaining semantic contradiction in the backend contract.
It is no longer hidden by renderer-root facade noise or mixed backend dispatch
buckets, which means the next real cut must either:

- make that semantic split explicit as backend policy under one product-level
  record/submit contract
- or reduce the split directly without repeating the earlier broken "delay all
  GL surface draws" attempt

Any further structural cleanup that does not address that truth is secondary.

One important boundary is clearer now too: `SurfaceDraw` is no longer allowed
to quietly mean "generic draw anything." Recent terminal fixes proved that
terminal row backgrounds, cursor/composition cells, and other terminal-grid
semantics need their own dedicated seams when they depend on terminal batching
or per-cell ordering truth. The current contract should therefore be read as:

- `SurfaceDraw`: generic UI/image/presentable-style recorded draws
- terminal draw contracts: terminal-grid/cell batching truth
- presentable contract: retained/direct present lifecycle truth

If a caller needs tighter phase ordering than "preserved among recorded surface
draws inside the backend's surface phase," that caller is on the wrong seam.

That has improved slightly again on the terminal overlay side too: selection
fills, hover underlines, and rect-style cursor overlay pieces no longer use the
generic `drawRect(...)` / `drawRectF(...)` surface path. They now route through
the terminal rect path with an explicit overlay batch bracket, which is a
better fit for the truth that those draws are terminal-phase semantics, not
generic UI surface draws.

That has improved slightly again on the clip side too: clip dispatch now
terminates in dedicated backend runtimes (`gl_clip_runtime.zig` /
`metal_clip_runtime.zig`) instead of remaining one more inline backend-specific
 switch in the shared dispatch module. This is a small structural cleanup, but
 it helps isolate the real remaining backend contradiction: surface submission
 semantics still differ materially.

That has improved slightly again on backend ownership too: backend dispatch no
longer terminates presentable operations back into the large generic backend
files. Dedicated backend presentable modules now own that seam directly:

- `src/ui/renderer/gl_presentable_runtime.zig`
- `src/ui/renderer/metal_presentable_runtime.zig`

This is still not full presentable parity, but it is a more honest ownership
shape than keeping presentable lifecycle inline in `gl_backend.zig` and
`metal_backend.zig` as one more mixed concern.

That has improved slightly again on the scene-composition side too: the
offscreen scene-target contract/state now lives in a dedicated
`scene_target_state` module and is stored under `opengl_runtime.scene_target`
instead of as a direct renderer-root field. That makes the current OpenGL-owned
offscreen scene-target model less obviously shared-state-by-default.

That has improved slightly again at the renderer root too: the remaining
window-refresh / zoom invalidation merges for the OpenGL scene target now
route through `gl_backend`, and Metal atlas-preview lookup now routes through
`metal_backend`, so `Renderer` no longer directly reaches into those backend
runtime storage slots for those paths.

That has improved slightly again on the Metal-only helper surface too: unused
`app_shell` forwards for macOS Metal host prep, smoke frames, and atlas
diagnostics were **removed**, and atlas preview/upload probe entrypoints live on
`Renderer` rather than as Shell methods. Remaining Metal-only mechanics still
live under `metal_backend` / `macos_host` where appropriate, without duplicating
that surface on `app_shell`.

That has improved slightly again on the primitive draw/clip boundary too: the
renderer root no longer owns private Metal queue-assembly helpers for solid
rects or atlas samples, and it no longer owns the OpenGL scissor
implementation directly either. Primitive solid-rect submission, terminal
glyph/rect submission, and backend clip application now route through
`gl_backend.zig` / `metal_backend.zig` instead of `renderer.zig` acting as the
implementation center for those backend-specific mechanics.

That has improved slightly again on frame host bookkeeping too: the shared
frame prelude/epilogue state reset and submission finalization now live in
`renderer_frame_host.zig` instead of being duplicated between
`Renderer.beginFrame()` and both backend frame runtimes. This is real lifecycle
cleanup, but it is still only host-shape progress; backend frame assembly and
submission ownership remain materially different between OpenGL and Metal.

That has improved slightly again at the backend dispatch boundary too: the
GL/Metal backend ops table and switchboard now live in
`backend_dispatch.zig` instead of `renderer.zig` carrying the full backend
routing block inline. This makes the renderer root less obviously the dispatch
center, even though backend lifecycle ownership is still not closed.

That has improved slightly again on contract shape too: the backend switchboard
now reads as grouped `runtime`, `frame`, `presentable`, and `draw`
subcontracts instead of one flat `backend_ops` blob. This is still the same
dispatch center, but it makes the remaining contradictions more honest and
reduces the renderer-root “single backend god object” surface.

That has improved slightly again on renderer-root state honesty too: the
renderer no longer stores a separate `backend` label field when the selected
backend contract/runtime already carries that truth. This is small, but it
removes one more dead “backend enum on the root” relic from the shared host.

That has improved slightly again on draw-payload neutrality too: shared raw
image draws no longer carry a `.opengl` / `.metal` texture union in
`surface_draw.zig`. The payload now carries one opaque `GpuImageRef`
(`handle + width + height`), while backend-specific interpretation and
clone/release logic terminate inside `gl_backend.zig` / `metal_backend.zig`.
This does not finish the whole draw-submission contradiction, but it removes
one direct “future `.vulkan` arm” pressure point from the shared payload.

That has improved slightly again on the caller-facing image surface too:
persistent image upload/draw APIs used by kitty images and shell icons no
longer expose `types.Texture` as a public renderer contract. Those callers now
use `GpuImageRef` plus `drawPersistentImage(...)`, so the shared surface no
longer teaches product code that a persisted image is “really a GL texture
struct.”

That has improved slightly again on root-surface sprawl too: the old public
`Renderer.drawTexture(...)` method is gone. Texture drawing remains an internal
font/glyph/atlas primitive, but product-level callers no longer get a generic
GL-shaped texture draw verb by default.

That has improved slightly again on frame lifecycle termination too:
backend frame begin/submit and screenshot entrypoints now live directly on
`gl_backend.zig` / `metal_backend.zig`, and the old
`opengl_frame_runtime.zig` / `metal_frame_runtime.zig` wrappers are gone.
This is a real ownership improvement because per-backend frame mechanics now
terminate in the backend modules themselves instead of one more intermediate
runtime layer.

That has improved slightly again on the Metal helper surface too: queue and
cell/text append helpers that are now only used internally by
`metal_backend.zig` are no longer exported as public backend surface. That
reduces one more fake API layer where implementation-detail queue mechanics
looked like supported contract.

That has improved slightly again on the Metal draw path too: backend-internal
solid/atlas/raw-image queue helpers now append to Metal queue storage directly
instead of bouncing back through the shared `backend_ops.surface.recordSurfaceDraw`
surface as if they were neutral product-level callers.

That has improved slightly again on the caller-facing shared renderer surface
too: `Renderer` no longer exports `recordSurfaceDraw(...)` as a public method.
That does not solve the deeper submission-semantics split yet, but it removes
one more fake-neutral verb from the root surface seen by product code.

That has improved slightly again on the shared surface edge too: the common
surface-record helper for logical solid fills now lives in
`renderer_surface_host.zig` instead of `renderer.zig`, and terminal
presentation and other direct renderer callers now use that host seam
directly instead of keeping dedicated `Renderer.drawRect(...)` /
`Renderer.drawRectF(...)` facades alive. That is a more honest ownership
shape than leaving that backend-facing seam as one more private root helper.
The same is now true for rect outlines: `Shell` and other callers use
`renderer_surface_host.zig` directly instead of keeping `Renderer.drawRectOutline(...)`
alive as another root solid-fill convenience surface.
Clip lifecycle now follows the same ownership story too: `beginClip(...)` /
`endClip(...)` live in `renderer_clip_host.zig` and callers route there
directly instead of keeping clip-stack lifecycle as one more renderer-root
convenience surface over backend clip runtimes.

That has improved slightly again on root-surface sprawl too: dead convenience
capability verbs with no live callers are being removed from `Renderer`
instead of left behind as speculative shared API.

That has improved slightly again on the OpenGL lifecycle side too: the
OpenGL scene-target and presentable runtimes no longer call GL-only
render-target helpers through `Renderer`. They now talk to `gl_backend`
directly for render-target begin/ensure/destroy, which removes another
pure-OpenGL helper surface from the renderer root.

That has improved slightly again on the OpenGL target-binding side too: the
OpenGL frame, scene-target, and presentable runtimes now bind the default
target through `gl_backend` directly instead of going through one more
OpenGL-only helper on `Renderer`.

That has improved slightly again on the shared/widget side too: terminal
presentation debug sampling no longer reaches into
`renderer.opengl_runtime.presentable_targets.terminal` directly. It now asks
the renderer presentable contract for backend-neutral presentable info instead
of peeking into OpenGL-owned storage from shared terminal code.

That has improved slightly again at the renderer root itself: the live
renderer instance now selects one explicit backend ops table at init time and
routes frame, presentable, screenshot, capability, clip, and primitive draw
behavior through that table instead of repeating backend switches across the
root for each of those operations.

That has improved slightly again on the bootstrap side too: startup window
binding, startup backend configuration, and startup smoke execution now route
through a small backend bootstrap ops table instead of `renderer.zig`
carrying a separate cluster of ad hoc backend startup switches.

That has improved slightly again on dead contract cleanup too: the unused
renderer-root `deinitPresentables()` seam and its matching backend ops entry
are gone. Presentable teardown now only exists where it is actually needed, in
backend-owned runtime cleanup.

That has improved slightly again on the widget-side contract too: Kitty image
handling no longer decides between persistent GL textures and direct Metal raw
image draws by branching on `renderer.backend`. The renderer capability model
now publishes an explicit Kitty image mode, and the terminal Kitty widget
follows that contract instead of backend labels.

That has improved slightly again on the immediate-draw boundary too: Kitty
direct raw-image placement, terminal Metal text fallbacks, `text_runtime`
Metal fallbacks, font-sample Metal preview, and the macOS Metal text diagnostic
no longer import `metal_backend.zig` just to enqueue those draws. They call
`Renderer` methods wired through `BackendOps` instead, and OpenGL implements
those ops as honest no-ops.

That has improved slightly again on the persistent image-texture side too: the
renderer root no longer exposes `createTextureFromRgb` /
`createTextureFromRgba` as GL-only helper surfaces. Persistent texture
creation and destruction now route through backend ops, so shell icons and the
Kitty persistent-texture path ask the backend contract for a linear persistent
image texture instead of depending on a raw OpenGL-only renderer helper.

That has improved slightly again on the font-atlas hook seam too: font
initialization no longer first checks `renderer.backend != .metal` before
asking for Metal atlas upload hooks. The Metal backend helper now answers the
real question directly.

That has improved slightly again on shared init policy too: the old
OpenGL-only swap-interval policy tweak no longer lives as a raw
`renderer.backend == .opengl` branch in `renderer.zig`. That runtime policy
now routes through backend ops as backend-owned behavior instead of leaving one
more backend-special case in shared initialization.

That has improved slightly again on the Metal frame side too: the shared
frame prelude no longer clears the Metal queued draw list before backend
dispatch. That queue reset now lives under `metal_frame_runtime.zig`, which is
closer to the rule that shared frame entry should not directly mutate
backend-native runtime state.

### 2. Shared frame lifecycle still branches backend-by-backend

The renderer root no longer spells out backend frame begin/submit bodies, but
shared frame runtime code still decides whether a frame is OpenGL or Metal.

That is survivable for two backends, but it is not the shape that makes a
third backend feel routine.

This has improved slightly: the top-level frame seam is now split across:

- `src/ui/renderer.zig`
- `src/ui/renderer/opengl_frame_runtime.zig`
- `src/ui/renderer/metal_frame_runtime.zig`

So the renderer root no longer spells out the whole OpenGL and Metal frame
loops inline, and even the older scene-runtime wrapper role has been split out.

But there is still not a final backend lifecycle seam yet:

- the dispatch point still lives in shared frame runtime code
- shared lifecycle helpers still expose backend-specific state on `Renderer`
- the backend frame runtimes still operate on a renderer object that carries
  concrete backend state directly

- backend startup ownership is better, but still depends on backend modules
  mutating renderer-carried backend state directly rather than owning that
  runtime state behind a narrower lifecycle seam

This has improved slightly again: OpenGL-only scene target refresh/prep no
longer happens in a shared frame wrapper; that branch now lives under
`opengl_frame_runtime.zig`, which is closer to the contract we actually want.

That has improved slightly again: the remaining OpenGL scene-target mechanics
no longer live in `present_trace_runtime.zig`'s predecessor either. Scene-target contract
refresh, offscreen begin/draw, and recreate handling now live under
`gl_backend.zig`, leaving the shared scene runtime closer to shared
present-trace semantics instead of mixed shared/GL ownership.

This has improved slightly once more: the extra shared backend-frame dispatch
wrapper is gone. `Renderer.beginFrame()` / `Renderer.submitFrame()` now do the
small shared per-frame bookkeeping directly and route to backend-owned
`beginFrame` / `submitFrame` entrypoints on the OpenGL and Metal modules.

That has improved slightly again on the OpenGL submission path too: direct GL
submit and direct window screenshot-readback logic now live under the OpenGL
frame/backend modules instead of `present_trace_runtime.zig` carrying that
OpenGL-specific behavior inside a shared runtime file.

That has improved slightly again on the presentable lifecycle side too: the
terminal presentable end path no longer bypasses the shared presentable
contract just to call a shared scene-runtime restore helper. The restore logic
now lives under the OpenGL presentable implementation, and the widget-facing
terminal presenter ends presentables through the contract again.

That has improved slightly again at the renderer boundary too: the repeated
live-instance backend dispatch switches for frame/presentable/capability and
primitive operations are now gone from `renderer.zig`, replaced by one backend
ops table selected at renderer init. The remaining root-level backend
switching is now mostly ops-table selection and backend-profile gating rather
than per-call renderer behavior.

That has improved slightly again on teardown ownership too: OpenGL presentable
and scene-target cleanup no longer runs from `Renderer.deinit()` before backend
shutdown. That teardown now lives under `gl_backend.deinitRuntime()`, which is
closer to the contract we want.

### 3. The shared draw queue is still Metal-native

The shared renderer currently stores and submits
`metal_backend.SurfaceDraw`, which expands into:

- `AtlasSampleDraw`
- `RawImageDraw`
- `SolidColorDraw`

Those types live in `src/ui/renderer/metal_backend.zig`.

This has improved slightly: the draw payload types now live in
`src/ui/renderer/surface_draw.zig` instead of `metal_backend.zig`.

But the submission flow is still not fully shared yet:

- Metal is still the only backend consuming that draw union directly
- shared renderer helpers still expose Metal-shaped public verbs
- OpenGL does not yet participate in the same backend-neutral submission path

This is still one of the strongest contradictions against a future Vulkan
lane.

If Vulkan were added today, the easiest local move would still be to bolt a
third backend onto a shared renderer that already carries backend-native state
and lifecycle truth directly. That is exactly the failure mode this campaign is
supposed to prevent.

### 4. Retained/presentable surfaces are still GL-shaped in shared runtime code

The neutral presentable surface no longer lives in a separate shared runtime
wrapper. The small caller-facing facade now lives in
`src/ui/renderer/renderer_presentable_host.zig` instead of being spread between
another wrapper layer and the renderer root.

This has improved slightly: the presentable target type now lives in
`src/ui/renderer/gl_presentable_target.zig` instead of being owned directly by the
GL backend, so the module name reflects GL-shaped retained storage.

The shared runtime surface has improved too:

- the main shared retained-target API now uses presentable-oriented names
- callers no longer have to speak in GL-era `ensureSurface` /
  `beginSurface` / `drawSurface` vocabulary
- the shared presentable contract types now live in
  `src/ui/renderer/presentable_contract.zig`
- the OpenGL presentable mechanics now live directly in
  `src/ui/renderer/gl_backend.zig` instead of inside the shared presentable
  contract module or another backend-local wrapper
- the renderer-owned presentable facade now routes through backend-owned
  presentable entrypoints on the OpenGL and Metal modules
- presentable trace/editor-surface bookkeeping now also routes through
  `src/ui/renderer/renderer_presentable_host.zig` instead of GL and Metal
  each deciding that lifecycle bookkeeping inline
- GL and Metal presentable draw paths now also share one normalized draw
  resolution rule from `presentable_contract.zig` instead of each backend
  open-coding width/height/source fallback semantics
- shared presentable availability now resolves from `presentableInfo != null`
  instead of keeping a second backend-dispatched availability verb beside the
  existing info contract
- the Metal terminal snapshot presentable now also stores its logical surface
  size explicitly in backend state, so `presentableInfo()` no longer
  has to report full-window logical size as a fallback when the retained
  terminal surface is only a viewport-sized logical region
- the Metal terminal snapshot draw path now also treats
  `PresentableDraw.x/y` as destination placement only, matching the GL path
  instead of reusing those coordinates as implicit source crop offsets
- with editor retained presentation deleted from the shared contract, the dead
  one-value `PresentableSurface` argument is gone too. The live presentable API
  is now explicitly terminal-presentable instead of pretending to stay generic
  by forwarding `.terminal` through every layer.

But the presentable surface story is still not backend-neutral at the shared
runtime layer:

- the moved type is still FBO/texture-shaped
- OpenGL still owns the richer retained-presentable lifecycle
- Metal currently participates through a narrower direct/snapshot terminal
  presentable implementation rather than a broader presentable model

That is why OpenGL still reads like "the real retained implementation" while
Metal still reads like "the narrower direct/snapshot implementation" instead
of both being equally mature implementations of one presentable contract.

### 5. The caller-facing renderer surface is better, but still not fully neutral

The renderer root no longer carries the earlier Metal-only public helper verbs
for sampled text, terminal cell runs, raw image draws, and terminal snapshot
draws. Live callers now route those operations through `metal_backend`
directly instead of treating `Renderer` as the backend convenience surface.

That is a real improvement.

But the contract is still not finished because:

- those backend-owned entrypoints still only succeed on the Metal path today
- backend submission still does not run through one neutral lifecycle surface
- OpenGL still does not consume the same draw/present contract

## Concrete Evidence Centers

The main contradiction centers today are:

- `src/ui/renderer.zig`
  - backend-owned state is still stored directly on `Renderer`
  - shared runtime still leans on renderer-carried backend state
- `src/ui/renderer/metal_backend.zig`
  - owns a useful implementation surface, but is still the only backend
    consuming the shared surface-draw queue directly
- `src/ui/renderer/gl_backend.zig`
  - now owns more of the OpenGL runtime lifecycle, but shared renderer code
    still carries the OpenGL runtime state directly
- `src/ui/renderer/gl_backend.zig`
  - now also owns the actual GL presentable lifecycle directly instead of
    routing that behavior through a second backend-local wrapper module
- `src/ui/renderer/renderer_presentable_host.zig`
  - now owns the small neutral presentable facade, but presentable lifecycle
    truth is still not backend-neutral
- `src/ui/renderer/renderer_frame_host.zig`
  - now owns the small shared frame facade, but frame lifecycle ownership is
    still not fully backend-neutral
- `src/ui/renderer/backend_dispatch.zig`
  - now owns the backend switchboard, but backend lifecycle ownership is still
    not closed
- `src/ui/renderer/gl_backend.zig`
  - now owns OpenGL frame lifecycle directly, but the resulting lifecycle
    semantics are still not equivalent to Metal
- `src/ui/renderer/metal_backend.zig`
  - now owns Metal frame lifecycle directly, but the resulting lifecycle
    semantics are still not equivalent to OpenGL
- `src/ui/renderer/present_trace_runtime.zig`
  - now mostly trace/present bookkeeping, but is still part of the shared
    frame lifecycle surface
- `src/ui/renderer/gl_backend.zig`
  - now also owns the OpenGL scene-target mechanics directly instead of
    routing them through a second backend-local wrapper module

## First Required Cut Order

The next structural cuts should happen in this order:

### Cut 1. Shared surface draw contract

Define one backend-neutral draw payload in shared renderer/runtime code for:

- solid rect
- atlas sample
- raw image
- presentable blit

Then make both OpenGL and Metal consume that same contract.

Status, 2026-04-05:

- the shared payload types now exist in `src/ui/renderer/surface_draw.zig`
- the next required step is to make backend submission consume that contract
  without Metal-specific renderer verbs remaining as the practical API

### Cut 2. Shared presentable contract

Replace direct dependence on `gl_backend.RenderTarget` in shared runtime code
with one backend-neutral presentable target surface:

- ensure
- begin/end update
- draw presentable
- scroll/shift
- availability/reuse truth

Status, 2026-04-05:

- the presentable target type now lives in `src/ui/renderer/gl_presentable_target.zig`
- the shared runtime surface now exposes presentable-oriented API names
- the next required step is to move lifecycle behavior behind that ownership,
  not just the storage type

### Cut 3. Backend lifecycle dispatch seam

Move inline frame begin/submit logic out of `src/ui/renderer.zig` and behind a
backend-owned lifecycle surface so the renderer root stops being the place that
knows how each backend actually submits work.

Status, 2026-04-05:

- the inline begin/submit bodies now live in dedicated backend frame runtime
  modules
- the next required step is to reduce shared renderer ownership of the dispatch
  point and backend-native frame state itself

### Cut 4. Delete backend-specific public draw helpers from `Renderer`

Only after cuts 1 through 3 are real should the Metal-specific convenience
verbs disappear behind neutral renderer/backend contracts.

## Defect Class Note (2026-04-06)

One concrete class now confirmed by live behavior: stateful overlay
invalidation drift between backend present/reuse paths. The observed symptom was
stale terminal cursor presentation on Metal when fast snapshot-present reuse
skipped redraw even though cursor state changed. The structural fix now tracks
cursor/overlay state deltas in presentation cache/reuse decisions, but this
class should be treated as an explicit scrutiny target when comparing OpenGL
and Metal lifecycle equivalence after the current cut order is complete.

## Terminal Present Contract Status (2026-04-08)

The terminal-present contract lane has now crossed the main gate-2 transfer:

- shared code owns one terminal present transaction vocabulary
- shared code owns planning/invalidation truth
- retained update-cycle execution terminates behind
  `renderer_presentable_host.runRetainedTerminalPresentExecution(...)`
- direct/snapshot execution terminates behind
  `renderer_presentable_host.runDirectTerminalPresentExecution(...)`
- shared code still finalizes product outcomes from partial execution data

That means gate #2 is now mostly about validating and tightening this
contract, not about discovering another major direct-vs-retained ownership cut.

Validation status:

- OpenGL/Linux: behavioral equivalence validated across the defined
  adversarial seam-hardening cases
- Metal/macOS: still unverified against the new seam contract; this is
  deferred verification, not evidence that gate #2 remains structurally open

What remains in gate #2:

- keep shared finalization honest against the partial execution seam
- remove any leftover backend-shaped orchestration that survives only as local
  glue around the terminal-present seam
- keep GL/Metal behavior equivalent while the shared transaction remains the
  authority

What has moved into gate #5:

- broader frame/present/order ownership
- cross-widget frame lifecycle alignment
- any attempt to absorb shared terminal-present finalization into a larger
  renderer-wide frame contract

## Frame Outcome Ownership Status (2026-04-08)

The first gate-5 cut now exists too:

- shared frame lifecycle now uses one small frame-execution outcome surface
- OpenGL and Metal report begin/submit/abandon results through that surface
- `renderer_frame_host.zig` now finalizes frame bookkeeping from that shared
  outcome instead of taking raw backend success booleans

This is the right scope for `RB-B3.a`. It does not yet redesign broader
frame/present ordering, and it did not require backend-shaped schema growth to
get shared finalization off raw backend return values.

That next pressure is now cut too:

- `Renderer.beginFrame()` now returns shared frame-entry readiness instead of
  hiding it behind `void`
- Metal begin/acquire failure no longer silently runs the shared draw body
- shared draw/runtime can stop early and still flow through normal frame
  submission/finalization

This is the right scope for `RB-B3.b`. It still does not redesign broader
frame ordering, and it did not require a new generic frame transaction object
to make frame-entry readiness part of the shared contract.

The smallest remaining ordering leak after that cut was narrower than a new
host seam:

- `Renderer.beginFrame()` still reset backend clip state before shared code
  knew whether begin had produced a drawable frame

That follow-up is now fixed too. Initial clip reset now follows shared
frame-entry readiness instead of running unconditionally after backend begin.
So the current evidence does not yet force a larger unified begin/prelude host
seam; the next gate-5 move should wait for a stronger ordering leak.

One more product-level leak from the same seam is now fixed too:

- shared frame finalization was still clearing present-capture requests on
  `not_attempted` / `begin_failed` / `abandoned` outcomes where no drawable
  frame ever existed

Capture requests now stay armed across those no-drawable-frame outcomes and
clear only once a drawable frame actually reaches submit. That still fits the
current narrow frame-readiness/finalization surfaces; it does not yet force a
larger frame transaction redesign.

Inspection of failed-submit handling did not prove a larger gate-5 cut either.
The next honest correction there was only observability:

- present feedback no longer logs failed submissions as `frame_present`
- logging now records `frame_submission` with explicit submitted truth

So current evidence still does not justify opening `RB-B3.c`.

The current product-state rule on `submitted = false` is now explicit too:

- allowed to advance:
  - frame attempt sequence
  - observability trace rollover
  - last submission timing publication
  - composition-target reset
  - frame-execution state reset
- must remain pending:
  - submission sequence
  - terminal presentation retirement/ack
  - presented-generation feedback
- failure-class distinction:
  - `not_attempted` / `begin_failed` / `abandoned` keep present capture armed
  - `submit_failed` may clear present capture because a drawable frame did
    reach submit

That answer still fits the current readiness/outcome surfaces, so it does not
yet trigger `RB-B3.c`.

The current stop marker is now stronger too:

- focused `renderer_frame_host.zig` unit tests lock begin prelude reset,
  submission-sequence advancement, and capture preservation/clearing semantics
  across `submitted`, `begin_failed`, and `submit_failed`

So the present gate-5 policy is no longer just doc authority; it is regression
checked in code.

## Ranked Contradictions

### High

1. backend-native state still lives in shared renderer state
2. retained/presentable surface contract is still GL-shaped in shared code
3. frame lifecycle dispatch still happens in shared runtime code
4. caller-facing renderer verbs are now neutral in name, but not yet neutral in
   backend reach

### Medium

1. capability reporting still carries some implementation truth that should
   eventually fall out of stronger shared contracts
2. current docs and queues now point at the right campaign, but code still
   reflects the older "make Metal real first, contract later" execution order

### Low

1. doc language is improving, but some older renderer docs still describe
   modularization or platform progress rather than the stronger backend
   contract bar

## What Must Change Before Vulkan Feels Routine

1. move draw list ownership to backend-neutral types
2. move presentable/retained target ownership to backend-neutral types
3. move backend frame dispatch behind one backend-owned lifecycle seam
4. widen the neutral renderer verbs until both OpenGL and Metal can honestly
   sit behind the same submission surface
5. keep OpenGL and Metal as the proof pair while deleting shared-state leakage

## Current Proof Standard

The repo should treat OpenGL and Metal as the two reference implementations for
this work.

A renderer/backend change is only a real improvement if it makes both of them
look more like implementations of one contract, not more like special cases
hidden behind the same enum.
