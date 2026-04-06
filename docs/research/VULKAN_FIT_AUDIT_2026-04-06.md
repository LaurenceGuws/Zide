# Vulkan fit audit (renderer/backend contract)

**Date:** 2026-04-06  
**Authority:** This audit is evidence and review input. It does not change
`app_architecture/ui/RENDER_BACKEND_CONTRACT.md` by itself; it interprets that
contract against `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md` and the
code paths those docs name.

**Scope:** Answer whether a Vulkan backend could be **routine backend work**
(implement the existing seams without reopening `renderer.zig` as the
implementation center) **as the repo exists today**. No Vulkan code; no Android
implementation.

**Method:** Trace the **target** contract (`RENDER_BACKEND_CONTRACT.md`), the
**honest current-state** audit (`RENDER_BACKEND_CURRENT_STATE.md`), and the
**documented submission split** (e.g. `SurfaceDraw` + `BackendOps` in
`renderer.zig`). Where code still contradicts the target contract, Vulkan inherits
that debt.

---

## Verdict (executive)

**Fit is not clean enough for a minimal Vulkan bootstrap to be “just another
backend module.”** A third backend would still risk **renderer surgery** unless
the structural gaps in current-state §§1–5 and “First Required Cut Order” are
addressed first—especially **unified surface-draw submission**, **presentable
parity behind neutral types**, and **moving backend-native storage off the
shared `Renderer` host**.

Vulkan is not blocked by naming; it is blocked by **ownership and submission
semantics** that are still split across GL immediacy vs Metal end-of-frame replay,
and by **renderer-carried backend bundles**.

---

## What Vulkan could implement *mostly unchanged* (conceptual mapping)

These are **real seams** that a Vulkan backend could **aim** to satisfy without
inventing a parallel API, *provided* the shared layer stops contradicting them:

1. **`BackendOps`-shaped lifecycle**  
   Init/deinit runtime, `beginFrame` / `submitFrame`, capabilities, screenshot
   hooks, presentable entrypoints, clip application, terminal primitive submission,
   persistent image textures, `enqueueSurfaceDraw`—as **one row** in the same
   ops-table pattern OpenGL and Metal use today.

2. **`surface_draw.SurfaceDraw` payload data**  
   Solid / atlas / raw image / presentable blit **as neutral data** can map to
   Vulkan pipelines, descriptor sets, and render passes—**if** every backend
   consumes one submission model (deferred record + submit vs immediate is a
   **backend policy**, not two product semantics).

3. **Frame semantics**  
   Acquire → record → present maps naturally to swapchain + command buffers, in
   the same conceptual slot as Metal’s frame object and GL’s implicit context +
   swap.

4. **`RendererCapabilities`**  
   Behavior flags remain backend-neutral; Vulkan would report truth the same way.

5. **Host / platform geometry**  
   Drawable size, display metrics, and native surface lifecycle remain owned by
   `PlatformRenderHost` / SDL normalization—not the graphics API choice.

**Important caveat:** “Could implement” does **not** mean “can drop in without
touching `renderer.zig`.” The current **implementation** still centralizes
backend choice and stores backend-native state on `Renderer` (see below).

---

## What still blocks Vulkan from being *routine*

These are **concrete** blockers derived from current-state authority, not generic
risk language.

| # | Blocker | Why it forces non-routine work |
|---|---------|--------------------------------|
| B1 | **Dual draw submission semantics** | Contract doc admits Metal **appends** `SurfaceDraw` to a replay queue while OpenGL **submits immediately**. Vulkan is inherently deferred; picking one model without a shared contract forces either a third special case in shared code or a redesign of the enqueue path. |
| B2 | **Metal-shaped queue consumption** | Current-state: Metal is still the backend that **consumes the shared draw union directly** for end-of-frame replay; OpenGL does not participate in the same path. Vulkan is not “like Metal” or “like GL” exclusively—it needs **one** contract. |
| B3 | **Texture handle variants in draw payloads** | `RawImageTexture`-style `.opengl` vs `.metal` branching (per contract doc) implies **new Vulkan-specific variants** or a **real opaque backend handle**—not neutral until unified. |
| B4 | **Renderer-hosted backend-native storage** | OpenGL and Metal runtime bundles still live on the shared `Renderer`. A Vulkan bundle would either **widen** that pattern (three backends on the host) or **force** the refactor that Milestone B was supposed to deliver: backend-owned storage. |
| B5 | **Presentable contract unevenness** | Retained targets remain **FBO/texture-shaped** in practice; OpenGL owns the rich path; Metal is narrower. Vulkan swapchain/images are a third shape—without **one** neutral presentable lifecycle, shared code will keep leaking assumptions. |
| B6 | **Shared frame / dispatch center** | `Renderer` still orchestrates product frame state + ops dispatch. Adding Vulkan touches the **same** root unless lifecycle moves behind a narrower backend seam (current-state §2). |
| B7 | **GL-only scene-target invalidation path** | OpenGL scene-target contract refresh and invalidation are real product seams; Metal stubs/no-ops parts of that. Vulkan would need an explicit story so shared code does not keep an implicit “GL is the real offscreen owner.” |

---

## Renderer-owned seams that would still force *surgery*

These are the **highest-risk edit surfaces** for a Vulkan bring-up if attempted
today:

1. **`src/ui/renderer.zig`** — `BackendOps` selection, `Renderer` struct layout,
   and any new backend enum value propagates across init/deinit and public
   facade methods.

2. **Shared enqueue / replay boundary** — Anything that assumes **one** of
   immediate GL vs queued Metal without a single backend-neutral “record then
   submit” rule.

3. **Presentable + terminal presentation stack** — Shared terminal presentation
   must not import Vulkan (or GL) types; today’s **parity gap** between GL and
   Metal means a third backend does not “slot in”—it **exposes** the gap.

4. **Capability + feature gating** — Acceptable only if capabilities describe
   **behavior**; any place that still encodes “how Metal does it” vs “how GL
   does it” becomes a third fork for Vulkan.

---

## Is the contract unfairly shaped by OpenGL?

**Partially yes, where implementation diverges from the written contract.**

- **Fair / neutral:** `SurfaceDraw` union, presentable **names** (`ensure` /
  `begin` / `draw` / `scroll`), and `BackendOps` indirection are deliberate
  neutral vocabulary.

- **GL-shaped in practice:** Immediate submission for GL vs queued replay for
  Metal; richer retained presentable path on GL; scene-target/offscreen story
  centered on OpenGL modules. The **written** contract says OpenGL must not be
  the design authority, but **behavior** still makes GL the “complete” lane for
  some paths.

Vulkan would **not** get a fair slot until **one** submission model and **one**
presentable lifecycle maturity target apply to **all** active backends.

---

## Would the current contract age badly under Android / mobile pressure?

**Yes, without the same structural fixes Vulkan needs.**

From `app_architecture/platform/android/RENDER_BACKEND.md` and
`NATIVE_HOST_CONTRACT.md`:

- Surfaces are **ephemeral** (`ANativeWindow`, image-queue semantics); desktop
  SDL window assumptions already do not transfer directly.

- A contract that still leaks **desktop GL immediacy**, **Metal queue replay**,
  or **FBO-shaped** retained targets forces mobile to either **fork** shared
  code or **pretend** GLES/Vulkan-KHR matches desktop OpenGL—both are the
  “contract was desktop-shaped” failure mode the target contract explicitly
  forbids.

**Pressure test:** If Android had to ship tomorrow, the honest shared layer is
still **host geometry + neutral draw/present intent**. The current **uneven**
backend implementations would require **the same** closure work as Vulkan:
neutral submission, neutral presentable storage semantics, backend-owned GPU
objects.

---

## Relationship to Milestone B (backend closure)

Review Chunk 2 was **not** approved as complete; partial cleanup does not change
this audit’s conclusion. **Milestone B exit criteria remain the real
prerequisite** for a honest “Vulkan is routine” claim—even if this audit is
delivered earlier as **evidence** for planning Chunk 2 continuation.

---

## Top blockers before any Vulkan bootstrap (ordered)

1. **Unify surface-draw submission** so OpenGL, Metal, and a future Vulkan path
   implement the **same** contract (no “immediate vs replay” as a product
   fork).
2. **Opaque or unified GPU resource handles** in draw payloads (no growing
   `.opengl` / `.metal` / `.vulkan` enum sprawl in shared code).
3. **Presentable lifecycle parity** behind neutral types (not GL FBO as the
   implicit reference implementation).
4. **Move backend-native runtime storage** off `Renderer` or narrow the host to
   opaque backend context (so “add Vulkan” does not mean “add another peer
   bundle”).
5. **Single backend-owned frame lifecycle seam** so `Renderer` is not the
   dispatch center for three different GPU models.

---

## Exact review questions (for maintainers)

1. Is the **enqueue immediate vs enqueue replay** split acceptable as a **permanent**
   backend policy, or must the product layer see **one** record-then-present
   model?
2. Should the next Chunk 2 continuation **prioritize draw unification** or
   **presentable parity** first—given both block Vulkan and mobile?
3. Do we require an **opaque `GpuTexture` / `BackendImage`** handle in shared
   code before any `vulkan` backend exists, to avoid a third handle variant?

---

## References

- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` (Vulkan as fit audit, not lane)
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
