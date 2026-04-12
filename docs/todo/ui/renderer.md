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

Current priority note:

- this queue is no longer the repo-wide identity by default
- Android terminal excellence is the active product goal
- execute renderer tickets from this queue when, and only when, they are the
  next highest-leverage blocker for Android terminal progress

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
- **Do not widen Android GLES into a broad backend sprint until the controlled
  `AR-B4` stop markers are met.** Gate readiness allows the narrow Android GLES
  lane now; it does not allow speculative Vulkan work, duplicate bootstrap
  paths, or backend breadth by inertia.
- Do not pivot to Android rendering implementation yet.
- Android native-host/platform work may advance, but Android rendering backend
  work is still gated by this queue.
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

### Gate checklist (code truth, 2026-04-08)

Aligned with `app_architecture/ui/RENDER_BACKEND_CONTRACT.md` § “Gate status
(code truth)”:

| # | Criterion | Status |
|---|-----------|--------|
| 1 | One semantic operation → one renderer contract path | **Met** — `SurfaceDraw` deferral unified GL/Metal; flush discipline enforced at `drawTextureRect`, `flushTerminalBatch`, `GlyphCache.flush`; `updateRetainedPresentable` flushes surface queue into retained FBO before restoring scene target (fixes kitty-above ordering). No immediate-draw bypass remains. |
| 2 | Backend choice does not change product-level submission semantics | **Structurally met on GL** — terminal-present transaction/execution seams are in place and GL behavioral equivalence passed adversarial cases; Metal is still unverified against the new seam contract and remains deferred verification rather than a structural blocker. |
| 3 | No backend-specific `.opengl` / `.metal` / `.vulkan` in shared **draw payloads** | **Met for `SurfaceDraw`** — `GpuImageRef` + neutral union; `Renderer` still dispatches by backend enum elsewhere. |
| 4 | `Renderer` not the hidden owner of backend-native runtime | **Met** — selected runtime storage is opaque, only the selected backend runtime is materialized, runtime storage init/deinit now routes through backend runtime ops, shared code no longer reaches directly into backend dispatch/runtime internals, and backend-host construction is centralized in `renderer_backend_host.zig`. The renderer-owned backend host is now the one sanctioned owner surface rather than a widening runtime-storage pattern. |
| 5 | Presentable/frame routine for a new backend | **Structurally met for scanned composition families** — chrome, terminal overlays, editor row/overlay, tooltips, and sample sections now have explicit owners. The remaining presentable lifecycle split is tracked under gate #2 / Metal parity, not generic composition-family ownership. |

**Readiness:** Android **platform** work (lifecycle, IME, etc.) stays allowed.
Android **GLES rendering** is open for a first controlled backend slice, not a
full backend sprint. Desktop Vulkan and Android Vulkan remain not ready.

**Branch scope (2026-04-09):** Gate #2 is structurally closed on GL and gate
#4 is now structurally met. Gate #5 remains paused unless a stronger
ordering/ownership leak appears again. The non-terminal frame-family adopter
lane under `RB-B3.c` is now structurally complete for `chrome_band`,
`editor_row_band`, and `sample_section`. That means Android rendering is still
blocked, but not by backend-runtime ownership anymore. The remaining contract
blockers are:

- gate #2: Metal still needs live verification against the terminal-present
  transaction seam
- gate #5: presentable/frame routine is still not neutral enough for a new
  backend to feel routine, even though shared frame feedback is no longer
  terminal-only across the planned non-terminal family adopters

Current strongest Android renderer pressure:

- execute the first controlled Android GLES backend cut against the existing
  shared contracts
- keep it narrow enough that any remaining renderer-contract weakness is found
  before a broad backend sprint starts
- `AR-B4.a` is the current Android-side slice:
  Android GLES backend skeleton and frame binding
- owner: `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`

Android note:

- Android may continue with bootstrap-owned EGL/GLES binding authority and
  terminal-host-local proof work
- the first shared renderer backend skeleton is now allowed and in progress
- that does not authorize a second parallel renderer path or a premature
  product handoff before the shared backend owns real EGL/context/surface truth
- `AR-B4.b` is now met:
  Android terminal-host can create a shared external-host `Renderer`,
  execute shared Android GLES clear/swap on-device, and load the bridge without
  SDL runtime leakage
- `AR-B4.c` is now met:
  first Android GLES `SurfaceDraw.solid` replay
- terminal-host product layout now exposes the renderer surface as the main
  content host at real device size
- `AR-B4.d` is now met:
  Android GLES minimal terminal rect/glyph rendering is visible on-device
- `AR-B4.e` is now met:
  live shell product ownership is on the shared Android renderer path, the
  Java transcript is no longer present in product view while that path is
  active, and readable atlas glyph replay is visible on-device through the
  shared Android GLES path
- `AR-B4.f` is now met:
  the live shell now sizes from the real product surface instead of a fixed
  bootstrap `80x24` grid island
- `AR-B4.g` is now met:
  IME-aware live viewport sizing is now live on the shared Android GLES path
- Android renderer/backend work should now reopen only if a concrete product
  blocker proves the shared path still lacks required capability

Gate #3 remains met for the `SurfaceDraw` surface. Do not reopen gate #4
without new ownership pressure that proves the sanctioned backend-host surface
is no longer honest.

Current `RB-B3.e` checkpoint:

- shared terminal widget runtime no longer owns the direct-surface versus
  retained-surface execution branch for terminal presentation
- that execution split now terminates in
  `src/ui/renderer/renderer_presentable_host.zig`
- the remaining blocker is therefore narrower:
  backend-owned mechanics still differ, but shared widget/runtime flow no
  longer branches on a separate terminal-present path enum directly
- the shared capability question is also slightly cleaner now:
  widget/runtime asks for incremental presentable update support instead of a
  backend-shaped "direct partial update" concept
- widget/runtime also now keeps its own sync-update reuse policy locally
  instead of asking the presentable host to blend backend truth with widget
  policy state
- the behavior-level parity gap is narrower too:
  Metal now satisfies the shared terminal presentable refresh seam
  structurally instead of reporting refresh as unsupported by definition
- refresh-capable backends now also use the active shared refresh execution
  path instead of treating refresh as a retained-only route

Current blocker reading after `RB-B3.e` progress:

- the surviving terminal presentation sample labels are now primarily
  debug/reporting surfaces, not shared product control flow
- that means the remaining pressure is no longer generic terminal-presentable
  parity wording cleanup
- the honest remaining blocker is:
  live reference verification of the Metal refresh-backed snapshot path, plus
  the stronger shared renderer pressure already recorded in
  `RENDER_BACKEND_CURRENT_STATE.md` around text/surface phase boundaries

Next active ticket:

- text/surface phase-boundary follow-up
- owner:
  `app_architecture/ui/BAND_COMPOSITION_PHASE_PLAN.md`
  `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Current checkpoint:

- `RB-B3.f` shell/UI chrome-band composition is met
- `RB-B3.g` terminal overlay/progress composition is met
- `RB-B3.h` editor row/overlay composition is met
- `RB-B3.i` sample/diagnostic section composition check is met
- `AR-B4.g` IME-aware shared Android GLES viewport sizing is met
- the strongest remaining renderer pressure is now narrower than those landed
  slices:
  fills and their dependent text/icon work still do not share one
  backend-neutral phase boundary consistently enough that a new backend would
  feel routine

Next renderer move:

- `RB-B3.j` editor overlay phase-boundary closure is met
- closure truth:
  `editor_widget_draw_overlay.zig` is now the explicit owner seam for editor
  row-band local ordering; non-owner files no longer spell immediate
  begin/end/flush choreography or direct surface-queue drains for that family
- editor text-emitter follow-up is also now met enough:
  highlighted text / decoration traversal now shares one generic emitter-driven
  path, and the remaining emitter structs are just accepted side-effect
  adapters
- IME composition overlay ownership is now in too:
  `editor_widget_draw.zig` no longer draws the cursor-anchored IME composition
  preview directly; composing text + underline now terminate in
  `editor_widget_draw_overlay.drawImeCompositionPreview(...)`
- next stronger blocker:
  return to the broader renderer contract pressure already named in current
  authority:
  fills are deferred while ordinary UI/editor dependent text still resolves
  through immediate `text_runtime.zig` paths that mutate shared
  `renderer.text_render.bg_rgba` state and emit texture draws immediately, so
  fill-plus-text work still lacks one backend-neutral phase boundary
- current checkpoint:
  first cut is now in:
  non-terminal text paths in `text_runtime.zig` no longer mutate ambient
  `renderer.text_render.bg_rgba` before drawing; they carry background through
  a local text draw context into the texture draw thunk instead.
  second cut is now in too:
  terminal-grid / terminal glyph batching no longer mutates ambient
  `renderer.text_render.bg_rgba`; terminal glyph quad submission now carries
  cell background explicitly through the terminal draw host/backend seam.
  Remaining pressure is no longer ambient bg mutation; it is the smaller set
  of legacy renderer thunks and GL surface-phase replay paths that still read
  ambient bg instead of taking explicit background data.
- next honest blocker:
  `SurfaceDraw.atlas` / `SurfaceDraw.raw_image` replay and a few legacy
  renderer texture thunks still depend on ambient background reads. The next
  cut should either carry bg explicitly through those payloads/thunks or prove
  that those reads are dead enough to remove.
- current read-side checkpoint:
  `SurfaceDraw.atlas` and `SurfaceDraw.raw_image` now carry explicit
  `bg_rgba`; GL surface-phase replay uses that payload field instead of
  reading `renderer.text_render.bg_rgba`. Remaining ambient bg reads are now
  limited to legacy renderer-local texture thunks in `renderer.zig`.
- closure checkpoint:
  the legacy renderer-local texture thunks were dead and are removed, and
  `Renderer.TextRenderState.bg_rgba` no longer exists. Remaining `bg_rgba`
  references are explicit payload/context fields. The ambient
  text/background-state blocker is closed.
- next presentable checkpoint:
  terminal presentable refresh now receives the full `TerminalPresentPlan`
  instead of only an erased update body. Metal snapshot refresh uses
  `plan.surface_geometry.logical_width/height` for presentable logical size
  instead of overwriting that state with drawable pixel dimensions during
  refresh. GL ignores the plan for retained-target refresh because its retained
  target already owns logical size.
  Metal `presentableInfo()` also no longer falls back to full-window logical
  dimensions if no terminal logical size was recorded.
- do not reopen Android backend work unless that audit proves a new concrete
  renderer-owned Android blocker

Gate-4 closure note:

- shared font/text/surface/vertex-stream helper access now routes through
  dedicated backend-host files instead of generic shared files importing
  backend modules directly
- selected runtime storage is opaque and selected-backend-only
- runtime storage init/deinit now routes through backend runtime ops
- shared code no longer reaches directly into `renderer.backend.ops` /
  `renderer.backend.kind`
- `renderer_backend_host.zig` is now the sanctioned owner surface for backend
  selection, dispatch, and opaque runtime storage

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

- only open this chunk after approval from Review Chunk 3 **and** honest closure
  of Milestone B (`RB-B1`–`RB-B3`) against its exit bar—a fit audit alone is not
  enough to open implementation

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

Milestone B "done" checkpoints (execute in order, do not rerank mid-lane):

- [x] **B-DONE-1: freeze seam target contract**
  - add one explicit "text phase group" target contract in authority docs:
    producer shape, replay shape, ordering guarantees, and non-goals
  - name accepted local producers for closure (`chrome band`, `sample section`,
    `editor row-band`) and prohibit new ad-hoc producers
- [x] **B-DONE-2: unify local phase hosts under one replay contract**
  - make chrome/sample replay hosts implement the same typed replay/group
    surface instead of parallel host-specific function sets
  - keep behavior identical (no paint-order changes) while contract shape
    converges
- [x] **B-DONE-3: adopt unified contract in editor row-band lane**
  - move editor row-band dependent text emission onto the same group/replay seam
    with explicit row-band boundaries
  - preserve existing editor visual ordering and cursor behavior
- [x] **B-DONE-4: delete duplicate local seams**
  - remove superseded seam-specific helpers once all three producers are on the
    shared contract (legacy band/sample replay wrappers and
    duplicate record/replay adapters)
  - no compatibility shims left behind
- [x] **B-DONE-5: close observability parity**
  - standardize trace metrics for phase groups (begin/end counts and mismatch
    detection) under one naming family
  - keep runtime warning guardrails for begin/end divergence
- [x] **B-DONE-6: lock regression coverage**
  - unit tests for empty/non-empty group replay, op order, bg payload propagation
    on the unified host seam
  - focused widget-level smoke checks for chrome, sample, and editor row-band
    paths
- [x] **B-DONE-7: remove stale API surface**
  - delete public or quasi-public verbs that still expose old split semantics
    after migration (renderer/shell helpers that bypass unified phase seam)
  - verify no product caller remains on retired paths
- [x] **B-DONE-8: close docs and adoption gate**
  - update contract/current-state/todo docs to mark Milestone B closure deltas
    with concrete evidence
  - restate Adoption Gate blockers after this closure so next lane is explicit

### `RB-B1` Presentable ownership

Status: structurally complete on GL; Metal verification deferred

Current evidence:

- shared frame lifecycle now uses one small frame-execution outcome surface
  instead of passing raw backend success booleans into
  `renderer_frame_host.finishFrameSubmission(...)`
- that surface currently carries only:
  - `not_attempted`
  - `begin_failed`
  - `abandoned`
  - `submitted`
  - `submit_failed`
- OpenGL and Metal both report through that same surface
- `renderer_frame_host.zig` now finalizes submission bookkeeping from the
  shared outcome instead of backend-shaped raw success/failure truth
- this is good first proof for `RB-B3.a`: shared finalization did not require
  extra backend flags or frame-ordering policy to become honest

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
- dedicated `gl_surface_runtime` / `metal_surface_runtime` modules keep surface
  submission out of the giant backend files; **OpenGL `SurfaceDraw` is now
  fully deferred** like Metal at the product level (flush + submit replay).
- remaining surface work is **composition**: call sites that bypass
  `renderer_text_host` after recording surface draws must flush on OpenGL, and
  atlas/raw-image ordering around terminal/chrome still needs phase discipline.
- `clip` dispatch now terminates in dedicated backend runtimes too:
  - `src/ui/renderer/gl_clip_runtime.zig`
  - `src/ui/renderer/metal_clip_runtime.zig`
- that removes one more tiny backend-specific inline dispatch seam from the
  switchboard. (The old GL-immediate `.solid` fork is closed; presentable and blit
  ordering remain the louder gaps.)
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
- the shared presentable contract no longer exports a backend lifecycle query
  either; terminal presentation now attempts the retained update-cycle seam
  directly and branches on `.updated` / `.unavailable` / `.unsupported`
  instead of asking whether the backend is "retained" first.
- direct-vs-retained terminal present choice is now presentable-owned too:
  `renderer_presentable_host` resolves that path from backend presentable ops
  instead of deriving it from `RendererCapabilities.terminal_presentation_mode`.
- `renderer_presentable_host` no longer proxies
  `RendererCapabilities.terminal_presentation_mode` for draw metrics either;
  that diagnostic capability read now comes from `Renderer` directly.
- terminal workspace tab activation now synchronizes `ui_focused` across all
  terminal widgets instead of only invalidating the new active widget. This
  fixes focused-cursor state sticking to the old tab until a window-focus
  event forces a refresh.
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
- terminal presentation now routes through one explicit shared transaction
  vocabulary too: `TerminalPresentPlan` / `TerminalPresentResult` exist in
  presentable-contract space instead of keeping fast-present / update /
  present inputs as branch-local runtime plumbing.
- shared terminal plan construction no longer decides `present_intent` from
  backend identity. Reuse intent now comes from product truth
  (presentable-ready state, invalidation causes, generation match, viewport
  shift, sync-update state), and the fast-present path consumes that shared
  plan instead of re-deriving cursor/overlay/composition reuse inputs
  locally.
- this is the first real `RB-B1.c` normalization checkpoint: plan intent is
  now product-owned, while backend execution still decides how to satisfy that
  intent underneath.
- non-reuse execution now also lifts `planUpdate(...)` out of the deeper
  direct-partial / retained helpers and into the hook layer, so the chosen
  execution path consumes one shared update-plan build before entering its
  backend-shaped body.
- retained update-cycle execution now terminates at
  `renderer_presentable_host.runRetainedTerminalPresentExecution(...)`
  instead of being open-coded directly in widget runtime.
- direct/snapshot execution now also terminates at
  `renderer_presentable_host.runDirectTerminalPresentExecution(...)`
  instead of keeping partial-vs-full direct orchestration open-coded in
  widget runtime.
- this is intentionally narrower than full `RB-B1.d` closure: shared code
  still owns retained present-state bookkeeping and final retained
  present/unavailable handling, and shared code still finalizes product
  outcomes from partial execution data.
- guardrail for the next Metal move: backend execution seams still return
  partial execution data, not a fully resolved `TerminalPresentResult`.
  Shared code continues to finalize cache-state advance, present-state
  bookkeeping, unavailable logging, and final result assembly unless a wider
  seam proves product-level semantics rather than backend mechanics.
- both retained and direct/snapshot execution now terminate behind
  presentable-host execution seams. The remaining `RB-B1` work is mostly
  tightening shared finalization/orchestration honesty and re-auditing the
  gate boundary, not discovering another major direct-vs-retained ownership
  transfer.
- shared reuse-present finalization now also routes its direct-vs-retained
  note choice through `renderer_presentable_host` instead of interpreting
  backend mode inline in widget runtime.

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `app_architecture/ui/FRAME_SUBMISSION_OUTCOME_OWNERSHIP_PLAN.md`
- `app_architecture/ui/TERMINAL_PRESENT_TRANSACTION_PLAN.md`

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

Stop marker reached:

- shared terminal transaction vocabulary exists and is the authority
- retained/direct execution now terminate behind presentable-host execution
  seams instead of widget-owned execution trees
- GL behavioral equivalence passed the defined adversarial seam-hardening cases
- Metal remains unverified against the new seam contract and should be treated
  as deferred verification, not as a reason to reopen gate #2 extraction work

Remaining gate-2 work:

- drift prevention only
- treat future Metal regressions here as contract violations to fix, not as a
  reason to relabel the lane as structurally incomplete

Follow-on redesign authority:

- `app_architecture/ui/TERMINAL_PRESENT_TRANSACTION_PLAN.md`

### `RB-B2` Backend runtime ownership

Status: structurally complete

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
- current code pressure narrowed enough to close the structural gate:
  - shared code no longer meaningfully reads `renderer.backend.runtime`
    outside backend modules
  - selected runtime storage is opaque and selected-backend-only
  - runtime storage init/deinit is backend-owned in practice
  - `renderer_backend_host.zig` is now the one sanctioned owner surface for
    backend selection, dispatch, and opaque runtime storage
- Android host/bootstrap truth forced the audit, but the conclusion is now the
  opposite of the older assumption:
  - Android rendering is no longer blocked on `RB-B2`
  - reopening this lane now would require new ownership pressure, not just the
    existence of a renderer-owned backend host field

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `app_architecture/ui/BACKEND_RUNTIME_OWNERSHIP_PLAN.md`

Acceptance criteria:

- `Renderer` stops carrying backend-native implementation bundles as its real
  center of gravity
- backend-specific state mutations terminate behind backend-owned surfaces

Do not do:

- do not add new backend-native peer fields on `Renderer`
- do not solve "quickly" by widening shared state

Latest reviewable cut:

- `RB-B2.a` Selected backend runtime ownership

Purpose:

- replace the widening `backend_runtime_bundle.Bundle` shape so `Renderer`
  stops materializing concrete GL and Metal runtime state side-by-side

Owner docs:

- `app_architecture/ui/BACKEND_RUNTIME_OWNERSHIP_PLAN.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Primary code pressure:

- `src/ui/renderer/renderer_backend_host.zig`
- `src/ui/renderer/backend_runtime_bundle.zig`
- `src/ui/renderer/backend_dispatch.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/ui/renderer.zig`

Acceptance criteria:

- `Renderer.backend` no longer materializes both backend runtime structs at
  once
- shared code still triggers runtime lifecycle, but backend code owns concrete
  runtime storage init/deinit/mutation
- the first cut does not widen into frame ordering, presentable lifecycle, or
  third-backend bootstrap

Do not do:

- do not invent a larger generic backend object framework than this pressure
  actually needs
- do not reopen gate-5 frame/present redesign while addressing runtime storage

Stop marker:

- one selected-backend runtime storage surface replaces the widening bundle
- GL and Metal behavior stays unchanged
- queue/docs clearly state what later gate-4 pressure still remains

Current checkpoint:

- `backend_runtime_bundle.Bundle` now stores only the selected backend runtime
  instead of concrete GL and Metal state side-by-side
- selected concrete backend runtime is no longer embedded inline on `Renderer`
- GL and Metal backend modules now reach runtime storage through
  selected-backend accessors
- Metal optional helper paths now return neutral results on non-Metal selected
  runtime instead of panicking through selected-runtime assertions
- build/test validation stayed green with no intended behavior change
- gate 4 is now structurally complete:
  - `Renderer` no longer owns a widening or backend-tagged runtime-storage
    surface
  - selected runtime storage is opaque and selected-backend-only
  - selected runtime storage lifecycle now routes through backend runtime ops
  - shared code terminates at `renderer_backend_host.zig` instead of reaching
    backend dispatch/runtime internals directly
  - the renderer-owned backend host is now accepted as the one sanctioned
    owner surface, and pointer-wrapping or heap-owning it would be indirection
    theater rather than a real contract improvement

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
  no longer caller sprawl; it is the backend surface-phase split itself.
  surface-phase truth now:
  - OpenGL queues **all** `SurfaceDraw` variants (including `.solid`) and replays
    at `flushQueuedSurfaceDrawsNow` (wired through `renderer_text_host` and
    explicit widget boundaries) plus `submitFrame`
  - Metal remains submit-time replay for the surface queue
- terminal pane / viewport fills have now been peeled off that generic lane.
  They route through the presentable seam as terminal presentable backdrop
  work, and Metal replays them in a dedicated presentable-composition queue
  after terminal snapshot capture.
- the remaining discipline is **flush boundaries**: call sites that record
  surface work then draw through `draw_ops` / `text_draw` without the text host
  must call `flushQueuedSurfaceDrawsBeforeDependentSurfaceWork` on OpenGL (or
  route through `renderer_text_host`).
- backend code now also distinguishes surface-phase fills from surface-phase
  blits internally. That is not a semantic fix yet, but it is the first code
  seam that matches the real blocker and gives us a narrower target than
  "delay everything."
- observability: present trace emits `gl_surface_solid_enqueue` and
  `gl_surface_queued_replay` per frame on OpenGL.
- **GL editor + deferral (validated):** with all `SurfaceDraw` deferred on
  OpenGL, pane base must replay immediately after record; row-band batches must
  end with a queue drain; scrollbars must flush before later widgets. Landed on
  branch `surface-contract-shared-text-phase` with manual editor/IDE smoke OK.
- **Gate 1 flush discipline — closed (2026-04-08):** `draw_ops.drawTextureRect`
  (non-replay), `flushTerminalBatch`, and `GlyphCache.flush` call
  `gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork`; surface **replay**
  uses `drawTextureRectImmediate` to avoid re-entrancy. Additionally,
  `gl_presentable_runtime::updateRetainedPresentable` now calls
  `gl_backend.flushQueuedSurfaceDrawsNow` at body-end before
  `restoreCompositionTarget` fires — this flushes kitty-above and any other
  deferred `SurfaceDraw`s into the retained FBO while it is still bound, instead
  of letting them leak to the scene target and be covered by the presentable blit.
  No remaining call site allows an immediate GL draw to jump ahead of a queued
  `SurfaceDraw`. Gate 1 status updated to **Met**.
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
- editor checkpoint: expanded unstyled text run splitting for selection/bg text
  slices now also runs through one shared helper there.
- editor checkpoint: the final immediate-vs-draw-list emitter split is now
  gone too; `editor_widget_draw_text.zig` uses one small emitter seam for both
  text and decoration emission.
- editor stop rule checkpoint: do not keep grinding local editor text helper
  cleanup past this point. The next renderer-quality move is back on the
  shared timing contract.
- shared timing checkpoint: ordinary UI/editor text is still immediate in
  `text_runtime.zig`
  - text draw paths still mutate `text_render.bg_rgba`
  - then emit texture draws immediately
  - editor draw-list flush ultimately resolves back into that same immediate
    text path
- that means the remaining blocker is not "some fills are still generic". It
  is that generic fills and their dependent text still do not share one
  backend-neutral phase boundary.
- chrome-band checkpoint: `renderer_chrome_band_host` now uses bg-aware text
  and icon-text entrypoints by default for band labels/icons. This improves
  local seam honesty but is still not recorded text/surface phase closure.
- chrome-band checkpoint: band text/icon calls are now queued and flushed
  explicitly at band end (`Band.flush()`), so local chrome ordering is no
  longer only implicit immediate call order.
- chrome-band checkpoint: `Band.flush()` now runs through explicit renderer-host
  group boundaries (`beginBandCommandGroup` / `endBandCommandGroup`) as a
  no-op consumption unit for future shared phase wiring.
- chrome-band checkpoint: band text op storage moved from a fixed-size local
  array to dynamic list storage, removing the "overflow falls back to immediate
  draw" branch from this seam.
- chrome-band checkpoint: `Band.flush()` replay is owned by the shared
  `renderer_text_phase_group_host` seam (via `.chrome_band` group replay).
- chrome-band test checkpoint: replay-group semantics are unit-tested in the
  shared `renderer_text_phase_group_host` seam (group wrapping, op order).
- chrome-band trace checkpoint: present trace records band command-group
  boundaries (`band_group_begin_count` / `band_group_end_count`) from the
  shared text phase host group contract.
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
- presentable checkpoint: shared code no longer carries a backend lifecycle
  enum query for that seam at all.
- the terminal runtime now attempts the retained update-cycle contract
  directly and receives `.updated`, `.unavailable`, or `.unsupported`.
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
- sample checkpoint: section text in `font_sample_view.zig` records through
  `font_sample_section_host` and flushes via the shared
  `renderer_text_phase_group_host` (`.sample_section` group), preserving the
  tiny sample seam while removing seam-specific replay wrappers.
- sample checkpoint: sample-section group boundaries are now visible in present
  trace (`sample_section_group_begin_count` /
  `sample_section_group_end_count`) and replay order/bg payload handling is now
  covered by unit tests in `renderer_text_phase_group_host`.
- closure checkpoint (`B-DONE-2`): chrome-band and sample-section replay now
  share one typed host contract surface in
  `renderer_text_phase_group_host.zig`.
- closure checkpoint (`B-DONE-4`): seam-specific replay adapters are now
  deleted; chrome and sample call the shared text phase host contract directly.
- editor checkpoint (`B-DONE-3`): both draw-list and immediate/fallback
  row-band lanes now use explicit `.editor_row_band` group boundaries through
  the shared text phase host seam, with begin/end trace counters and mismatch
  warnings.
- closure checkpoint (`B-DONE-5`): phase-group observability now follows one
  naming family across chrome/sample/editor (`*_group_begin_count`,
  `*_group_end_count`, `*_group_mismatch`) with frame-present warning
  guardrails kept enabled.
- closure checkpoint (`B-DONE-6`): unified host seam tests now explicitly cover
  empty/non-empty replay, op kind ordering, bg payload propagation, and editor
  row-band group-kind forwarding in `renderer_text_phase_group_host`.
- closure checkpoint (`B-DONE-7`): stale quasi-public helper surfaces that
  bypassed the unified seam were reduced (`flushDrawList` internalized; test-
  only replay helper no longer exported), and no product callers remain on
  retired chrome/sample adapter paths.
- closure checkpoint (`B-DONE-8`): closure deltas are now documented across
  contract/current-state/todo authority, and Adoption Gate blockers are
  restated after text phase group closure.
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

Completed reviewable cut:

- `RB-B3.a` Frame submission outcome/finalization ownership

Purpose:

- define the first honest gate-5 contract cut: separate backend frame
  execution from shared frame-outcome finalization so frame/present/order
  ownership stops drifting through `renderer_frame_host.zig`

Owner docs:

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Primary code pressure:

- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/backend_dispatch.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`

Acceptance criteria:

- queue/authority docs explicitly distinguish product-level frame outcome
  finalization from backend-native begin/submit/abandon execution
- the first cut does not smuggle terminal-present policy back into the broader
  frame lane
- the next code step is obvious enough to implement without reopening gate #2
- shared finalization no longer consumes raw backend success booleans for frame
  submission

Do not do:

- do not widen this into a renderer-wide rewrite in one commit
- do not let `backend_dispatch` become a general policy bucket
- do not collapse frame and terminal-present finalization into one vague seam

Stop marker:

- one shared frame-execution outcome surface exists
- backend begin/submit/abandon results report through it
- shared frame finalization consumes it without backend-shaped schema growth

Latest reviewable cut:

- `RB-B3.b` Frame begin readiness ownership

Purpose:

- expose backend frame-entry readiness to shared draw/runtime code so a begin
  failure does not silently run the full draw path with no drawable backend
  frame

Owner docs:

- `app_architecture/ui/FRAME_BEGIN_READINESS_PLAN.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Primary code pressure:

- `src/ui/renderer.zig`
- `src/ui/renderer/renderer_frame_host.zig`
- `src/ui/renderer/gl_backend.zig`
- `src/ui/renderer/metal_backend.zig`
- `src/app_shell.zig`
- `src/app/draw_frame_runtime.zig`

Acceptance criteria:

- shared redraw policy still decides whether a frame is attempted
- backend begin/acquire reports one narrow shared readiness result
- shared draw/runtime can skip draw work when frame begin is not ready
- the cut does not widen into broader frame ordering or transaction redesign

Do not do:

- do not turn this into a general frame transaction object yet
- do not move redraw policy into backend code
- do not widen `FrameSubmission` or reopen terminal-present seams

Stop marker:

- `Renderer.beginFrame()` no longer hides backend begin readiness behind `void`
- OpenGL and Metal both report frame-entry readiness through one small shared
  surface
- draw/runtime code can exit early on a non-ready frame without backend-shaped
  branches

Next reviewable cut:

- `RB-B3.c` Non-terminal frame family ownership

Purpose:

- make the first non-terminal composition family first-class in shared
  frame/present bookkeeping so Android renderer adoption no longer inherits a
  terminal-only product feedback surface

Owner docs:

- `app_architecture/ui/NONTERMINAL_FRAME_FAMILY_PLAN.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Primary code pressure:

- `src/ui/renderer/present_trace_runtime.zig`
- `src/ui/renderer/renderer_frame_host.zig`
- `src/app/present_feedback_runtime.zig`
- `src/ui/renderer/renderer_chrome_band_host.zig`

Acceptance criteria:

- one shared family-level frame summary surface exists
- product-level frame feedback is no longer terminal-only in meaning
- the planned non-terminal adopters report through that surface:
  - `chrome_band`
  - `editor_row_band`
  - `sample_section`
- terminal feedback remains correct

Do not do:

- do not widen this into a generic multi-family present framework
- do not reopen terminal-present redesign while doing this cut

Stop marker:

- terminal, `chrome_band`, `editor_row_band`, and `sample_section` all report
  through one shared family summary surface
- present feedback no longer needs trace-only inference for those non-terminal
  families
- queue/docs clearly state the lane is structurally complete for its planned
  adopters

Current evidence:

- `Renderer.beginFrame()` now returns shared frame-entry readiness instead of
  hiding backend begin/acquire truth behind `void`
- `draw_frame_runtime.zig` now skips the draw body and goes straight to normal
  frame submission/finalization when frame begin is not ready
- Metal live-smoke and diagnostic paths now gate capture/draw work on that same
  readiness truth
- this did not require a broader frame transaction object or a widened
  `FrameSubmission`
- the smallest remaining ordering leak after that cut was just the initial
  backend clip reset running before shared code knew whether a drawable frame
  existed
- that follow-up is now fixed too: initial clip reset only runs when frame
  begin reports ready

Current implication:

- the current evidence does not yet force a larger unified begin/prelude host
  seam
- the next gate-5 cut should wait for a stronger ordering/ownership leak than
  one early backend clip reset
- one more product-level leak from the same seam is now fixed too: present
  capture is no longer cleared on `not_attempted` / `begin_failed` /
  `abandoned` outcomes where no drawable frame existed
- capture now stays armed across those no-drawable-frame outcomes and clears
  only once a drawable frame actually reaches submit
- failed-submit inspection did not prove a larger structural cut either; the
  next honest correction there was observability only
- present feedback now logs `frame_submission` with explicit submitted truth
  instead of logging failed submits under `frame_present`
- the restart question is now answered explicitly in authority docs:
  - `submitted = false` may still advance per-frame observability/reset state
  - it must not advance submission sequence or terminal presentation retirement
  - capture stays armed for `not_attempted` / `begin_failed` / `abandoned`, but
    may clear for `submit_failed`
- shared `FrameSubmission` feedback now matches that rule too:
  `terminal_presented` stays false and
  `terminal_presented_generation` stays null on `submitted = false`
- `RB-B3.c` checkpoint: shared frame finalization now produces one
  `FrameFamilySummary` surface and stores it on `FrameSubmission`.
- terminal presentation retirement feedback now also consumes
  `family_summary.terminal` directly instead of separate
  `FrameSubmission` compatibility fields.
- `renderer_chrome_band_host` is the first non-terminal adopter: chrome band
  fill/outline/text operations now mark family touch participation, and present
  feedback reports `chrome_band_touched` / `chrome_band_presented` directly
  from submission family summary.
- `editor_row_band` is now also adopted into shared frame family summary.
- present feedback now also reports `editor_row_band_touched` /
  `editor_row_band_presented`
- `sample_section` is now also adopted into shared frame family summary.
- present feedback now also reports `sample_section_touched` /
  `sample_section_presented`
- terminal presentation retirement feedback now also consumes
  `family_summary.terminal` directly instead of separate
  `FrameSubmission` compatibility fields
- the next concrete gate-5 pressure is now explicit:
  `terminal_widget_presentation_runtime.zig` still branches on
  `usesDirectTerminalPresentation(...)` for some product-significant decisions,
  so the next reviewable cut is to move those decisions behind the terminal
  present contract
- focused `renderer_frame_host.zig` tests now lock the current gate-5 frame
  policy in code:
  - begin prelude reset
  - submission sequence only advancing on `submitted`
  - capture preserved for `begin_failed`
  - capture cleared for `submit_failed`
  - failed submission not surfacing terminal-presented feedback

Next reviewable cut:

- `RB-B3.d` Terminal present path decision ownership

Purpose:

- remove the remaining product-significant
  `usesDirectTerminalPresentation(...)` decisions from
  `terminal_widget_presentation_runtime.zig`

Owner docs:

- `app_architecture/ui/TERMINAL_PRESENT_PATH_DECISION_PLAN.md`
- `app_architecture/ui/TERMINAL_PRESENT_TRANSACTION_PLAN.md`

Acceptance criteria:

- widget/runtime code no longer branches on direct-vs-retained terminal path
  mode for recent-input force-full policy, fast-present reuse gating, or
  direct partial-update entry
- shared planning stays product-owned
- presentable host / shared transaction contract owns path-satisfaction
  decisions

Do not do:

- do not widen into another terminal-present redesign
- do not reopen Metal validation
- do not introduce new plan/result schema unless the current vocabulary proves
  insufficient

Current evidence:

- `terminal_widget_presentation_runtime.zig` no longer calls
  `usesDirectTerminalPresentation(...)`
- recent-input force-full policy, fast-present reuse gating, and direct
  partial-update entry now terminate in `renderer_presentable_host.zig`
  instead of open-coded widget-runtime path checks
- the old `usesDirectTerminalPresentation(...)` helper is now removed
- this is a narrow path-decision ownership transfer only; execution behavior
  still flows through the existing terminal present transaction seams

Next reviewable cut:

- `RB-B3.e` Presentable lifecycle parity

Purpose:

- make the next shared terminal presentable lifecycle seam more backend-neutral
  so OpenGL retained-target semantics do not remain the de facto reference
  shape over Metal snapshot/composition behavior

Owner docs:

- `app_architecture/ui/PRESENTABLE_LIFECYCLE_PARITY_PLAN.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Acceptance criteria:

- the next presentable lifecycle seam is explicit in shared code and docs
- shared code no longer reads like it is asking for "retained update if
  possible, fallback otherwise" as the primary lifecycle contract
- OpenGL and Metal satisfy one clearer presentable lifecycle vocabulary through
  backend-owned mechanics

Current evidence:

- backend dispatch and presentable host now route through
  `refreshTerminalPresentable(...)` instead of
  `updateRetainedPresentable(...)`
- the shared refresh result surface is now:
  - `.refreshed`
  - `.target_unavailable`
  - `.unsupported`
- widget/runtime behavior is unchanged in this cut
- active widget/runtime refresh flow names are now also presentable/refresh-
  shaped instead of retained-path-shaped

Do not do:

- do not widen into general backend-runtime storage cleanup
- do not reopen Metal validation as part of the structural cut
- do not start Android renderer backend code here

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

- text phase group closure for chrome/sample/editor row-band is now complete;
  this is no longer an active blocker class for Milestone B
- `SurfaceDraw` semantics are still not one honest product-level story
- presentable parity/ownership is still not neutral enough
- backend runtime storage still widens under shared renderer ownership, even
  though direct runtime-state reaches are now confined to backend-owned modules
- the remaining loud ordering pressure is now primarily lifecycle/submission
  truth, not local text-phase band composition
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
