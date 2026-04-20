# Terminal Surface Contract (host-agnostic)

Date: 2026-04-19 (authority corrected 2026-04-19 — `CZH-B6-corrective`)

Purpose: freeze the **terminal surface** contract for **shared GPU presentation**
of terminal frames: what the host supplies, what Zide owns, and what stays in
backend-specific mechanics (`app_architecture/ui/RENDER_BACKEND_CONTRACT.md`).

This sits alongside native lifecycle (`app_architecture/platform/NATIVE_HOST_CONTRACT.md`)
but does **not** define windowing, swapchains, or platform view graphs as the
frozen abstraction — those are how a host *may* obtain or wrap the shared GPU
resource, not the contract center.

Android proved “host hands in a drawable attachment; Zide owns terminal truth
and generation bookkeeping” — **Android is one host**, not the definition.
Android may move when the shared contract matures; the first Android GLES shape
is validation pressure, not permanent architecture.

## What the frozen abstraction is

The contract centers on the **shared GPU texture or resource** the terminal
draw path uses: the object (or opaque handle) the **active renderer backend**
requires so the terminal widget can record draws into a **known, host-visible
GPU attachment** that the host can then **bind and present** inside its
platform frame lifecycle.

- **Not** the terminal cell snapshot buffer (publication / **VT core FFI**).
- **Not** GLES vs Metal vs Vulkan mechanics — those remain in
  `RENDER_BACKEND_CONTRACT.md`.

## Ownership split (frozen)

| Concern | Owner |
| --- | --- |
| Initializing and passing the **shared GPU texture/resource attachment** the backend needs for terminal draws (opaque or typed per backend) | **Host** — in cooperation with **`RendererBackend`** setup; concrete object shape is backend-local |
| GPU devices/queues/context objects and backend-specific upload paths | **`RendererBackend`** per `RENDER_BACKEND_CONTRACT.md` |
| Terminal **semantic** state at engine/publication layer | **Zide terminal stack** (`TerminalCore` + publication) |
| **Dirty tracking**, **published vs acknowledged generation**, **needs_redraw**, and update logic for **terminal content** (what must be redrawn and which generation is current) | **Zide** — hosts must not invent parallel damage or generation truth |
| Scheduling terminal draw work against the shared GPU resource | **Zide renderer + terminal widget** (shared product path) |
| **Binding** that shared resource into the host’s **platform presentation** (per-frame lifecycle, when pixels reach the display) and reporting **presentation completion** so generations can retire | **Host** — completion still flows through the **shared FFI present-ack** (`VT core FFI`) so Zide stays consistent |

Interpretation:

- The **host** is responsible for making a **suitable shared GPU attachment**
  available and keeping it live across the host’s frame lifecycle; the **frozen**
  idea is “shared GPU resource the terminal draws into,” not “this OS window
  handle” as the universal type.
- **Zide** owns **dirty tracking and generation truth** for terminal **content**
  and the **update contract** for what must be repainted into that resource.
- **Backend-specific** details (Metal drawable vs GL surface vs Vulkan image)
  stay out of this document by design.

## FFI touchpoints (VT core FFI, read-only contract)

Hosts observe redraw and generation pairing through **VT core FFI** symbols (e.g.
`needs_redraw`, `redraw_state`, `published_generation`, `present_ack` /
`acknowledged_generation`) — portable **logical** surface for frame contract
state. Raw GPU handles do not need to cross that boundary for the contract to
hold.

The current FFI/caller layout is not the maturity boundary. VT core,
bring-your-own-PTY, editor backend, and terminal presentation callers may move
when that makes ownership cleaner. The contract to preserve is the meaning of
the state crossing, not the current file or call-site placement.

**Zig seam (logical bundle):** `src/terminal/surface_contract.zig` layers **FFI**
(`ffiRedrawStateFill`, `ffiNeedsRedrawU8`, `ffiPresentAckGenerationAdmissible` for
`core_api` exports), **widget composite** (`publicationClearPair*` for terminal
widget publication/clear vs last surface draw), and **primitives** (`needsRedrawFromPair`,
widget legs, bundle `fillRedrawState`) with one policy per layer (`CZH-S13`,
`CZH-S14`).

**Widget draw consumer:** Terminal widget reuse/invalidation uses **only** the
composite pair helpers (`publicationClearPairMismatchesFromLastSurfaceRender`,
`publicationClearPairMatchesLastSurfaceRender`); primitives are decomposition
inside `surface_contract`, not alternate call-site shapes (`CZH-S12`, `CZH-S14`).

**Host attachment seam:** `src/terminal/surface_attachment_contract.zig` names
the logical predicate pipeline-ready ∧ host-target-available for the shared drawable attachment.
**Canonical compute route:** `TerminalPresentationBridge` (owned by terminal layer) computes
and stores conjunction via `notePresentableAvailability` — this is the single compute path.
**Canonical read route:** same bridge provides `readSharedSurfaceAttachmentReady` for
read-only access to conjunction. Widget layer (`TerminalWidgetSurfaceState`) delegates to bridge
and does not re-derive conjunction. Present-plan reuse eligibility uses
`terminalPresentablePipelineReady()` (pipeline leg only) by design (`CZH-S15`).
`presentationUpdateDelta.terminal_presentable_pipeline_ready` is the same pipeline leg (`CZH-S16`);
full readiness comes from bridge conjunction paths only.

## Operator observability (structured logs)

Zide operator logs on the widget presentation path mirror the same split as the
seams above (`CZH-B24`). **Reporting-carrier consolidation (`CZH-S23`):** the conjunction
value in **`renderer.terminal_present`** is reported from **`PresentationPresentState.shared_surface_attachment_ready`**
for that tick (not from `readSharedSurfaceAttachmentReady()` at the log callsite).

- **`renderer.terminal_present` (`logUnavailable`):** `publication_generation`;
  `terminal_presentable_pipeline_ready` (pipeline leg); `host_surface_target_available`
  (host drawable target leg); `shared_surface_attachment_ready` (full attachment,
  same predicate as `readSharedSurfaceAttachmentReady`, **carrier:** present-state field); `renderer_presentable_refresh_tag`
  (renderer refresh cycle enum, distinct from the pipeline-ready bool); view/update
  and geometry fields as emitted.
- **`terminal.generation_handoff`:** explicit `publication_*` / `capture_*` / `last_surface_render_generation`
  tokens in the widget draw path; `presented_generation` / `published_generation` /
  `pending_generation` in frame pacing — generation triples, not attachment conjunction logs.

## Widget presentation storage (dominant field names, `CZH-B25`)

**Storage ownership:** `PresentationState` (`src/ui/widgets/terminal_widget_presentation_state.zig`)
stores the two attachment legs as **`terminal_presentable_pipeline_ready`** (pipeline only) and
**`host_surface_target_available`** (host drawable target). These names match the
`SharedSurfaceAttachmentPipelinePair` contract; full attachment is never computed or stored locally.

**Compute/read delegation:** Widget surface state delegates conjunction computation and reading to
`TerminalPresentationBridge` (terminal-layer seam). Widget stores legs only; bridge owns canonical
`notePresentableAvailability` (compute) and `readSharedSurfaceAttachmentReady` (read) routes.

**Transient present gate (`PresentationPresentState`, `CZH-S22`):** the widget presentation runtime
holds per-tick **`host_surface_target_available`** and **`shared_surface_attachment_ready`**
(conjunction from bridge's `notePresentableAvailability`) before draw/present; operator
`logUnavailable` reports the same conjunction field — not a re-derivation from unrelated state.

## Present aggregation (`TerminalPresentResult`, `CZH-B26`)

`TerminalPresentResult` (`src/ui/renderer/presentable_contract.zig`) carries **`host_surface_target_available`**
(host drawable-target leg only) and **`shared_surface_attachment_ready`** (full attachment when the
caller computes pipeline ∧ host target). `ReusePresentOutcomeState` in the widget presentation
runtime uses the same two identifiers before folding into `TerminalPresentResult` on reuse success.

**Reporting/result cohesion (`CZH-S24`):** structured **logs** use `PresentationPresentState` / widget
getters for attachment visibility; **host export** uses `TerminalPresentResult` after runtime folds
outcomes — same field **names** where applicable, distinct **roles** (reporting snapshot vs aggregated
result).

## Presentation runtime ownership (authority)

**Terminal-owned runtime orchestration layer:**
The terminal layer owns the presentation runtime module (`src/terminal/presentation_runtime.zig`)
that manages all semantic presentation logic:

- **Outcome classification** (pure semantic): `classifyRefreshOutcome()`, `classifyDirectPresentOutcome()`, `reuseSuccessOutcome()`
  - Classify refresh cycle, direct present, and reuse results into outcome states with invariant fields
  - Refresh classification carries `shared_surface_attachment_ready` inline in `RefreshOutcomeState` (no separate conjunction transport parameter)
  - All hardening assertions validate semantic consistency (no behavior changes)
  
- **Outcome folding** (pure computation): `presentResultFromRefreshOutcomeState()`, `presentResultFromReuseOutcomeState()`
  - Fold outcome state + timing into host-facing result structs
  - Refresh fold consumes conjunction from `RefreshOutcomeState.shared_surface_attachment_ready` (no separate fold argument)
  - Propagate conjunction state (attachment readiness) through folding
  
- **Orchestration coordination** (pure except for integration seams):
  - **Refresh path:** `runPresentableRefreshCycle()`, `runRefreshedPresentablePresentation()`, `executeRefreshPresentFlow()`
    - Drive refresh cycle outcome classification and result folding
    - Refresh transport is single-carrier: `runRefreshedPresentablePresentation` supplies conjunction once, `classifyRefreshOutcome` stores it inline, and fold reads from outcome state
    - No renderer/shell calls; coordinates pure decision paths
  - **Reuse path:** `tryFastPresentExisting()`, `runFastPresentIfAvailable()`
    - Reuse eligibility decision based on generation pairing
    - Outcome classification and result folding for cached frames
  - **Direct path:** `directPresent()`
    - Direct present path outcome classification and result folding
  - **High-level coordination:** `runPresentation()`, `refreshPresentState()`, `planUpdate()`
    - Top-level orchestration that calls phase-specific helpers
    - Planning surface update modes based on presentation state
    - No re-derivation of outcomes; delegates to outcome-phase helpers

- **Geometry computation** (pure): `PresentationGeometry`, `computePresentationSurfaceGeometry()`, `ViewportShiftState`
  - Surface geometry derivation from view dimensions and cell metrics
  
- **Attachment readiness** (pure computation): `computeHostSurfaceAttachmentState()`
  - Apply `TerminalPresentationBridge` to derive full conjunction state

**Widget-retained integration layer** (`terminal_widget_presentation_runtime.zig`):
The widget layer remains a thin facade that:
- Gathers input/geometry/UI context from renderer/shell/view state
- Calls terminal-owned orchestration entry point with pure state
- Interprets results in renderer/shell context (timing, callbacks, viewport clipping)
- Delegates all semantic classification, folding, and outcome coordination to terminal layer
- Keeps no presentation logic, only integration and GPU operations

**No re-derivation rule:** Widget layer never recomputes outcomes, folding, or orchestration decisions.
All semantic logic is owned by terminal layer and called through defined interfaces.

**Canonical orchestration entry point:** `runPresentation()` in terminal runtime is the single
orchestration function called by widget facade. All refresh/reuse/direct paths flow through this
or its phase-specific helpers. Widget may call phase helpers directly only for testing/internal
decision gating (e.g., checking reuse eligibility)—production codepaths always flow through
the canonical entry point for consistent outcome handling
in UI layer.

**Outcome types:** Outcome structs and classification helpers are defined in terminal layer.
Widget layer uses them, does not redefine or re-classify.

## Android mapping (example, not definition)

On Android, code may obtain a native window or surface on the way to a GLES
texture or image; the **contract** here is still: shared GPU attachment for
terminal draws + Zide-owned generations + host-owned presentation binding. JNI or
`ANativeWindow` shape remains **platform-local**.

## Non-goals

- Defining draw queues, passes, or backend resource types — see
  `RENDER_BACKEND_CONTRACT.md`.
- Defining JNI, Activity, or desktop window APIs — see `NATIVE_HOST_CONTRACT.md`
  and platform docs.
- Changing parser/engine semantics — `VT_CORE_DESIGN.md` / maturity campaign.

## Related documents

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md` — lifecycle + native
  surface availability patterns.
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md` — backend responsibilities
  and adoption gates.
- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — where publication
  and presentation meet.
