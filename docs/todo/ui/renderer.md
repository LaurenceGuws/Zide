# Renderer Backend Contract Queue

This is the active execution queue for the renderer backend contract campaign.

Read this queue as the renderer version of a small ticket board:

- pick one active ticket
- read its owner docs
- satisfy its acceptance criteria
- update this queue and the owning docs
- stop drift into other lanes unless the ticket explicitly says to

## Campaign Goal

Architect and enforce a reference-grade renderer backend abstraction API.

The standard is:

- OpenGL on Linux is the current proving ground
- Metal on macOS remains the second reference implementation, even while live
  Metal validation is paused
- future Vulkan and Android/mobile work must fit the same contract instead of
  forcing renderer surgery later

The contract is only good enough when backend choice changes implementation,
not architecture.

## Non-Negotiable Rules

- Do not shape the contract around current OpenGL convenience.
- Do not add a real Vulkan implementation yet.
- Do not pivot to Android implementation work yet.
- Android native-host/platform design may advance, but Android rendering
  backend work is still gated by this queue.
- Do not let backend labels substitute for a contract.
- Do not treat Linux GL regressions as polish-only if they expose contract
  weakness.
- Do not keep stale duplicate seams just to avoid a clean cut.

## Pre-Android Rendering Gate

Android work now splits into two lanes:

- allowed now:
  - Android native-host/platform design
  - Activity / `ANativeWindow` lifecycle authority
  - IME, focus, clipboard, file intents, permissions, redraw-needed, resize,
    surface-loss truth
- not allowed yet:
  - real Android rendering backend bootstrap
  - GLES/Vulkan backend work that assumes the renderer contract is already
    stable

Reason:

- the current renderer still allows one semantic operation to travel through
  multiple render paths
- `Renderer` still owns too much backend/runtime shape
- frame/presentable/draw ownership is still not strict enough
- starting Android rendering now would either:
  - bend Android around desktop/GL-shaped seams
  - or reopen renderer surgery while trying to bootstrap mobile

Android rendering backend work only becomes valid when all of these are true:

1. one semantic operation has one renderer contract path
   - especially terminal/text/background/presentable drawing
2. backend choice no longer changes product-level submission semantics
3. shared draw/resource payloads do not want backend-specific `.opengl` /
   `.metal` / future `.vulkan` branches
4. `Renderer` is no longer the hidden owner of backend-native runtime state
5. presentable/frame ownership is honest enough that a new backend would feel
   routine rather than invasive

If those are not true, Android rendering is still blocked.

## How To Use This Queue

1. Confirm the repo-wide focus in `docs/AGENT_HANDOFF.md`.
2. Read the architecture authority:
   - `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
   - `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
3. Pick the top-most active ticket that is not blocked.
4. Read the ticket's linked owner docs before touching code.
5. Implement only that ticket's scope.
6. Update this queue:
   - status
   - evidence
   - new blockers or follow-up tickets
7. Validate locally.

If a task does not map cleanly to one ticket below, it is probably not the
current renderer priority.

## Review Cadence

This campaign should be executed as large but controlled chunks.

A weaker agent should not free-run across multiple milestones. It should stop
at the review gates below.

Review gate rule:

- complete one milestone chunk
- update this queue and the owning docs
- validate locally
- stop and ask for review

Do not continue into the next chunk until review feedback is incorporated or
explicit approval is given.

## Milestone / Review / PR Schedule

### Review Chunk 1: Linux Contract Stabilization

Tickets:

- `RB-A1` Focus and input truth
- `RB-A2` Scale and geometry truth
- `RB-A3` Terminal resize and scrollback truth

Expected output:

- Linux GL is boring enough to trust as contract evidence
- obvious focus, scale, redraw, and resize failures are no longer dominating
  the lane
- owner docs for Linux, geometry, and terminal resize are current

Required validation before review:

- `zig build`
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
- manual Linux smoke notes for:
  - workspace move / focus recovery
  - display-hop / fractional-scale behavior
  - repeated terminal resize / scrollback sanity

Stop marker:

- stop here and request review before opening Milestone B work

Suggested review title:

- `Renderer Contract Review 1: Linux stabilization`

### Review Chunk 2: Backend Contract Closure

Tickets:

- `RB-B1` Presentable ownership
- `RB-B2` Backend runtime ownership
- `RB-B3` Frame lifecycle ownership

Expected output:

- `Renderer` no longer reads like the hidden backend implementation center
- shared draw/present/frame seams are more honestly backend-neutral
- GL is not receiving privileged contract shape by default

Required validation before review:

- `zig build`
- `zig build test`
- `zig build check-app-imports`
- `zig build check-input-imports`
- `zig build check-editor-imports`
- one short written summary in this queue:
  - what ownership moved
  - what still remains renderer-root-owned
  - why the current cut is reviewable

Stop marker:

- stop here and request review before opening any Vulkan-fit work

Suggested review title:

- `Renderer Contract Review 2: backend closure`

### Review Chunk 3: Vulkan Fit Audit

Tickets:

- Milestone C only

Expected output:

- one explicit fit audit against the current contract
- no implementation drift into Vulkan code unless the audit says the fit is
  clean enough to proceed

**Delivered (2026-04-06):** `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md` — full audit with explicit
answers to: what can map to Vulkan mostly unchanged; ranked blockers; renderer seams that force
surgery; GL shaping vs neutral contract; Android/mobile aging. **Conclusion:** fit is **not** clean
enough for “routine” Vulkan without further backend-closure work; see audit for ordered blockers
before bootstrap.

**Entry note:** This chunk was executed **explicitly** as Review Chunk 3 while Milestone B remains
incomplete. The audit treats that as **honest risk**, not as approval to skip Chunk 2 continuation.

Required validation before review:

- updated contract docs
- updated renderer queue
- explicit written answer to:
  - what Vulkan would implement unchanged
  - what still blocks Vulkan from being routine

Stop marker:

- stop here and request review before any Vulkan bootstrap code

Suggested review title:

- `Renderer Contract Review 3: Vulkan fit audit`

### Review Chunk 4: First Vulkan Bootstrap

Entry rule:

- only open this chunk after approval from Review Chunk 3

Expected output:

- first minimal Vulkan bootstrap proving the contract is real
- no renderer-root architecture relapse

Required validation before review:

- `zig build`
- targeted Vulkan bootstrap validation notes
- queue + architecture docs updated with what the bootstrap proved

Suggested review title:

- `Renderer Contract Review 4: Vulkan bootstrap`

## Review Handoff Format

When a weaker agent reaches a review gate, it should report in this shape:

1. Review chunk name
2. Tickets completed
3. Files changed
4. Validation run
5. Remaining risks
6. Exact questions for review

Example:

- review chunk: `Renderer Contract Review 1: Linux stabilization`
- tickets: `RB-A1`, `RB-A2`, `RB-A3`
- validation: `zig build`, `zig build test`, import checks, Linux smoke
- risks: resize reflow still suspicious under extreme width churn
- review request: confirm contract direction and identify architecture leaks

## Weak-Agent Guardrails

If you are using a weaker agent for this lane:

- assign exactly one review chunk at a time
- do not ask it to "finish the renderer contract" in one pass
- require the review handoff format above
- reject work that spans Linux stabilization and backend closure in one
  uncontrolled diff
- reject any chunk that adds Vulkan or Android implementation work early
- require small coherent commits on the feature branch during the chunk
- do not allow commits on `main`
- only accept changes onto `main` after the chunk review is complete

## Current Milestone Map

1. Milestone A: Linux contract stabilization
2. Milestone B: backend contract closure
3. Milestone C: Vulkan fit audit
4. Milestone D: first Vulkan bootstrap only if the fit audit is honestly clean

## Milestone A: Linux Contract Stabilization

Purpose:

- use Linux GL as pressure against weak contract seams
- stabilize the host, geometry, and terminal interactions that still expose
  bad ownership splits

Exit bar:

- focus/input truth is boring and reliable
- scale/display-hop behavior is correct without rituals
- terminal resize/scrollback behavior is correct under repeated resize stress
- Linux GL no longer hides obvious renderer-contract contradictions behind
  "works on my machine"

### `RB-A1` Focus and input truth

Status: completed (Review Chunk 1 — pending human validation on Linux)

Why this matters:

- if focus visuals and keyboard truth drift apart, the renderer/host/input
  contract is still wrong

Owner docs:

- `docs/todo/linux/implementation.md`
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

Scope:

- window focus gain/loss truth
- text input activation truth
- workspace move / display move churn
- modifier-state recovery after compositor shortcuts

Acceptance criteria:

- keyboard input recovers correctly after workspace moves
- visual focus and keyboard focus agree
- no "spam click until it wakes up" behavior remains
- diagnostics show one coherent focus/input state story

Do not do:

- do not bury host bugs under renderer-only hacks if the host contract is the
  real owner
- do not classify keyboard-loss bugs as terminal-only if SDL/window/input truth
  is implicated

### `RB-A2` Scale and geometry truth

Status: completed (Review Chunk 1 — pending human validation on Linux)

Why this matters:

- wrong scale behavior proves we still have multiple competing geometry
  authorities

Owner docs:

- `docs/todo/ui/window_scale_geometry.md`
- `app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md`

Scope:

- startup scale truth
- display-hop refresh
- cursor scale
- pane-to-grid fit
- fractional-scale snapping consistency

Acceptance criteria:

- initial scale is correct on non-1.0 displays
- moving between displays preserves correct scale and cursor behavior
- terminal fit policy is stable and deliberate
- fractional-scale rendering artifacts are reduced to acceptable residuals

Do not do:

- do not let GL-specific coordinate behavior define the public geometry model
- do not add one-off monitor hacks without documenting the owning seam

### `RB-A3` Terminal resize and scrollback truth

Status: completed (Review Chunk 1 — pending human validation on Linux)

Why this matters:

- resize bugs are a product failure and also evidence that terminal geometry,
  publication, and presentable ownership are still split badly

Owner docs:

- `docs/todo/terminal/widget_scrutiny.md`
- `docs/todo/terminal/vt_core_rearchitecture.md`

Supporting owner docs:

- `docs/todo/ui/window_scale_geometry.md`
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`

Scope:

- resize reflow
- viewport preservation
- scrollback truth after repeated resize
- retained-present invalidation under resize

Acceptance criteria:

- scrollback remains coherent after width and height changes
- view anchoring is predictable under resize
- retained/direct presentation does not leak stale geometry

Do not do:

- do not dismiss this ticket as "integration polish"
- do not patch presentation artifacts while leaving reflow truth undefined

## Milestone B: Backend Contract Closure

Purpose:

- turn the current partly-neutral renderer into a real backend-neutral host
- stop `Renderer` from being the hidden backend implementation center

Exit bar:

- presentable ownership is backend-neutral in reality, not only in naming
- backend runtime state is backend-owned
- frame lifecycle ownership terminates behind backend seams
- adding a future backend no longer implies reopening `renderer.zig` as the
  implementation center

### `RB-B1` Presentable ownership

Status: active

Current evidence:

- the renderer-owned presentable facade methods now live in
  `renderer_presentable_host.zig` instead of `renderer.zig` directly.
- this removes another small renderer-root ownership seam from the shared
  presentable contract surface.
- the renderer root no longer exports `beginPresentable(...)` /
  `endPresentable(...)` as if they were stable product verbs.
- widget/view callers that actually perform retained-surface updates now talk
  to `renderer_presentable_host.zig` directly for that lifecycle edge.
- this is more honest than keeping those lifecycle forwards on `Renderer`,
  because `begin/end` are not equally meaningful across backends today.
- the remaining root presentable forwards (`ensure`, `available`, `draw`,
  `scroll`, `info`) are now gone too.
- widgets/diagnostics that actually use the presentable seam now talk to
  `renderer_presentable_host.zig` directly instead of bouncing through
  `Renderer` first.
- this makes the ownership boundary plainer: `Renderer` no longer pretends to
  own a presentable facade while `renderer_presentable_host.zig` and the
  backend presentable modules do the real work.
- persistent-image/raw-image draw/resource verbs now also route through a
  dedicated shared host seam:
  - `src/ui/renderer/renderer_draw_host.zig`
- kitty images, shell icons, and the font sample no longer depend on
  `Renderer` methods for that surface.
- this removes another fake renderer-root facade from the draw/resource lane
  without inventing a second contract; the grouped draw contract was already
  the real owner.
- even the remaining root theme-background clear forward is now gone; the font
  sample uses `renderer_draw_host.zig` directly instead of asking `Renderer`
  to proxy one more draw-contract verb.
- terminal rect/glyph submission now also routes through a dedicated host seam:
  - `src/ui/renderer/renderer_terminal_draw_host.zig`
- terminal grid/presentation/text code no longer depends on public
  `Renderer.addTerminalRect(...)` / `addTerminalGlyphRect(...)` /
  `addTerminalGlyphQuad(...)` methods.
- this keeps the terminal draw contract on one explicit host seam instead of
  leaving another renderer-root facade in front of backend draw ops.
- the grouped backend draw bucket has now been split further too:
  - `clip`
  - `terminal_draw`
  - `image_draw`
  - `surface`
- that is more honest than one `backend_ops.draw` grab bag mixing clip state,
  terminal primitives, persistent images, raw images, and surface submission.
- the old backend `clearThemeBackground` hook is now gone entirely.
- it was only one leftover convenience op for the font sample, and normal
  `drawRect(...)` semantics are the right path instead of preserving a
  special clear contract for one caller.
- the `surface` contract now terminates in dedicated backend modules too:
  - `src/ui/renderer/gl_surface_runtime.zig`
  - `src/ui/renderer/metal_surface_runtime.zig`
- that does not solve the remaining GL-immediate vs Metal-queued semantic
  split by itself, but it makes the ownership seam honest instead of burying
  surface submission inside the large backend files.
- the main remaining blocker is now explicit:
  - OpenGL `surface` submission still means "interpret now"
  - Metal `surface` submission still means "append now, replay at submit"
- that is not a naming issue anymore; it is the loudest remaining contract
  contradiction in Milestone B.
- no further structural cleanup should pretend this is solved until backend
  choice stops changing the product-level meaning of `surface` submission.
- `clip` dispatch now terminates in dedicated backend runtimes too:
  - `src/ui/renderer/gl_clip_runtime.zig`
  - `src/ui/renderer/metal_clip_runtime.zig`
- that removes one more tiny backend-specific inline dispatch seam from the
  switchboard, leaving the surface semantic split as the louder remaining
  contradiction.
- presentable trace/editor-surface bookkeeping now also lives in
  `renderer_presentable_host.zig` instead of being split across GL and Metal
  presentable lifecycle methods.
- this is a real ownership improvement because the shared presentable facade
  now owns when presentable update/draw/end bookkeeping happens, instead of
  each backend inlining its own trace semantics.
- terminal presentable update lifecycle is now a host-owned operation too: the
  terminal widget no longer calls `beginPresentable(...)` /
  `endPresentable(...)` directly, and instead asks `renderer_presentable_host`
  to run one presentable update cycle.
- OpenGL presentable operations now resolve retained-target storage through
  backend-owned slot helpers instead of open-coding terminal/editor target
  access at each call site.
- This is small but useful ownership pressure: presentable storage reads are
  becoming less ad hoc even before the broader presentable lifecycle is
  fully re-cut.
- backend dispatch now terminates presentable operations in dedicated backend
  presentable modules:
  - `src/ui/renderer/gl_presentable_runtime.zig`
  - `src/ui/renderer/metal_presentable_runtime.zig`
- that is more honest than keeping presentable lifecycle inline in
  `gl_backend.zig` / `metal_backend.zig`, because it makes presentable
  ownership a first-class backend lane instead of a sidecar on the general
  backend modules.
- GL and Metal presentable draw paths now consume one shared draw-resolution
  helper from `presentable_contract.zig` instead of each backend open-coding
  width/height/source fallback semantics.
- shared presentable availability now resolves from `presentableInfo != null`
  instead of keeping a second backend-dispatched availability verb beside the
  existing info contract.
- Metal terminal snapshot presentables now also store their logical surface
  size explicitly in backend state, so `presentableInfo()` stops
  falling back to full-window logical size when the retained terminal surface
  is only a viewport-sized logical region.
- Metal terminal snapshot presentables now also treat `PresentableDraw.x/y` as
  destination placement only, matching the GL path instead of incorrectly
  reusing destination coordinates as source crop offsets during raw-image
  replay.
- presentable contract cleanup: once editor retained presentation was removed,
  the dead one-value `PresentableSurface` parameter was removed too. Terminal
  presentable APIs now say exactly what they are instead of forwarding
  `.terminal` through every host/backend layer.

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Primary code pressure:

- `src/ui/renderer.zig`
- `src/ui/renderer/presentable_contract.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`

Acceptance criteria:

- shared code talks to one honest presentable contract
- retained/direct/snapshot behavior does not leak GL-shaped assumptions into
  shared runtime
- Metal and GL both satisfy the same presentable vocabulary

Do not do:

- do not rename GL-owned concepts to neutral names without changing ownership

### `RB-B2` Backend runtime ownership

Status: active

Current evidence:
- `Renderer` now carries one `backend_runtime` bundle instead of separate
  `opengl_runtime` and `metal_runtime` peer fields.
- backend-facing dispatch and backend-native runtime are now grouped under one
  dedicated `backend` host on `Renderer` instead of remaining two separate
  peer root fields (`backend_ops` and `backend_runtime`).
- Metal queue ownership is now slightly narrower too: both
  `queued_presentable_draws` and `queued_surface_draws` live under Metal
  backend context instead of as separate shared runtime-state lists beside the
  backend context/frame slots.
- that is not closure, but it is a real ownership improvement: the two active
  Metal lifecycle queues are now owned by backend context state instead of
  widening the shared renderer-hosted runtime bundle.
- the live Metal frame slot now follows that same rule too: it lives under
  backend context instead of as a separate shared runtime field.
- that keeps Metal acquire/submit/abandon state with the backend-owned
  lifecycle model it actually belongs to.
- This is good host-shape cleanup and reduces one obvious renderer-root
  duplication seam.
- This is not closure yet:
  - backend host storage is still renderer-root-owned
  - backend-specific mutation/storage truth still lives in shared process
    memory shaped by the renderer host
  - adding a backend still pressures this shared storage story

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Acceptance criteria:

- `Renderer` stops carrying backend-native implementation bundles as its real
  center of gravity
- backend-specific state mutations terminate behind backend-owned surfaces

Do not do:

- do not add new backend-native peer fields on `Renderer`
- do not solve "quickly" by widening shared state

### `RB-B3` Frame lifecycle ownership

Status: active

Current evidence:

- shared frame prelude/epilogue host bookkeeping now lives in
  `renderer_frame_host.zig` instead of being split between `Renderer.beginFrame`
  and backend frame paths.
- backend dispatch table assembly now lives in `backend_dispatch.zig` instead
  of `renderer.zig` carrying the full GL/Metal switchboard inline.
- that switchboard is now grouped into `runtime`, `frame`, `presentable`, and
  `draw` subcontracts instead of one flat `backend_ops` blob, which makes the
  remaining ownership seams more explicit and reduces the renderer-root
  “backend god object” shape.
- backend frame begin/submit and screenshot entrypoints now terminate in
  `gl_backend.zig` / `metal_backend.zig` directly; the separate
  `opengl_frame_runtime.zig` / `metal_frame_runtime.zig` wrappers are gone.
- Metal queue/text/cell append helpers that are now backend-internal no longer
  remain exported as fake backend-facing API surface.
- Metal backend-internal queue helpers now append directly to Metal queue
  storage instead of routing back through the shared dispatch surface.
- the renderer root no longer exports `recordSurfaceDraw(...)` as a public
  method; that fake-neutral draw verb is now internal renderer machinery
  instead of part of the caller-facing shared surface.
- the shared surface-record helper for logical solid fills now lives in
  `renderer_surface_host.zig` instead of `renderer.zig`, which is a better
  ownership fit for that backend-facing seam.
- terminal presentation and other direct renderer callers now use that host
  seam directly instead of keeping dedicated `Renderer.drawRect(...)` /
  `Renderer.drawRectF(...)` surfaces alive for generic solid fills.
- rect outlines now follow that same rule through `renderer_surface_host.zig`
  instead of keeping `Renderer.drawRectOutline(...)` alive as another root
  convenience wrapper over the same solid-fill seam.
- generic shell-level solid/outline wrappers are now gone too:
  app/widget callers that still need generic fills now terminate in
  `renderer_surface_host.zig` directly instead of bouncing through
  `Shell.drawRect(...)` / `Shell.drawRectOutline(...)`.
- clip lifecycle now follows the same rule through `renderer_clip_host.zig`
  instead of keeping `beginClip(...)` / `endClip(...)` as renderer-root
  convenience surfaces over already-owned backend clip runtimes.
- contract authority now pins the next hard rule for `SurfaceDraw`:
  shared code may assume order only relative to other recorded surface draws
  inside the backend's surface phase, not exact interleaving with terminal or
  presentable lifecycle work.
- contract authority now also pins caller triage:
  `SurfaceDraw` is for generic UI/image/presentable-style draws, not terminal
  grid/cursor/composition work that already needs dedicated seams.
- terminal overlay rect semantics now follow that rule too:
  selection, hover underline, and rect-style cursor overlay pieces no longer
  use generic `drawRect` / `drawRectF`; they route through the terminal rect
  path with their own overlay batch bracket.
- dead renderer-root capability convenience verbs with no callers are being
  deleted instead of preserved as speculative API surface.
- the renderer root no longer stores a dead backend label field when backend
  truth already lives in the selected contract/runtime.
- shared raw-image draw payloads now use one opaque `GpuImageRef` handle
  instead of a `.opengl` / `.metal` texture union.
- backend-specific clone/release/interpretation now terminates in backend
  modules instead of the shared draw contract encoding backend branches in the
  payload itself.
- public persistent-image APIs used by kitty images and shell icons now also
  speak `GpuImageRef` plus `drawPersistentImage(...)` instead of exposing
  `types.Texture` as a public renderer contract.
- the old public `Renderer.drawTexture(...)` surface is gone; texture drawing
  is now internal renderer/font machinery unless a caller is explicitly using
  the persistent-image contract.
- shared text draw entrypoints no longer hang off `Renderer` as thin forwards
  to `text_runtime`. Shell/UI/editor callers now route through
  `renderer_text_host.zig`, which matches the earlier clip/surface/presentable
  host cuts and removes another fake renderer-root facade.
- the generic `SurfaceDraw` payload is no longer exported from `renderer.zig`,
  and `renderer_surface_host.recordSurfaceDraw(...)` is now host-private. That
  narrows the misuse surface so product code cannot quietly treat generic
  `SurfaceDraw` construction as a normal public rendering API again.
- the remaining `SurfaceDraw` producer set is now intentionally narrow:
  generic UI/editor/shell fills, presentable/snapshot blits, and raw image /
  atlas samples that already fit the shared payload model. The live blocker is
  no longer caller sprawl; it is the backend surface-phase split itself
  (GL executes surface phase immediately, Metal replays it at submit).
- terminal pane / viewport fills have now been peeled off that generic lane.
  They route through the presentable seam as terminal presentable backdrop
  work, and Metal replays them in a dedicated presentable-composition queue
  after terminal snapshot capture.
- the exact blocker is now named: many remaining `SurfaceDraw.solid` calls are
  local background layers immediately followed by text/outline work at the same
  call site. A broad "defer all GL surface draws to submit" cut would still
  paint those backgrounds over later immediate text.
- backend code now also distinguishes surface-phase fills from surface-phase
  blits internally. That is not a semantic fix yet, but it is the first code
  seam that matches the real blocker and gives us a narrower target than
  "delay everything."
- that split did **not** produce a broadly safe delayed-blit lane yet:
  kitty/raw-image placements still interleave with terminal text, and shell
  icons still draw before adjacent tab labels. The only relatively isolated
  blit family is retained presentable draw, which already belongs under the
  presentable contract and is too narrow to close `SurfaceDraw` timing on its
  own.
- the remaining solid-ordering dependency is now mapped into concrete families,
  not hand-waved as one giant queue problem:
  shell chrome bands, editor banding, and sample/diagnostic sections. Terminal
  pane/presentable fills are no longer in the generic surface lane. The next
  semantic cut should target one family or a stronger shared phase for that
  family, not "all remaining solids."
- shell chrome is the most obvious next family, but it is blocked from an easy
  cut because its dependent text/icon path is still immediate in
  `text_runtime.zig`. A fill-only move would recreate the same separation bug
  at the band level. Any real shell-chrome cut now needs a stronger
  fill-plus-text phase or a genuinely narrower subset.
- narrower shell-chrome subset audit: no free lane found yet. Config reload
  notice, close-confirm UI, and caption buttons still mix fills with immediate
  text and/or immediate outline/icon primitives at the same call site.
- next design direction is now explicit: introduce a shell/UI chrome
  band-composition seam that owns fill + dependent text/icon/outline ordering
  as one product-level unit. Keep first scope narrow: status bar, tab bar,
  shared top bar, side nav, then nearby notice/confirm/chrome surfaces if they
  fit the same contract.
- first adopter checkpoint: a narrow widget-side chrome band host now exists
  and status bar/tab bar/shared top bar/side nav plus the config-reload notice
  route through it. This is a seam sketch, not a solved backend phase.
- nearby modal/card surfaces such as terminal close confirm do not fit this
  seam and should stay outside it unless a separate popup/modal contract is
  introduced.
- sample/diagnostic pressure is narrower too: `font_sample_view.zig` no longer
  borrows the editor presentable seam. It now stays on a direct diagnostic
  path.
- editor widget draw is now equally honest: the dead retained/direct branch in
  `editor_widget_draw.zig` is gone, so the live widget path is direct-only.
- presentable checkpoint: the dead shared `.editor` presentable surface is
  gone too. The live shared presentable contract is terminal-only again; if
  editor retained presentation returns later, it must come back as a reviewed
  lane instead of a dormant branch inside the generic presentable contract.
- presentable ownership checkpoint: terminal presentable update lifecycle now
  terminates in `renderer_presentable_host.zig`, so the terminal widget no
  longer sequences backend `begin/end` primitives directly.
- naming checkpoint: the host seam now says `terminalPresentable*` explicitly
  instead of generic `presentable*` names. That keeps the API aligned with the
  current truth that the live shared presentable lane is terminal-only.
- retained-update checkpoint: the shared backend dispatch no longer exports
  `beginPresentable(...)` / `endPresentable(...)` as first-class contract
  verbs.
- that pair was still a fake lifecycle leak from the GL retained-target model.
  The live shared seam now says what the product actually asks for:
  "attempt one retained terminal presentable update cycle."
- OpenGL still implements that by opening a retained target, running the body,
  and restoring composition target state.
- Metal still reports that no retained update cycle exists and relies on its
  snapshot-plus-composition path instead.
- this does not solve the remaining lifecycle-model mismatch, but it removes
  another false claim that `begin/end` were a backend-neutral vocabulary.
- OpenGL presentable target slot access now also routes through `gl_backend`
  helpers instead of `gl_presentable_runtime.zig` reaching directly into
  `renderer.backend.runtime.opengl.presentable_targets`.
- remaining presentable blocker is now sharper: OpenGL still owns a real
  retained update target, while Metal still owns a terminal snapshot plus
  composition replay queue. The API is cleaner, but the lifecycle model is
  still materially uneven.
- ownership checkpoint: the seam has graduated out of `widgets/` into
  `renderer_chrome_band_host.zig`. That is the right host-level home for it,
  even though it is still only a local composition seam and not a backend phase.
- renderer-host checkpoint: the seam now terminates directly in renderer
  surface/text hosts instead of routing back through `Shell` wrapper verbs.
- stop rule: do not keep widening this seam unless it becomes a real recorded
  band-composition phase. More adopters without that phase cut would be fake
  progress.
- with shell chrome carved out behind the chrome-band seam, the loudest
  remaining generic `SurfaceDraw` ordering family is now editor banding and
  editor-adjacent overlay work. Sample/diagnostic sections are still active,
  but they are the narrower secondary lane now.
- those are not one shape: editor already has a local row/segment composition
  lane, while sample/diagnostic section banding is simpler explicit fill-plus-
  text work. Do not force them under one seam without proving it.
- code-facing checkpoint: the editor pressure is now specifically the
  row-band/gutter/current-line fills in `editor_widget_draw.zig` that still
  neighbor immediate text/overlay work in the direct/fallback path.
- editor checkpoint: the direct/fallback segment base painting is now
  centralized through one helper in `segment_paint.zig` instead of staying as
  scattered immediate rect calls inside `editor_widget_draw.zig`.
- editor checkpoint: pane-level editor background + gutter clears now also run
  through one explicit helper in `segment_paint.zig` instead of sitting as
  stray generic surface calls in the widget draw entrypoints.
- editor checkpoint: the fallback line-base path is now one explicit immediate
  helper too, instead of a hybrid path where base fills were immediate but the
  line-number/current-line label still rode a one-op draw-list flush.
- editor checkpoint: the cached/list-side segment base painting now follows the
  same rule through one `segment_paint.zig` helper instead of open-coding its
  own row/gutter/current-line rect sequence in `editor_widget_draw.zig`.
- that is not timing closure, but it makes the remaining editor-family
  ordering dependency easier to change honestly.
- editor rule checkpoint: the next valid cut is not more helper cleanup. One
  editor row-band composition unit still needs to own base fills, line number
  label, selection/search overlays, text runs, and cursor/caret decoration as
  one local ordering story.
- editor proof checkpoint: the fallback path now executes one explicit
  immediate row-band composition helper in `segment_paint.zig`.
- editor proof checkpoint: the cached/list path now executes one explicit
  draw-list row-band composition helper in `segment_paint.zig` too, instead of
  spelling that band payload out inline in `editor_widget_draw.zig`.
- that is stronger proof of the intended editor-local composition rule, but it
  is still not full shared timing closure because the immediate and draw-list
  row-band lanes remain distinct concrete implementations.
- editor boundary checkpoint: two remaining editor visuals should stay outside
  the row-band contract unless their owning interaction model changes:
  - IME/composition text and underline are cursor-anchored widget interaction
    overlays, not per-row-band content
  - scrollbars are pane-level final overlays and intentionally render after the
    row-band/content path
- that means the remaining editor timing pressure is now mostly row-band local
  ordering itself, not those two overlay families.
- editor audit checkpoint: the next loud editor-local split is now in styled
  text/decorations, not pane scaffolding:
  - fallback path still resolves highlighted text + underline/undercurl/
    strikethrough through direct text/decor paths in
    `editor_widget_draw_text.zig`
  - cached/list path resolves the same semantics through draw-list text/rect
    ops there
- that is the next honest editor-family seam if we keep pushing this lane.
- editor checkpoint: highlighted-token traversal in
  `editor_widget_draw_text.zig` now runs through one shared helper for both
  immediate and draw-list paths.
- that does not unify the emitters yet, but it removes one duplicated
  traversal/order policy and leaves the remaining split at the emission layer
  instead of the token-walk layer.
- editor checkpoint: text-decoration geometry in
  `editor_widget_draw_text.zig` now also runs through one shared helper for
  both immediate and draw-list paths.
- underline / undercurl / strikethrough now differ mainly by emitter target,
  not by separate geometry policy.
- editor checkpoint: expanded styled-text run splitting for tabs/wide glyph
  spans now also runs through one shared helper in
  `editor_widget_draw_text.zig`.
- the remaining editor styled-text split is now increasingly just the final
  immediate-vs-draw-list emission target.
- editor stop rule checkpoint: do not keep grinding local helper cleanup past
  this point unless a cut removes the final emitter-target split itself or
  changes the real `SurfaceDraw` timing story.
- backend-runtime checkpoint: the remaining runtime-storage blocker is now more
  specifically OpenGL-shaped than Metal-shaped. Metal live frame/queue state is
  under backend context.
- OpenGL checkpoint: retained presentable target slots and offscreen
  scene-target lifecycle now live under one explicit
  `opengl_runtime_state.TargetRuntime` stratum instead of being flat peers of
  context/shader/VBO state.
- OpenGL checkpoint: GL shader/VBO/text resource ownership now lives under one
  explicit `opengl_runtime_state.ResourceRuntime` stratum too, separate from
  both context ownership and retained-target lifecycle.
- that is a real ownership narrowing. The remaining OpenGL runtime shape is now
  three explicit backend-native strata instead of one blob:
  - SDL GL context ownership
  - GL shader/VBO/text resource ownership
  - retained target / scene-target lifecycle
- that is still not runtime closure, but the next GL runtime cut now has to be
  a genuinely semantic one, not a first-pass storage disentangling.
- presentable checkpoint: OpenGL presentable runtime no longer keeps an
  internal `beginPresentable/endPresentable` split behind the shared retained
  update-cycle contract. It now exposes one `updateRetainedPresentable(...)`
  verb directly, which is the honest shape the shared contract already names.
- presentable checkpoint: the Metal side no longer hides its lack of retained
  update-cycle semantics as an inline false stub in backend dispatch. That
  "no retained update cycle here" result now lives in
  `metal_presentable_runtime.zig` itself.
- presentable checkpoint: the shared terminal presentable host no longer
  compresses "retained update ran", "retained update unavailable", and
  "backend has no retained update model" into one boolean result.
- OpenGL now returns `.updated` or `.unavailable` from the retained-update
  seam; Metal returns `.unsupported`.
- terminal presentation runtime now tracks that explicit retained-update status
  instead of treating every non-true outcome as the same backend-neutral case.
- presentable checkpoint: terminal presentable lifecycle model is now explicit
  in the shared host seam too:
  - OpenGL: `.retained_update_target`
  - Metal: `.snapshot_composition`
- the terminal runtime no longer attempts a retained update cycle on snapshot
  backends just to learn that the answer is "not here."
- presentable ownership checkpoint: terminal widget code no longer asks the
  renderer root whether terminal presentation is "direct" or what mode it is.
  That decision now lives in `renderer_presentable_host.zig` with the rest of
  the terminal presentable seam.
- code-facing checkpoint: the sample pressure is specifically
  section-fill-plus-bg-aware preview text in `font_sample_view.zig`, including
  custom-font preview draws that still go through direct texture draw calls.
- sample checkpoint: the font-sample section seam no longer depends on
  mutating `renderer.text_render.bg_rgba` globally just to make preview text
  honor the section background. That background is now carried explicitly at
  the sample draw site.
- this is good local honesty for the sample lane, but it does not yet turn the
  sample family into a recorded backend-neutral phase.
- first sample-side proof is acceptable only as a tiny section-composition seam,
  not as a new generic band layer.
- This is real lifecycle cleanup and removes another renderer-root duplication
  seam.
- This is not closure yet:
  - backend frame assembly is still materially different between OpenGL and
    Metal
  - submission ownership still terminates in backend-specific frame runtimes
  - `Renderer` still remains the dispatch center through `backend_ops`

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Acceptance criteria:

- prepare/begin/submit/abandon semantics read like backend-neutral lifecycle
- shared runtime does not remain the hidden backend dispatch center

Do not do:

- do not keep backend-specific frame assembly inline in shared runtime merely
  because the wrapper names became cleaner

## Milestone C: Vulkan Fit Audit

Purpose:

- prove the contract is strong enough before any Vulkan code exists

Status: **audit complete (evidence doc); bootstrap not approved on this audit alone**

- Primary artifact: `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md`
- Outcome: the contract is **not** yet strong enough that Vulkan would be routine
  backend-only work; top blockers are unified surface-draw submission, handle
  neutrality in draw payloads, presentable parity, and backend storage ownership
  (see audit table). **Chunk 2 continuation** should be sharpened using this audit
  before Review Chunk 4.

Entry rule (historical):

- intended: do not open this lane until `RB-B1` through `RB-B3` are honestly stronger
- **Review Chunk 3** was run as an explicit assignment to produce evidence while
  Milestone B is still open; the audit records that gap honestly.

Acceptance criteria:

- the audit can describe a Vulkan backend in terms of existing contract seams
- no new `Renderer`-owned Vulkan state is required by the proposed fit
- no widget/runtime layer needs Vulkan-specific knowledge

**Audit result vs criteria:** The audit **does** describe Vulkan in terms of existing
seams *and* names where **today’s code** would still force `Renderer`-centric
changes and shared forks. A honest fit is **not** proven yet; criteria are **not**
fully satisfied for proceeding to bootstrap without further closure work.

## Adoption Gate

Current explicit answer to "what still stands between us and Vulkan/Android
rendering adoption?":

- `SurfaceDraw` semantics are still not one honest product-level story
- presentable parity/ownership is still not neutral enough
- backend runtime storage still widens under shared renderer ownership, even
  though direct runtime-state reaches are now confined to backend-owned modules
- the remaining loud ordering families are now editor banding and
  sample/diagnostic sections
- the shared presentable contract is terminal-only; editor retained
  presentation is no longer a dormant shared seam and would need a deliberate
  reviewed reintroduction
- editor width/layout truth was still partly derived from full-window geometry
  instead of the editor pane; that had to be corrected before retained editor
  presentation can be trusted again

This means:

- Vulkan adoption is still blocked by backend-contract closure, not by lack of
  a third backend module skeleton
- Android rendering adoption is blocked by the same contract truth; mobile
  pressure does not get a separate shortcut

Do not rerank back to "just start Vulkan" or "just start Android rendering"
until these four lines are materially stronger in code and authority docs.

## Milestone D: Android and Mobile Pressure

Purpose:

- keep mobile in view without letting it derail the current contract campaign

Status: deferred

Owner docs:

- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`

Rules:

- Android is a future pressure target, not an active implementation lane
- mobile work must validate that the renderer contract is not desktop-GL-shaped
- do not let today's Linux GL convenience bias tomorrow's Android/mobile story

## Current Evidence Snapshot

- **Vulkan fit audit (2026-04-06):** `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md` — verdict: **not**
  routine Vulkan yet; dual GL/Metal submission semantics, renderer-hosted backend bundles, and
  presentable/draw parity gaps are the named blockers. Use as input for Chunk 2 continuation, not
  as permission to skip closure work.
- Review Chunk 1 (2026-04-06): initial window focus/text-input activation now follows SDL on the
  first poll (`InputRuntimeState.window_focused` default false; terminal `FocusUiState` defaults
  aligned). Geometry-only display-metrics merge no longer preserves an all-zero scale/density
  snapshot when the host had not yet reported real display coupling (fractional/Wayland startup).
  Deferred terminal grid resize now invalidates retained presentation caches so resize/reflow does
  not reuse stale presenter geometry.
- Linux GL is now the primary proving ground for contract quality.
- Metal remains a reference implementation even though live validation is
  paused.
- recent Linux work proved that focus, scale, redraw, and terminal presentation
  bugs were contract evidence, not just polish.
- terminal background styling bug (Neovim/Yazi highlight-heavy UI, 2026-04-07)
  proved a sharper Milestone B point: one semantic operation still had two
  render paths. Row backgrounds were resolved correctly in widget logic but
  traveled through generic `SurfaceDraw` via `addTerminalRectF(...)`, while
  normal terminal cell backgrounds/glyphs used the dedicated terminal rect/glyph
  batch path. Fixing the bug required moving row backgrounds onto the terminal
  rect path, not changing widget color decisions.
- follow-up closure after that bug: the dead `addTerminalRectF(...)` API was
  removed so terminal background drawing no longer advertises two public paths.
- follow-up closure after that seam review: terminal overlay/cursor/composition
  rendering now uses the same batched terminal cell path as the grid, and the
  old immediate terminal-cell API was removed as dead duplication rather than
  preserved as a second public route.
- next closure after that: composition overlay no longer carries a Metal-only
  row fallback route; it uses the same per-cell batched terminal path as the
  rest of overlay rendering instead of advertising a second backend-specific
  policy.
- next closure after that: the grid-side Metal row-run fallback and its
  matching diagnostics were removed too. Metal unavailable-text rendering now
  relies on the same per-cell terminal fallback path instead of carrying a
  second row-aggregation implementation with separate telemetry.
- the next meaningful wins should reduce shared renderer ownership, not add
  another backend.

## When To Rerank

Rerank this queue only if one of these becomes true:

- Milestone A exit criteria are satisfied
- a blocker proves Milestone B is the real prerequisite
- user direction explicitly changes the campaign

Do not rerank just because another backend sounds exciting.
