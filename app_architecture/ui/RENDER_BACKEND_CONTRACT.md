# Renderer Backend Contract

Purpose: define the renderer/backend abstraction Zide is actually trying to
build, using OpenGL and Metal as the two reference implementations.

This is current architecture authority for backend abstraction quality.

## Why This Exists

Zide no longer needs a vague "multiple backends someday" story.

It needs a contract strong enough that:

- OpenGL can remain the mature baseline
- Metal can become a first-class peer instead of a special side lane
- Vulkan can be added later without reopening the renderer root as the real
  backend implementation center
- Android/mobile pressure can fit later without exposing that the contract was
  really desktop-GL-shaped all along

The standard is not "can two backends coexist."

The standard is:

- do two backends prove one clean contract

Current proving rule:

- Linux GL is the active proving ground
- Metal remains a required reference implementation
- OpenGL convenience must not define the public contract

## Product Standard

The backend contract must make OpenGL and Metal read like two implementations
of the same rendering system.

That means:

- shared renderer code owns product semantics
- backend code owns GPU/frame/surface mechanics
- backend choice changes implementation, not architecture

The backend contract is only good enough when adding Vulkan would mainly mean:

- implement the same frame lifecycle
- implement the same surface draw contract
- implement the same presentable/retained target contract
- implement the same atlas/image upload contract

It must not require:

- adding new Vulkan-specific state to `Renderer`
- adding Vulkan-native draw queues to shared renderer state
- teaching widget/runtime code about Vulkan-only present rules
- reinterpreting capabilities because the shared draw contract was never real

## Backend Adoption Gate

Until the following are true, Vulkan and Android rendering adoption are still
blocked by contract debt rather than implementation effort.

### Must Be True Before Vulkan Or Android Rendering Starts

1. One product-level submission story for shared draws

- shared code must not care whether a backend consumes recorded work
  immediately or later
- backend timing may differ internally, but product semantics must not
- today this is still the loudest blocker

2. Presentable lifecycle is neutral enough for a third backend

- retained/direct/snapshot draw must read like one contract
- OpenGL retained targets must not remain the de facto reference shape
- Android surface loss/replacement and Vulkan swapchain replacement must fit
  without reopening shared renderer ownership

Current warning: the live shared presentable contract is terminal-only today.
The old retained **editor** presentable arm has been removed rather than left
as a dormant disabled branch. If editor retained presentation returns, it must
come back as a deliberate reviewed lane, not as an assumed part of the routine
backend contract.
That cleanup is now reflected in the API too: the dead one-value
`PresentableSurface` parameter is gone, so terminal presentable operations no
longer pretend to stay generic by forwarding `.terminal` through every layer.
The shared contract is slightly more honest again at the lifecycle edge too:
it no longer exports `beginPresentable(...)` / `endPresentable(...)` as if
those were backend-neutral presentable verbs. The live shared seam only asks
for one higher-level thing there: "attempt one retained terminal presentable
update cycle."
The next presentable problem is therefore narrower and more honest: OpenGL
still models terminal presentation as a real retained update target, while
Metal still models it as snapshot creation plus composition replay. A future
backend needs those two lifecycle shapes to converge further than they do
today.

3. Backend-native runtime storage is no longer a widening pattern on `Renderer`

- adding a backend must not mean adding another renderer-hosted peer runtime
  bundle as the normal move
- the host must narrow further toward backend-owned or opaque runtime storage

4. Resource/image handles stay opaque in shared code

- no new backend-tagged handle variants in shared payloads or product APIs
- Vulkan/Android must not require shared code to learn a new GPU object shape

5. The remaining active ordering families have an honest home

- terminal is already mostly carved out behind terminal/presentable seams
- shell chrome is now carved out behind `renderer_chrome_band_host.zig`, but is
  explicitly capped until it becomes a real recorded phase
- the remaining loud generic surface-pressure families are editor banding and
  sample/diagnostic section banding
- editor composition must honor the editor pane rect as its geometry authority;
  deriving wrap/segment truth from full-window width is a contract bug, not an
  acceptable implementation shortcut
- retained editor presentation is not part of the live shared presentable
  contract today; if it returns, it must come back through a reviewed lane
  with honest ownership and geometry/update truth
- backend-runtime storage pressure is now about ownership of the runtime bundle
  shape, not shared caller leakage; shared code should not read backend-native
  runtime fields directly

### What Is No Longer Blocking By Itself

- terminal pane/background misuse of generic `SurfaceDraw`
- terminal overlay/cursor duplicate paths
- backend-tagged raw-image payload unions
- product-facing persistent image APIs that exposed backend texture structs
- shell chrome living as scattered widget-local fill/text calls with no local
  composition seam

### Current Answer

If Vulkan or Android rendering started today, the repo would still be doing
renderer surgery, not just backend implementation. The remaining blockers are
mainly:

- shared surface-phase semantics
- presentable parity/ownership
- renderer-hosted backend runtime shape
- editor/sample ordering families still leaning on generic surface timing

## Contract Layers

The backend abstraction should be read in this order:

1. renderer-owned product semantics
2. backend-neutral draw/present contracts
3. backend-specific implementation details

### 1. Renderer-Owned Product Semantics

The shared renderer owns:

- composition planning
- clip ownership
- retained/presentable intent
- screenshot intent
- text/image/surface submission intent
- capability reporting

The shared renderer does not own:

- API-specific frame handles
- API-specific texture handles
- API-specific command encoders
- per-backend draw unions

### 2. Backend-Neutral Contracts

The shared backend contract must define at least these seams:

#### Frame lifecycle

- `prepareFrame`
- `beginFrame`
- `submitFrame`
- `abandonFrame`
- optional readback/capture hooks

#### Surface draw contract

One backend-neutral draw list that can express:

- solid rects
- atlas samples
- raw images
- presentable/snapshot blits

This list must not embed Metal-native or GL-native draw structs in shared
renderer state.

**Submission shape today:** the shared union lives in `surface_draw.zig`
(`SurfaceDraw`). The renderer now keeps `recordSurfaceDraw(...)` internal, but
still routes shared solid draws through the grouped backend draw contract.
Metal records into the submit-time surface phase; OpenGL consumes the same
record immediately via `gl_backend.consumeRecordedSurfaceDrawInSurfacePhase`
(raster-space
`dest_rect` / atlas `dest_x`/`dest_y` converted back to logical coordinates to
match how Metal enqueues those draws). Atlas samples on OpenGL require
`text_rendering_mode == gl_texture_atlas` and use `terminal_font` coverage/color
textures. Raw images now use one opaque shared `GpuImageRef` handle
(`handle + width + height`) instead of a backend-tagged `.opengl` / `.metal`
union inside the shared payload; backend-specific interpretation and
clone/release logic terminate in `gl_backend.zig` / `metal_backend.zig`.
Persistent image upload/draw used by higher-level product code should follow
the same rule: public renderer contracts expose `GpuImageRef`, not backend
texture structs.
For CPU pixel buffers on OpenGL, `drawRawImageRgba` / `drawRawImageRgb` upload
ephemeral textures then submit one `SurfaceDraw.raw_image` with a `GpuImageRef`
whose handle is interpreted as a GL texture id. On Metal,
`appendSolidRect` / `appendAtlasSample` build the same `SurfaceDraw` values and
submit through the grouped backend draw contract so queueing shares the same
payload semantics as other callers. High-level logical solid fills route
through that same shared submission contract via `renderer_surface_host.zig`,
while integer `addTerminalRect` remains on backend draw ops so OpenGL can keep
batching terminal quads.

This means the contract vocabulary is ahead of the implementation truth:

- product/shared code can now talk about one `record one SurfaceDraw` contract
- but backend choice still changes when that record is consumed

That semantic split is still acceptable only as a current-state defect to be
closed, not as a stable design target.

**Required ordering rule:** product/shared code may assume that
`recordSurfaceDraw(...)` preserves order relative to other recorded surface
draws in the same backend-defined surface phase. It must not assume that a
recorded surface draw interleaves with terminal batching, presentable update
lifecycle, or backend-native mid-frame work at the exact call site. Any code
that depends on that tighter interleaving is not a valid `SurfaceDraw` caller;
it belongs on a more specific seam.

**Required caller rule:** `SurfaceDraw` is for generic UI fills, atlas/image
samples, and presentable/snapshot-style blits. It is not the contract for:

- terminal grid backgrounds
- terminal glyph/cursor/composition cells
- retained-presentable update begin/end lifecycle
- other backend-specific batched primitives that already have a dedicated seam

If a rendering path needs terminal-cell batching, presentable lifecycle timing,
or backend-specific phase guarantees, it must not be routed through
`SurfaceDraw` just because that path already exists.

**Active caller set (2026-04-07):** after the terminal-path cleanup, the
remaining real `SurfaceDraw` producers are intentionally narrow:

- generic UI/editor/shell logical fills and outlines through
  `renderer_surface_host.zig`
- text-runtime background clears that are still just generic UI rects
- presentable/snapshot blits through the shared presentable contract
- raw image and atlas samples that already fit the shared payload model

Terminal pane / viewport fills are no longer counted in that generic caller
set. They now route through the presentable contract as terminal presentable
backdrop work, which is the more honest ownership story for a fill that exists
only to bracket presentable composition.

So the remaining blocker is not broad caller sprawl. The remaining blocker is
backend phase timing:

- OpenGL executes the surface phase immediately at record time
- Metal replays the recorded surface phase later in submit

The next contract cut must attack that phase truth directly rather than reopen
caller triage unless a new misuse appears.

**Known ordering blocker (2026-04-07):** a broad "defer all GL surface records
to submit" cut is still not safe, even after terminal cleanup, because many
remaining active `SurfaceDraw.solid` callers are immediate background layers
paired with text or outline work that still renders right after them at the
same call site. Examples include status/top bars, editor fills, text-runtime
background clears, and similar UI chrome. If OpenGL deferred those solids to a
submit-time surface phase while text stayed immediate, the deferred fills would
still overpaint later text. So the next safe semantic cut cannot be "delay all
GL surface draws"; it must either:

- move a narrower subset with no immediate text dependency
- or define a stronger shared phase boundary that also captures the dependent
  text/background ordering

**Blit-subset reality (2026-04-07):** splitting fills from blits was useful,
but it did not produce a generally safe "delay these later" subset yet.
`SurfaceDraw.raw_image` and atlas-style blits are still used in places with
local text ordering:

- kitty image placements can interleave with terminal text in the same visual
  lane
- shell/tab icons draw before adjacent tab labels at the same call site

So generic blits are still not automatically phase-isolated just because they
are not fills. The one comparatively isolated blit family is retained
presentable/snapshot draw, but that already belongs under the presentable
contract and is too narrow to solve the broader `SurfaceDraw` timing split by
itself.

**Active ordering families (2026-04-07):** the remaining
background-before-dependent-work problem is no longer diffuse. It clusters into
repeatable families:

- shell/UI chrome bands where a bar or badge fill is followed immediately by
  adjacent text, icons, or outlines (`status_bar`, `tab_bar`, `shared_top_bar`,
  `side_nav`, notice/confirm surfaces, caption buttons)
- editor banding where row/gutter/current-line fills are followed by text and
  overlay decoration in the same visual band
- font/sample or diagnostic sections where section fills are followed by text
  preview content

That means the next real semantic cut should probably target one family at a
time or define a stronger shared phase that explicitly contains both the fill
and its dependent text/outline work. It should not treat all remaining solids
as one undifferentiated problem.

**Shell/UI chrome blocker (2026-04-07):** the obvious next family is shell/UI
chrome bands, but that family is not a free move today because the dependent
text side is still immediate. Shared UI text (`drawText`, `drawTextOnBg`,
icon text, most app-font draw paths) still terminates in immediate texture draw
work rather than one recorded phase shared with the corresponding fills. So a
"move shell chrome fills later" cut would still separate chrome backgrounds
from their labels/icons unless the phase boundary also grows to own the
dependent text path.

That is not just true for the big bars. The smaller obvious subsets also still
have the same shape:

- config reload notice: fill + outline + immediate text
- close-confirm modal/buttons: fills + outlines + immediate text
- caption buttons: fills + immediate icon strokes/rects

So there is no honest "easy shell subset" today where fills can move alone
without reopening the same ordering bug under a smaller name.

**Shell/UI chrome direction (2026-04-07):** the next honest move is not
"another subset hunt." It is to introduce a dedicated band/composition seam for
UI chrome families that need one local ordering story for:

- band/background fills
- dependent text and icon text
- dependent outline/accent primitives

That seam should be read as product-level band composition intent, not generic
surface submission. The backend-neutral rule should be:

- preserve order inside one recorded band composition unit
- do not expose backend timing differences to the caller
- keep generic `SurfaceDraw` for truly generic fills/blits that do not depend
  on immediate neighboring text/outline work

Initial scope should stay narrow:

- status bar
- tab bar
- shared top bar
- side nav
- small notice/confirm/chrome surfaces only if they use the same band story

Do not broaden this into "all UI drawing" up front. The point is to give the
chrome family one honest seam, not to replace every renderer path with a new
god-queue.

**First adopter checkpoint (2026-04-07):** the first useful code step is now
present too: a narrow widget-side chrome band host exists and the status bar,
tab bar, shared top bar, and side nav use it. That is not the final
backend-neutral phase yet. It is the first explicit contract surface where one
chrome family can stop reading like "some fills plus unrelated immediate text
calls." The next cuts should grow this seam carefully, not duplicate it.

The nearby config-reload notice also fits this seam. Centered modals such as
terminal close confirm do not. They are popup/card surfaces with different
ownership and should not be forced into the chrome-band contract just because
they also mix fills and text.

**Ownership checkpoint (2026-04-07):** now that the first intended adopters are
covered, this seam no longer lives under `widgets/`. It has moved into the
renderer host area as `renderer_chrome_band_host.zig`. That is still not a
backend-neutral phase, but it is the right ownership story: one UI composition
host adjacent to the other renderer hosts, not a random widget helper that
looks private but keeps spreading.

**Renderer-host checkpoint (2026-04-07):** this seam now terminates directly in
renderer surface/text hosts instead of bouncing back through `Shell`
convenience forwards. That keeps the ownership story honest: it is a renderer
composition host, not a widget helper wearing renderer clothes.

**Current blocker / stop rule (2026-04-07):** do not keep widening this seam as
if it were already a backend-neutral phase. Today it is still a renderer-host
composition helper over immediate text/surface work. The next valid step is
either:

- introduce a real recorded band-composition phase with one product-level
  ordering rule
- or stop here and treat shell chrome as a local renderer-host seam while the
  larger `SurfaceDraw` phase contradiction remains primary

Do not create a second chrome helper, and do not keep adopting unrelated popup
or modal surfaces just to make the seam look more important than it is.

With that family now carved out, the next `SurfaceDraw` timing pressure should
be read as primarily editor/sample banding pressure rather than shell chrome
pressure. That is where the remaining generic surface-phase design work should
look next.

Do not collapse editor and sample/diagnostic work into one new seam by default.
Editor already has a stronger local composition model than the sample view, so
the next cut should respect that difference instead of inventing a fake common
layer.

The first sample-side proof should stay tiny. A dedicated sample/diagnostic
section seam is acceptable if it only owns section background plus dependent
sample text for that lane. It should not be broadened into a repo-wide band
contract by analogy.

#### Presentable contract

One backend-neutral presentable surface contract that can express:

- allocate/ensure
- host-owned update lifecycle
- direct draw or cached snapshot present
- snapshot shift/scroll
- availability/reuse truth

Retained targets, direct snapshot caches, and future Vulkan surfaces should all
fit under this seam without shared code importing a backend-specific surface
type.

#### Atlas and image contract

One backend-neutral resource story for:

- glyph atlas ownership
- atlas sample submission
- raw image upload/draw
- screenshot/readback capture

### 3. Backend-Specific Implementation

Backends own:

- API devices/contexts
- API frame handles
- API texture/resource handles
- shader/pipeline/sampler objects
- platform/API attachment details

Those details should terminate inside backend modules or backend-owned runtime
helpers, not inside the renderer root.

## Required Design Rules

1. `Renderer` must not store backend-native draw arrays.
2. `Renderer` must not store more than one backend’s API frame object at a
   time as explicit peer fields.
3. Shared runtime modules must not depend on GL-native retained target types.
4. Capabilities must describe behavior, not substitute for missing contracts.
5. The "current implementation truth" may stay uneven, but the contract
   vocabulary must stay backend-neutral.

## Reference Pressure

The strongest current pressure for this contract is:

- Ghostty for "renderer host is not the backend implementation center"
- Zed/GPUI for "multiple backend implementations can satisfy one higher-level
  renderer contract"

Current reference scan:

- `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md`

## Vulkan fit audit (evidence, 2026-04-06)

A dedicated fit audit records whether a future Vulkan backend could implement **this**
contract as routine backend work without renderer surgery:

- `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md`

**Reader’s guide:** that document is **research evidence**, not a rewrite of this
authority file. Its conclusion: target seams (`BackendOps`, `SurfaceDraw` intent,
presentable vocabulary) are **mappable**, but **today’s implementation** still has
blockers (dual submission semantics, renderer-hosted backend storage, presentable
parity). Treat the audit as input for **continued** backend closure, not as
approval to start Vulkan bootstrap code.

## Immediate Consequence

The next renderer/backend work should be judged against one question:

- does this change make OpenGL and Metal look more like two reference
  implementations of one contract

And one guardrail:

- would this still look like the right contract if Vulkan and Android/mobile
  were added later

If not, it is probably backend momentum, not backend architecture.
