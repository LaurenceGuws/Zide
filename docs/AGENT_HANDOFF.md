## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Product Identity (permanent)

See `app_architecture/ENGINEERING.md` § "Product Identity" for the full
statement. The short version:

- The core is pure Zig — ruthlessly clean, fast, lean. No single platform
  shapes it.
- Native implementations are first-class, not wrappers. Each targets the most
  competitive version of Zide on its platform.
- No fallbacks, no stale code, no compromise for delivery speed.
- The renderer backend abstraction is intentionally open-ended — it adapts to
  proved truth, not speculation.

### Current Focus

Get native Android rendering working. That means completing renderer gate #5
so the backend abstraction is clean enough for a first-class Android GLES
backend.

- Active ticket: `AR-B3` / `RB-B3.h`
  - editor row/overlay composition phase boundary
  - owner: `app_architecture/ui/EDITOR_COMPOSITION_PHASE_PLAN.md`
- `RB-B3.d` is already met:
  - widget/runtime no longer calls `usesDirectTerminalPresentation(...)`
  - those path decisions now terminate in the presentable host seam
- `RB-B3.f` is met for scanned shell/UI chrome-band composition:
  - side-nav, status-bar, top-bar, tab-bar, config notice, and integrated
    window-caption paths now route through explicit band composition seams
- `RB-B3.g` is met for terminal overlay/progress composition:
  - close-confirm modal, progress bar, scrollbar thumb, and terminal separator
    now route through a terminal-owned composition seam
- `RB-B3.e` is now structurally narrowed enough that it is no longer the
  strongest blocker:
  - presentable lifecycle parity work materially reduced direct-vs-retained
    shared pressure
  - the stronger remaining renderer pressure is the text/surface
    phase-boundary problem
- Renderer work is in scope only when it is the direct next blocker — not for
  generic cleanup
- `AS-A3` (modifier-latch input UX) is parked open — works well enough now,
  do not polish or let it block rendering progress
- Gate #2 (Metal live verification) is paused; do not let it stall Android

### Current State

- Android foundation is real on the Note10:
  - lifecycle, surface identity, EGL surface recreation all proved
  - disposable app-process-owned PTY lifetime is the baseline
  - live shell via terminal engine, key-by-key PTY input via `InputConnection`
  - app identity: `dev.zide.terminal` / `ZideTerminalActivity`
  - repo path: `android/terminal-host/`
- Ownership boundary:
  - Zig owns terminal/runtime/core rendering primitives
  - Android owns lifecycle/input/insets/overlay surfaces
- Renderer gate status: #1–#4 met, #5 active blocker, #2 deferred

### Where To Look

- Active execution queue:
  - `docs/todo/android/implementation.md`
- Android authority:
  - `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
  - `app_architecture/platform/android/RENDER_BACKEND.md`
  - `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
  - `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
  - `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- Renderer dependency authority:
  - `docs/todo/ui/renderer.md`
  - `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
  - `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

### Deferred Focuses

- VT maturity purity is deferred as the repo-wide default focus.
- When that lane is resumed, start from:
  - `docs/deferred/VT_MATURITY_FOCUS.md`
  - `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
  - `app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the
  relevant `app_architecture/` authority docs.
- Do not let older renderer-campaign framing outrank the Android queue while
  Android terminal excellence is the active goal.
- Do not work directly on `main`; treat it as merge-only and start active work
  on a branch from current `main`.
- Weaker agents must stay on feature branches and keep small reviewable
  checkpoint commits; `main` should only move when the lead accepts a validated
  chunk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
