# Windows Implementation TODO

## Scope

Track the work required to make Windows a first-class native platform, not just
"it builds here sometimes".

The current execution order is:

1. native build/run truth
2. DPI + renderer correctness
3. text quality and font fallback quality
4. native workflow polish
5. installation/distribution

## Priorities

- Keep diffs small and reviewable.
- Preserve end-to-end Windows build and run smoke coverage.
- Treat Windows DPI and text rendering as product work, not incidental polish.
- Keep Windows-specific work in the owning queue as soon as the code and docs diverge.

## Entry Points

- `build.zig`
- `src/platform/*`
- `src/ui/renderer.zig`
- `src/ui/renderer/backends/*`
- `src/ui/renderer/text_runtime.zig`
- `src/ui/font/shaping.zig`
- `src/ui/terminal_font.zig`
- `src/terminal/io/pty_windows.zig`

## Baseline

- [x] Build produces a runnable `zig-out/bin/zide.exe` on Windows through the native Zig package-managed path.
- [x] Windows native dependency policy matches Linux/macOS at the app/library layer.
- [x] Windows ConPTY can spawn `cmd.exe` and pass a smoke test.
- [x] Editor text at fractional DPI is visually stable and competitive enough for current Windows product work.
- [x] Manual smoke coverage exists for editor-only, terminal-only, and default app mode on Windows.
- [x] Windows runtime/distribution flow is documented against the actual supported target policy.
- [x] Normal GUI launches on Windows do not create an attached console host window.

## Windows First-Class Fundamentals

- [ ] `WF-01` Lock the supported native Windows policy and stop drifting around it
  - Current intended policy:
    - native Windows target: `x86_64-windows-msvc`
    - app/library dependencies: Zig package-managed
    - no `vcpkg` fallback path
  - Exit criteria:
    - `build.zig`, `docs/DEPENDENCIES.md`, `app_architecture/DEPENDENCIES.md`, and bootstrap docs all say the same thing
    - no stale helper scripts or reports imply cache-path or `vcpkg` workarounds are still required

- [ ] `WF-02` Make DPI behavior explicit and testable on Windows
  - Current problem:
    - text/render behavior under `render_scale = 1.25` is still not trustworthy enough
  - First contract cut, 2026-03-19:
    - `src/platform/display_metrics.zig` is now the authoritative per-window
      display snapshot seam
    - renderer/font code now consumes that snapshot instead of pulling DPI and
      render scale through separate ad hoc reads
    - this is an extraction-only ownership fix, not the final fractional-DPI
      renderer fix
  - Current code-path finding, 2026-03-19:
    - Windows scale events already flow through SDL:
      - `SDL_EVENT_WINDOW_DISPLAY_CHANGED`
      - `SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED`
      - resize/pixel-size changes
    - `platform/window_metrics.zig` derives both `getDpiScale()` and
      `getRenderScale()` from SDL window display scale / pixel density.
    - `renderer.refreshUiScale()` responds to those changes and rebuilds fonts.
    - `ui_scale` is not currently "Windows DPI"; it is effectively an
      application/UI override lane (`ZIDE_UI_SCALE`) while native monitor DPI
      currently enters through `render_scale`.
    - So the remaining bug is not "Windows DPI events missing"; it is the
      renderer's fractional-DPI placement/sampling contract.
  - Contract correction, 2026-03-19:
    - `render_scale` should follow SDL pixel density / drawable ratio
    - Windows content scale should enlarge layout through `ui_scale`
    - this avoids rasterizing text at a content-inflated size and then
      effectively resampling it back into a 1x backbuffer on Windows
  - Current validated state, 2026-03-20:
    - on the current Windows machine, `125%` editor and terminal text are now
      user-accepted after the scale split fix
    - JetBrainsMono and IosevkaTerm both look correct enough on the corrected
      path that the shared Windows renderer bug is no longer blocking product
      work
    - the broader `100/125/150/175/200/250/300%` matrix still remains open
      under `WF-04` / `W3A-01`
  - Required checks:
    - window DPI acquisition path is explicit
    - `WM_DPICHANGED`/SDL display-scale changes rebuild fonts and layout predictably
    - editor/terminal/reference sample behavior is checked at 100/125/150/175/200/250/300%
  - Reference priority for the next pass:
    - `wezterm` for runtime render metrics and baseline/cell discipline
    - `alacritty` for runtime scale-factor/font-size updates
    - SDL renderer/view scale math for destination geometry rules
    - Windows DPI/DirectWrite docs for platform expectations

- [ ] `WF-03` Make Windows text quality a tracked product lane, not a side quest
  - Current evidence:
    - aggressive per-glyph snapping at fractional DPI caused dropped strokes and skew artifacts
    - remaining softness/fuzz points to a still-incomplete sampling/geometry contract
  - Required outputs:
    - a stable repro fixture/workflow
    - explicit acceptance criteria for Windows editor text quality
    - a narrowed queue in `docs/todo/ui/font_rendering.md`

- [ ] `WF-04` Add real Windows smoke coverage for the product shapes we claim to support
  - Required commands:
    - `zig build`
    - `zig build -Dmode=editor`
    - `zig build -Dmode=terminal`
  - Required manual checks:
    - window launch
    - text quality at 100/125/150/175/200/250/300%
    - resize/DPI move behavior
    - terminal spawn/input/exit
  - 2026-03-20 local signoff:
    - current Windows dev box manual coverage is accepted by the user for
      IDE/editor/terminal launch, shell spawn/input/exit, and the active DPI
      matrix exercised during the fractional-scaling fix lane

- [ ] `WF-05` Do not start installer work until runtime quality is acceptable
  - Packaging/install docs should wait until:
    - default Windows target policy is settled
    - text quality is acceptable
    - launch/runtime flow is stable without temporary policy workarounds

## Phases

### Phase 0 Docs and Baseline

- [x] `W0-01` Create the Windows implementation tracker
- [x] `W0-02` Fix doc drift so terminal design no longer claims ConPTY is a stub

### Phase 1 Terminal PTY Parity

- [x] `W1-01` Implement PTY lifecycle parity and wire `TerminalSession.isAlive()`
- [x] `W1-02` Honor configured shell path and command line on Windows ConPTY
- [x] `W1-03` Add graceful shutdown and exit-status plumbing for Windows ConPTY

### Phase 2 Renderer Backend

- [x] `W2-01` Wire `-Drenderer-backend` to real backend selection or fail cleanly
- [x] `W2-02` Decide WGL vs SDL-managed GL
  Current decision: SDL-managed GL remains the only selectable backend; WGL/EGL stay as non-selectable placeholders.
- [ ] `W2-03` Expand renderer validation into a Windows DPI/present contract review
  - The old "renderer smoke test" wording is too weak.
  - Required checks now include:
    - SDL display-scale changes
    - fractional-DPI text behavior
    - resize/present-loop stability
    - terminal/editor parity under the same render-scale changes

### Phase 3 Font Fallback

- [x] `W3-01` Implement Windows system font fallback
  DirectWrite-based fallback resolution is in place, with a fast path through well-known `%WINDIR%\\Fonts` entries.

### Phase 3A Text Rendering Quality

- [ ] `W3A-01` Replace guesswork with a Windows text-quality fixture lane
  - Own the reference material under `reference_repos/windows_docs/`
  - Cross-platform implementation references for this lane:
    - `reference_repos/terminals/wezterm/wezterm-gui/src/`
    - `reference_repos/terminals/alacritty/alacritty/src/`
    - `reference_repos/backends/sdl/src/render/SDL_render.c`
  - Keep `.zide.lua` logging minimal and bug-scoped
  - Maintain a repeatable retest script and comparison text/sample workflow
- [x] `W3A-02` Finish the fractional-DPI glyph placement contract
  - Keep the no-per-glyph-snap fix that removed dropped-stroke artifacts
  - Audit destination-quad sizing, baseline stability, and atlas sampling together
  - Preferred implementation order:
    - explicit scaled metric set
      - 2026-03-19: landed initial renderer-owned `ScaledFontMetrics`
        (`cell_width`, `cell_height`, `baseline_from_top`) for terminal/icon
        fonts; main editor/terminal baseline consumers now read the shared
        scaled snapshot instead of recomputing baseline from raw font fields
      - terminal widget/grid consumers now also read the shared snapshot for
        cell geometry instead of mixing direct `terminal_cell_*` scalars with
        raw font-derived baseline math
      - the shared snapshot now carries rounded ascent/descent/line-height too,
        so the next pass can tune baseline/cell/underline relationships from
        one metric set instead of inventing more one-off renderer math
    - baseline/cell metric consistency
    - destination quad extent quantization
    - atlas UV/sampling cleanup only after geometry is stable
  - Validated state, 2026-03-20:
    - current Windows `125%` editor and terminal rendering are user-accepted
      after the corrected scale split and geometry passes
    - remaining work moves to fixture authority, native reference comparison,
      and startup churn cleanup rather than core glyph placement triage
- [ ] `W3A-03` Verify editor text against Windows-native expectations
  - Compare against reference apps at the same font/size/DPI
  - Explicitly decide whether grayscale-only is good enough or whether an opt-in LCD/subpixel path is needed on Windows
- [ ] `W3A-04` Stabilize metric rebuild behavior
  - Current logs show metric transitions during startup/rebuild
  - The queue should end with one predictable font-init/rebuild contract, not multiple implicit phases
  - Cleanup landed, 2026-03-20:
    - startup now seeds renderer font path, size, and font-render settings from
      loaded config before the first font init
    - this removes the old "boot JetBrains, then switch to configured face"
      churn from normal startup

### Phase 4 Process Signals

- [x] `W4-01` Implement Windows Ctrl+C and close handling

### Phase 5 Tooling

- [x] `W5-01` Make bootstrap and grammar-pack flows work on Windows
  Grammar update now has a native PowerShell + Python path; bootstrap also has a PowerShell path.

### Phase 6 Quality of Life

- [x] `W6-01` Add native Windows file dialogs
- [x] `W6-02` Establish native Windows launcher identity
  - real PE resource metadata is now embedded per launcher
  - runtime AppUserModelID is now explicit per launcher
  - SDL app name/app id defaults now follow the owning launcher identity

### Phase 7 Policy Cleanup

- [x] `W7-01` Mark Windows CI work obsolete
  Project policy is local/manual validation only.

### Phase 8 Install/Distribution

- [x] `W8-01` Document the supported Windows runtime layout
  - binary shape
  - required runtime files
  - expected launch location/policy assumptions
- [x] `W8-02` Choose the first distribution method only after quality sign-off
  - chosen first path: per-user PowerShell installer
  - release zips remain the published artifact format
  - installer/package manager work later
- [x] `W8-03` Make Start Menu launchers carry native Windows shell defaults
  - installed launchers now accept terminal override args safely across IDE,
    editor, and terminal entrypoints
  - shared terminal shell/cwd policy is now owned by config rather than forced
    by installer defaults
  - installer may still stamp explicit `--shell` / `--cwd` args when requested
  - Windows ConPTY launch now also passes the resolved cwd to
    `CreateProcessW`, so installed terminals do not open in the install root

### Phase 9 Terminal-Only Native Chrome

- [x] `W9-01` Define the terminal-only Windows chrome contract before coding
  - Scope:
    - terminal-only mode should support two chrome policies:
      - `native`: ordinary Windows frame/titlebar
      - `integrated`: Zide terminal tab strip and drag region integrated into
        one top titlebar band
    - the first implementation target is Windows
    - IDE/editor modes stay on the current non-integrated path until
      terminal-only behavior is proven
  - Non-goals for the first cut:
    - no editor/IDE titlebar merge
    - no cross-platform generic custom-chrome project
    - no hidden coupling to the existing terminal tab width setting

- [x] `W9-02` Add a real config contract for terminal-only chrome mode
  - Intended direction:
    - `terminal.window_chrome.mode = "native" | "integrated"`
  - Required interaction rules:
    - `native` preserves the current content-row terminal tab bar behavior
    - `integrated` is a compact titlebar-tab presentation and must not use the
      current wide/fill behavior that consumes the whole row like content chrome
    - if `terminal.tab_bar.width_mode` remains user-visible, runtime must
      reject/normalize incompatible values under integrated mode or expose a
      separate compact integrated-width policy
  - Current state:
    - the config surface now exists in Lua defaults, parser, init, and reload
    - the current cut is intentionally no-behavior-change; the first runtime
      consumer is the upcoming Windows titlebar/hit-test implementation

- [ ] `W9-03` Establish the Windows titlebar/hit-test seam for terminal-only mode
  - Required capabilities:
    - draggable caption region
    - native resize borders/corners
    - minimize/maximize/close behavior
    - correct maximized padding/insets
  - The config surface should stay platform-capable; only the first runtime
    implementation is Windows-specific

- [ ] `W9-04` Merge terminal tabs into the titlebar band without preserving the old full-width tab-row assumption
  - Current blocker:
    - terminal-only layout still reserves a normal full-width tab row at `y=0`
    - terminal defaults still prefer `terminal.tab_bar.width_mode = "dynamic"`
    - that is incompatible with a Windows Terminal-like integrated titlebar
      where tabs should read as compact chrome rather than stretched content
      chips
  - First-cut acceptance:
    - integrated mode uses compact tab chips
    - terminal content begins directly below the merged titlebar band
    - tab drag/reorder/close behavior remains correct

- [ ] `W9-05` Add manual signoff for both native and integrated terminal-only chrome
  - Required manual checks:
    - native mode launch, drag, maximize, resize, and tab behavior
    - integrated mode launch, drag, maximize, resize, tab reorder, and close
    - switching config between `native` and `integrated`
