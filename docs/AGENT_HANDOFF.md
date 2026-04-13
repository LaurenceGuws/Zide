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

Android terminal excellence is the active product goal again. The Android pinch
/ resize-pressure lane is accepted and parked for now, but the broader
render-thread cleanup campaign is still active whenever it is the next direct
blocker for Android terminal progress.

- Active ticket: `AN-A1` interactive Neovim terminal baseline
  - owner:
    `docs/todo/android/implementation.md`
    `app_architecture/platform/android/ANDROID_USERLAND_BOOTSTRAP_PLAN.md`
    sibling mobile package authority repo: `../zide-mobile-pm`
  - current state:
    Android now has a real terminal-host package/userland foundation: in-app
    artifact install/update, explicit staged-state reporting, staged `zide-pm`,
    one app-owned package action, clean Bash startup, and a curated
    terminal-dev baseline. `AU-A2` and `AU-A3` are met for the current
    foundation. Android-native text interaction is now real too: floating text
    toolbar, clipboard copy, drag expansion, autoscroll, and Android-owned
    selection handles over the GPU terminal surface. The Java host is now
    split across explicit controllers:
    `dev.zide.terminal.selection.TerminalSelectionController`,
    `dev.zide.terminal.debug.TerminalStatusController`,
    `dev.zide.terminal.host.TerminalSurfaceHostController`,
    `dev.zide.terminal.host.TerminalChromeController`,
    `dev.zide.terminal.host.TerminalViewportController`, and the userland
    workflow/session controllers. The next Android cleanup is further
    reduction of `ZideTerminalActivity` breadth while continuing the
    Neovim/mobile-terminal product baseline.
- Accepted Android renderer checkpoint:
  - pinch / resize-pressure responsiveness is now accepted on the current
    release-build terminal-host path
  - do not reopen Android gesture tuning unless a new concrete product
    regression appears
  - the enduring output of that lane is renderer-core cleanup:
    size-keyed terminal font caching, async visible-glyph prep, CPU-prepared
    terminal font state, committed-target cache population, and prepared-target
    promotion after adopt
- Renderer checkpoint:
  - ordinary UI/editor text, terminal glyph batching, and `SurfaceDraw` blit
    replay now carry background explicitly
  - `Renderer.TextRenderState.bg_rgba` is gone
  - terminal presentable refresh/update execution now carries
    `TerminalPresentPlan` geometry to backend-owned refresh mechanics
  - Metal snapshot presentables no longer guess logical size from drawable
    state
  - remaining presentable risk is live Metal verification of the
    refresh-backed snapshot path, not another known Linux/shared-code cleanup
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
- `AR-B4.g` is now met:
  - terminal-host opts into `ADJUST_RESIZE`
  - Java reports the effective visible product viewport into native code
  - the shared terminal widget/grid now sizes from that visible viewport
  - Note10 validation now proves IME-open shrink and IME-hide restore on the
    shared Android GLES path
- `RB-B3.e` is now structurally narrowed enough to park local Linux-only
  cleanup:
  - presentable lifecycle parity work materially reduced direct-vs-retained
    shared pressure
  - remaining risk is Mac/Metal verification or a concrete new product blocker
- Renderer work is in scope only when it is the direct next blocker — not for
  generic cleanup
- Current renderer-thread front after pinch:
  - keep removing render-thread ownership violations from the audited queue
  - render-entry, resize/grid-fit, presentation-runtime, and backend
    frame-mechanics ownership are materially narrowed enough to stop forcing
    symmetry cleanup
  - next priority is not more Android gesture work; it is the next direct
    Android product blocker, with renderer-thread work reopening only for a
    concrete shared offender
- Android renderer/backend work should now reopen only if a concrete product
  blocker proves the shared path still lacks required capability
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
  - Linux-host userland bootstrap tooling now exists:
    - `./ops/android_terminal_host.py userland-fetch-ref`
    - `./ops/android_terminal_host.py userland-inspect`
    - `./ops/android_terminal_host.py userland-stage`
    - `./ops/android_terminal_host.py userland-stage-artifact`
    - `./ops/android_terminal_host.py userland-stage-packages neovim htop gotop`
    - `./ops/android_terminal_host.py userland-bash-version`
    - `./ops/android_terminal_host.py userland-apt-update`
  - Current AU-A1 device truth:
    - staged Bash 5.3.9 runs under `run-as`
    - staged Bash is also the live product shell on the SDK 28 terminal-host
      path; device proof shows the shared-renderer shell prompt and `pwd`
      running under Bash from the staged prefix
    - `apt-get update` refreshes package metadata with relocation overrides
    - `zide-pm-admin` publishes the current Android dev snapshot prerelease in
      `../zide-mobile-pm`;
      `userland-stage-artifact` verifies the manifest/archive and stages the
      prefix without parsing provider package internals
    - provider model is explicit:
      `termux-main` is the first supported Android provider, not the product
      identity; future Zide-owned providers can replace the default without
      changing `zide-pm`
    - latest published dev snapshot now contains and device-proves Bash 5.3.9,
      Neovim 0.12.1, Git 2.53.0, ripgrep 15.1.0-1, `htop` 3.5.0, and `gotop`
      4.2.0
    - the current published snapshot is `android-dev-2026.04.12.193048`
    - `./ops/android_terminal_host.py userland-smoke-baseline` repeats the
      staged-device smoke for Bash, Git, ripgrep, Neovim, htop/gotop, and
      `zide-pm`
    - product Install/Update now fetches that published manifest/archive
      contract in-app
    - device validation now also proves the staged prefix contains and runs
      `zide-pm` under `run-as dev.zide.terminal`
    - fresh terminal-host launch after artifact staging reports shell start and
      a Bash child under `dev.zide.terminal`
    - host-side `.deb` extraction/relocation remains available as explicit
      dev-provider tooling for investigation
    - `btop` is not present in the current Termux main aarch64 package index
    - direct on-device `apt-get install` is blocked by Termux package payloads
      rooted under `/data/data/com.termux/...`
    - terminal-host target SDK 28 is intentional product policy for the Bash
      userland lane, not stale Android configuration
    - `../zide-mobile-pm` is the producer/manifest owner; Zide should consume
      pinned artifacts, not package internals
- Ownership boundary:
  - Zig owns terminal/runtime/core rendering primitives
  - Android owns lifecycle/input/insets/overlay surfaces
- Android GLES device truth now also includes:
  - visible shared clear/swap in terminal-host product view
  - `SurfaceDraw.solid` replay on-device
  - minimal terminal rect/glyph-rect replay on-device
  - live shared-renderer shell ownership in product view without a Java text
    fallback
  - readable live shell text/prompt replay through atlas glyph rendering on
    the shared Android GLES path
  - product-fit live shell sizing from the real renderer surface instead of a
    fixed bootstrap grid island
  - IME-open now shrinks the live product surface/viewport and IME-hide
    restores it on-device through the shared Android renderer path
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
  - `app_architecture/platform/android/ANDROID_RENDER_THREAD_CONTRACT.md`
  - `app_architecture/platform/android/ANDROID_USERLAND_BOOTSTRAP_PLAN.md`
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
- Do not let older renderer-campaign framing or finished input polish outrank
  the Android queue while Android terminal excellence is the active goal.
- Work on `main` by default unless the user explicitly asks for a branch.
- If a branch is explicitly requested, keep small reviewable checkpoint commits
  and merge back to `main` only after a validated chunk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
