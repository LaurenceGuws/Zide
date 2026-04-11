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

Get native Android rendering working through the shared renderer path. Renderer
gate #5 is no longer the live blocker; the active next move is first live
terminal-grid ownership on the shared Android GLES path.

- Active ticket: `AR-B4.e`
  - Android GLES first live terminal-grid ownership
  - owner: `docs/todo/android/implementation.md`
  - current state:
    backend/runtime/frame binding is in, `AR-B4.b` external-host bootstrap is
    met, `AR-B4.c` first shared solid replay is met, and `AR-B4.d` minimal
    terminal rect/glyph replay is now met on-device; the next direct blocker is
    no longer backend visibility but product ownership still living in the Java
    transcript overlay instead of the shared renderer
- `RB-B3.d` is already met:
  - widget/runtime no longer calls `usesDirectTerminalPresentation(...)`
  - those path decisions now terminate in the presentable host seam
- `RB-B3.f` is met for scanned shell/UI chrome-band composition:
  - side-nav, status-bar, top-bar, tab-bar, config notice, and integrated
    window-caption paths now route through explicit band composition seams
- `RB-B3.g` is met for terminal overlay/progress composition:
  - close-confirm modal, progress bar, scrollbar thumb, and terminal separator
    now route through a terminal-owned composition seam
- `RB-B3.h` is met for editor row/overlay composition:
  - immediate editor helpers now route through the editor overlay/row-band owner
  - generic tooltip overlay composition now terminates in
    `renderer_tooltip_host.zig`
- `RB-B3.i` is met for sample/diagnostic section composition:
  - font sample section chrome now routes through `font_sample_section_host.zig`
- Next active move is `AR-B4`:
  - first controlled Android GLES backend implementation slice
  - authority: `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`
- `RB-B3.e` is now structurally narrowed enough that it is no longer the
  strongest blocker:
  - presentable lifecycle parity work materially reduced direct-vs-retained
    shared pressure
  - the stronger remaining renderer pressure is the text/surface
    phase-boundary problem
- Renderer work is in scope only when it is the direct next blocker — not for
  generic cleanup
- `AS-A3` (modifier-latch input UX) is parked open — works well enough now, do
  not polish or let it block rendering progress
- Gate #2 (Metal live verification) is paused; do not let it stall Android

### Current State

- Android foundation is real on the Note10:
  - lifecycle, surface identity, EGL surface recreation all proved
  - disposable app-process-owned PTY lifetime is the baseline
  - live shell via terminal engine, key-by-key PTY input via `InputConnection`
  - app identity: `dev.zide.terminal` / `ZideTerminalActivity`
  - repo path: `android/terminal-host/`
  - native bridge build path:
    `zig build android-terminal-host-bridge -Dtarget=aarch64-linux-android
    -Dmode=terminal --sysroot <ndk-sysroot>`
- Ownership boundary:
  - Zig owns terminal/runtime/core rendering primitives
  - Android owns lifecycle/input/insets/overlay surfaces
- Android GLES device truth now also includes:
  - visible shared clear/swap in terminal-host product view
  - `SurfaceDraw.solid` replay on-device
  - minimal terminal rect/glyph-rect replay on-device
  - the visible-output blocker was the host `SurfaceView` defaulting to
    `RGB_565`; terminal-host now requests `RGBA_8888`, and the shared EGL
    runtime also applies the config visual format to the `ANativeWindow`
- Renderer gate status: #1–#5 structurally met for active Android planning,
  #2 live Metal verification deferred until Mac access returns

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
