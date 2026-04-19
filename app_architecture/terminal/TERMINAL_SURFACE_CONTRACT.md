# Terminal Surface Contract (host-agnostic)

Date: 2026-04-19

Purpose: freeze the **terminal surface** layer that sits between **native host
surface availability** (`app_architecture/platform/NATIVE_HOST_CONTRACT.md`) and
**renderer backend mechanics** (`app_architecture/ui/RENDER_BACKEND_CONTRACT.md`).
Android was the proving ground for “host gives a window/surface; Zide drives
terminal truth and redraw bookkeeping” — but **Android is one host**, not the
contract.

This doc is authority for what must stay true on every first-class platform
that embeds the terminal widget + GPU path.

## What “surface” means here

“Surface” is the **host-provided drawable attachment** for the terminal’s GPU
presentation path: native window/view, swapchain or equivalent, and the
lifecycle events that accompany it (resize, loss, replacement). It is **not**
the terminal snapshot buffer and **not** the FFI struct mirror of cells — those
live in **publication / VT core FFI**.

## Ownership split (frozen)

| Concern | Owner |
| --- | --- |
| Obtaining and handing a native GPU surface/window into the renderer backend | **Host** (`PlatformRenderHost` / platform glue) |
| Binding backend context/devices/queues to that surface | **Host + `RendererBackend`** — mechanics stay backend-local per `RENDER_BACKEND_CONTRACT` |
| Terminal **semantic** state, scrollback, damage at the engine/publication layer | **Zide terminal stack** (`TerminalCore` + publication) |
| **Dirty tracking** for “what changed since last publish”, **published generation**, **needs_redraw**, **present generation** pairing | **Zide** — hosts must not invent parallel damage truth |
| Turning publication/snapshot into draw work and scheduling redraw | **Zide renderer + terminal widget** (shared product path) |
| **Presenting** a frame to the user and reporting **presentation completion** back into the terminal bridge | **Host** — but completion is reported through the **shared FFI present-ack** so Zide can retire generations honestly |

Interpretation:

- The **host** passes **whatever opaque or typed surface handle** the active
  backend requires; Zide does not standardize GLES vs Metal vs Vulkan objects
  here — that belongs to `RENDER_BACKEND_CONTRACT`.
- **Zide** owns the **update/dirty contract**: when the terminal must redraw,
  which generation is current, and how present ack advances acknowledged
  generation. Foreign hosts consume the same FFI fields as native.
- The **host** owns **when** a frame hits the screen and **which** native
  surface is current; it must not replace that responsibility with ad hoc
  snapshot polling as a substitute for honest present feedback.

## FFI touchpoints (read-only contract, not behavior change)

Hosts observe terminal publication and redraw through the **VT core FFI**
(`src/terminal/ffi/**`): e.g. `needs_redraw`, `redraw_state`, `published_generation`,
`present_ack` / `acknowledged_generation`. Those symbols are the portable surface
for “has the terminal advanced its frame contract” — separate from GLES/Metal
types which never cross the FFI boundary as raw GPU handles in the shared
design.

## Android mapping (example, not definition)

On Android, `ANativeWindow` / surface lifecycle flows through platform code; the
terminal FFI still speaks in **generations and acks**, not in JNI surface types.
If Android-specific glue peeks at GPU objects, that remains **platform-local**
and must not become a second publication truth.

## Non-goals

- Defining GLES vs Metal draw queues — see `RENDER_BACKEND_CONTRACT.md`.
- Defining JNI or Activity shape — platform docs + `NATIVE_HOST_CONTRACT.md`.
- Changing parser/engine semantics — `VT_CORE_DESIGN.md` / maturity campaign.

## Related documents

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md` — lifecycle + surface
  availability.
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md` — backend responsibilities
  and adoption gates.
- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — where publication
  and presentation meet.
