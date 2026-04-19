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
pipeline-ready ∧ host-target-available for the shared drawable attachment.
`TerminalWidgetSurfaceState.notePresentableAvailability` routes through that seam;
present-plan reuse eligibility still uses `terminalPresentablePipelineReady()` (pipeline leg only)
by design (`CZH-S15`). `presentationUpdateDelta.terminal_presentable_pipeline_ready` is the same
pipeline leg (`CZH-S16`); full readiness uses `readSharedSurfaceAttachmentReady` /
`hostSharedSurfaceAttachmentReady`.

## Operator observability (structured logs)

Zide operator logs on the widget presentation path mirror the same split as the
seams above (`CZH-B24`):

- **`renderer.terminal_present` (`logUnavailable`):** `publication_generation`;
  `terminal_presentable_pipeline_ready` (pipeline leg); `host_surface_target_available`
  (host drawable target leg); `shared_surface_attachment_ready` (full attachment,
  same predicate as `readSharedSurfaceAttachmentReady`); `renderer_presentable_refresh_tag`
  (renderer refresh cycle enum, distinct from the pipeline-ready bool); view/update
  and geometry fields as emitted.
- **`terminal.generation_handoff`:** explicit `publication_*` / `capture_*` / `last_surface_render_generation`
  tokens in the widget draw path; `presented_generation` / `published_generation` /
  `pending_generation` in frame pacing — generation triples, not attachment conjunction logs.

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
