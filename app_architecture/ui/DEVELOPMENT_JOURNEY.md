# UI Development Journey (Rendering Stack)

Purpose: describe the current rendering journey at a high level without
competing with the active renderer ticket queue.

Use this doc for orientation. Use `docs/todo/ui/renderer.md` for execution.

## Current Journey

Zide is no longer in a vague "many backends someday" phase.

It is in a renderer backend contract campaign with one immediate goal:

- architect and enforce a reference-grade backend abstraction

The current shape of that journey is:

1. prove the contract on Linux OpenGL
2. keep Metal honest as the second reference implementation
3. close the contract gaps that still leave `renderer.zig` as the hidden
   backend center
4. audit Vulkan fit only after the contract is strong
5. keep Android/mobile as pressure on the contract, not as active implementation
   drift

## Current Priorities

### 1. Linux GL is the proving ground

Linux GL is currently the best available place to expose contract weakness in:

- focus and input truth
- scale and geometry truth
- redraw and presentable ownership
- terminal resize and scrollback correctness

This does not mean OpenGL defines the contract.

It means Linux GL is the best place to test whether the contract is honest.

### 2. Metal remains a reference implementation

The macOS/Metal lane started the backend-contract journey and remains a
required reference implementation.

Current live Metal validation is paused, but the architecture standard did not
revert to "GL first, Metal later."

The standard remains:

- OpenGL and Metal must satisfy one shared contract

### 3. Vulkan is a fit audit, not an active implementation lane

Do not start real Vulkan work until the renderer contract is strong enough that
the Vulkan shape reads like routine backend work.

If Vulkan still looks like it needs renderer surgery, the contract is not done.

### 4. Android/mobile is future pressure, not current implementation work

Android matters because it pressures the host and renderer contracts away from
desktop-GL assumptions.

That does not mean "start Android now."

It means current contract work must avoid creating a renderer shape that a
future Android/mobile path would have to route around.

## Ownership Map

- execution queue:
  - `docs/todo/ui/renderer.md`
- target contract authority:
  - `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- current-state contract audit:
  - `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- native-host pressure:
  - `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- macOS renderer pressure:
  - `app_architecture/platform/macos/RENDER_BACKEND.md`
- Android/mobile pressure:
  - `app_architecture/platform/android/RENDER_BACKEND.md`
- scale and geometry pressure:
  - `app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md`

## Design Rules For The Journey

- backend choice must change implementation, not architecture
- OpenGL must not receive privileged contract shape just because it is mature
- Metal must not be treated as a side experiment
- Vulkan must not be used as an excuse to keep vague contracts vague
- Android/mobile must influence contract honesty without hijacking the current
  lane

## What This Doc Should Not Become

- not a changelog
- not the active ticket queue
- not a per-platform implementation diary
- not a substitute for `docs/todo/ui/renderer.md`

## Practical Reading Order

1. `docs/AGENT_HANDOFF.md`
2. `docs/todo/ui/renderer.md`
3. `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
4. `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
5. platform-specific pressure docs only if the active ticket needs them
