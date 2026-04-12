# Android Terminal Queue

This is the active execution queue for Android terminal work.

Use this queue for:

- Android host/runtime work
- Android PTY/runtime lifetime work
- Android renderer-unblocking work when Android is the forcing function
- Android terminal product decisions and sequencing

Do not use this queue for:

- generic renderer cleanup with no Android leverage
- desktop-only work with no Android leverage
- speculative backend work that bypasses the queue's current blocker notes

## Owner Docs

- `app_architecture/platform/NATIVE_HOST_CONTRACT.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BACKEND_PLAN.md`
- `app_architecture/platform/android/ANDROID_GLES_BINDING_PLAN.md`
- `app_architecture/platform/android/ANDROID_USERLAND_BOOTSTRAP_PLAN.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `docs/todo/ui/renderer.md` (for the pre-Android rendering gate)

## Current Rule

Android terminal excellence is the active repo goal until further notice.

Current boundary:

- the Android-native terminal-host lane is structurally complete enough to
  stop being the main unknown
- disposable app-process-owned PTY lifetime is the current Android terminal
  baseline
- service-owned PTY survival is now a validated separate Android product lane,
  but it has not displaced the disposable baseline as the default answer
- terminal-host-owned EGL/GLES proof is now strong enough that it is no longer the
  main unknown either
- shared Android renderer/backend proof is now strong enough that it should
  reopen only if a concrete product blocker proves a missing capability
- renderer work is only in scope here when it becomes the next
  highest-leverage Android blocker again
- product sequencing is explicit:
  - mobile terminal first
  - extract reusable mobile-native fundamentals while building it
  - mobile editor second
  - integrated IDE mode only after both products are mature enough to compose
- packaging is intentionally undecided:
  - do not assume one all-in-one APK is correct yet
  - do not assume split products are correct yet
  - keep terminal/editor/mobile fundamentals loosely coupled enough to support
    either decision later
- platform-native mobile UX is in scope:
  - do not force all product behavior into Zig or into the GPU texture path
  - keep terminal truth and shared runtime semantics in Zig
  - let Android own Android-native overlays, insets, gestures, and similar
    interaction surfaces where that is the better product fit

## Priority Rule

When choosing what to do next, rank work like this:

1. the highest-leverage blocker to a first-class Android terminal
2. if that blocker is Android-owned, execute it from this queue
3. if that blocker is a renderer gate, execute the exact renderer ticket that
   unblocks Android and then return here

Product sequencing rule:

1. finish mobile terminal to a strong standalone product
2. extract reusable mobile fundamentals while doing that
3. only then open the mobile editor product lane
4. only after both are mature, open integrated mobile IDE work

Do not drift back into renderer cleanup just because renderer docs are more
developed.

## Current Biggest Blocker

The renderer gate-5 composition cleanup is no longer the biggest Android
blocker.

Current blocker:

- backend bring-up is no longer the loud Android blocker
- current input assistance is now good enough locally to stop outranking a
  stronger product gap
- app-private Bash is now the live product shell on the SDK 28 terminal-host
  path
- the next strongest Android product gap is package authority for the Zide
  prefix

That means:

- gate #2 is treated as closed for active work until Metal validation is
  explicitly reopened
- gate #4 is met
- gate #5 is structurally met for scanned composition families
- Android terminal-host/product work should now continue only where it closes
  the package/userland gap or a concrete terminal product blocker

## Current Priority

**`AN-A1` Interactive Neovim Terminal Baseline** — this is the active Android
ticket now.

`AU-A2` and `AU-A3` are met for the current foundation: install/update is
app-owned, artifact-contract-only, stateful, and the staged prefix now
device-proves a curated terminal-dev baseline. The next highest-leverage move
is proving interactive Neovim behavior in the live terminal surface rather than
broadening package curation.

Owner docs:

- `app_architecture/platform/android/ANDROID_USERLAND_BOOTSTRAP_PLAN.md`
- `docs/research/terminal/ANDROID_USERLAND_EXEC_POLICY_2026-04-11.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- sibling mobile package authority repo: `../zide-mobile-pm`

Guardrails:

- do not drift back into Android host/tooling cleanup
- do not invent a custom Android package manager
- do not depend on the external Termux app as product infrastructure
- do not claim unmodified `com.termux` package payloads are product-correct for
  `dev.zide.terminal`
- keep the live `InputConnection` path as the single active input surface
- keep Java focused on bootstrap/progress/lifecycle ownership; do not move the
  core shell/runtime semantics out of Zig
- keep terminal-host consuming the published artifact contract; provider
  package internals stay in `../zide-mobile-pm` / dev-provider tooling
- do not broaden into package curation beyond the first terminal-dev baseline
- do not start mobile IDE/editor product work yet; this ticket is terminal
  behavior under Neovim, not Zide editor mode

Current checkpoint:

- Linux-host bootstrap staging is now real:
  - `./ops/android_terminal_host.py userland-fetch-ref`
  - `./ops/android_terminal_host.py userland-inspect`
  - `./ops/android_terminal_host.py userland-stage`
- the current upstream bootstrap is better than the earlier assumption:
  - staged Bash runs on the Note10 via `run-as`
  - after the SDK 28 target cut, the live product shell launches staged Bash
    from the app process
  - device proof: staged Bash is the live product shell and `pwd` runs from
    that shared-renderer shell
  - staged `apt-get update` can be relocated far enough to refresh package
    metadata on-device
  - Linux-host package staging can now materialize selected Termux `.deb`
    payloads into the Zide app-private prefix for development
- the current upstream package flow is still not product-ready:
  - direct on-device `apt-get install` is blocked because Termux packages
    unpack under `/data/data/com.termux/...`, which this app cannot own
  - host-side `.deb` extraction/relocation is a dev bootstrap tool, not the
    final package-manager contract
- the first curated Android dev snapshot prerelease from
  `../zide-mobile-pm` now exists:
  - manifest:
    `https://github.com/LaurenceGuws/zide-mobile-pm/releases/download/android-dev-2026.04.12.193048/android-dev-prefix.release.manifest.json`
  - Zide command:
    `./ops/android_terminal_host.py userland-stage-artifact`
  - the command verifies package/prefix/provider metadata, downloads the
    release-local archive asset, verifies size/SHA-256, and stages only the
    `android-prefix-archive` contract into the app-private files directory
  - terminal-host now reads `.zide-userland-bootstrap.json` before blind
    auto-start and reports blocked userland readiness honestly when the staged
    prefix is missing/invalid/not launchable
  - `./ops/android_terminal_host.py userland-state` now reports the staged
    device userland state, and `userland-stage-artifact` skips restaging when
    the same ready artifact/version/provider is already installed unless
    `--force` is used
  - product view now shows a bootstrap blocker when staged userland is missing,
    invalid, or not launchable, with direct Retry and Open Debug actions
  - terminal-host now distinguishes `ready-current` vs
    `ready-upgrade-needed` against the pinned requested dev artifact identity
  - terminal-host now owns the first in-app artifact install/update path:
    it fetches the published manifest/archive contract, verifies size/SHA-256,
    extracts the prefix into app-private storage, and rewrites the local
    userland stamp
  - `userland-stage-artifact` and the in-app installer now consume
    `runtime_support_links` from the artifact manifest; shortened app-owned
    paths produced by binary relocation are materialized as symlinks instead
    of hardcoded in Zig or Java
  - blocker/debug surfaces now also carry explicit install state:
    `idle`, `installing`, `failed`
  - Note10 validation proves the artifact-staged prefix:
    - Bash 5.3.9
    - Neovim 0.12.1
    - `nvim --headless +qall`
    - Git 2.53.0
    - ripgrep 15.1.0-1
    - `htop` 3.5.0
    - `gotop` 4.2.0
  - the current published snapshot is now
    `android-dev-2026.04.12.193048`
  - the snapshot contract is now owned in one checked-in descriptor:
    `android/terminal-host/app/src/main/assets/userland_release.json`
  - terminal-host in-app `Update` now installs that snapshot from the
    published manifest/archive contract
  - device validation now also proves the staged prefix contains and runs
    `zide-pm`:
    - `zide-pm doctor --prefix /data/user/0/dev.zide.terminal/files/usr`
    - `zide-pm list-available --prefix /data/user/0/dev.zide.terminal/files/usr`
  - product host now exposes one app-owned package action through the hidden
    sidebar:
    `Packages` runs `zide-pm doctor` plus `zide-pm list-available` against the
    installed prefix and surfaces the result in debug view
  - fresh terminal-host launch after artifact staging reports
    `auto.shellStart status=started` and a Bash child under `dev.zide.terminal`
- product posture is now explicit:
  terminal-host targets SDK 28 until a modern-target userland execution model
  is proven
- `../zide-mobile-pm` is the mobile package authority boundary;
  Zide-side Termux package staging remains temporary dev-provider tooling
- Bash/htop permission issues caused by compiled Termux paths are now treated
  as `../zide-mobile-pm` artifact relocation output; Zide only consumes the
  resulting runtime-support-link metadata

Status:

- `AU-A3` is met for the first curated terminal-dev artifact
- device state reports `sha256-fb7b4fd4cd40` installed and launch-ready
- device smoke proves Bash, Git, ripgrep, Neovim headless, `htop`, and `gotop`
  from the staged prefix
- `./ops/android_terminal_host.py userland-smoke-baseline` now repeats that
  staged-device smoke
- stop here unless a real terminal workflow proves the current baseline is too
  thin

### `AN-A1` Interactive Neovim Terminal Baseline

Purpose:

- make Neovim the first serious terminal application used to harden Android
  terminal behavior

Acceptance:

- launch `nvim` from the live product shell, not only `--headless`
- verify screen clear/alternate-screen behavior is legible on Android GLES
- verify arrow/navigation input reaches Neovim through the current
  `InputConnection` + assist-bar model
- verify `Esc`, `Ctrl`, and resize/IME viewport behavior are usable enough for
  editing a small file
- verify pinch font zoom is usable while preserving keyboard defaults:
  single tap opens IME; pinch changes shared renderer zoom; long press remains
  unclaimed until a concrete product gesture owns it
- record any terminal-rendering or input gaps as concrete tickets instead of
  reopening package/userland architecture

Status:

- open
- package prerequisite is met by `AU-A3`
- operator/manual entrypoint is now explicit:
  `./ops/android_terminal_host.py userland-nvim-manual-check`
- performance-testing build entrypoint is now explicit too:
  `./ops/android_terminal_host.py --variant profile deploy`
- current Android pinch/zoom result is accepted for this lane:
  - host-side gesture policy is explicit and stable
  - raw detector churn is quantized/coalesced host-side
  - identical renderer prep churn is deduped
  - slow/medium pinch now feels strong on device
  - release-build large-burst pinch is acceptable for the current product
    target
  - any remaining extreme-burst refinement is deferred; it is not the active
    Android blocker anymore
- first gesture-control cut is implemented:
  - `ProductGestureController` owns terminal-surface touch gestures
  - single tap opens IME through one product route
  - pinch routes to shared renderer user zoom and forces terminal-grid resize
    through the existing Android GLES path
  - keyboard shortcuts/defaults are unchanged
- Android applies the zoom through the external-host renderer path, not the SDL
  window/input refresh path
- next honest proof is one tiny real edit flow:
  `nvim test.txt` → insert text → `Esc` → `:wq`
- current performance lane is explicit:
  - debug APK is no longer the only deploy path
  - shared-renderer product mode no longer keeps the old Java shell poll loop
    alive by default
  - next audit target is native renderer/font-scale cost, not more Android
    gesture guessing
- Android render-thread scrutiny now has explicit authority:
  `app_architecture/platform/android/ANDROID_RENDER_THREAD_CONTRACT.md`
- render-thread war prep is now in progress under the new audit-first workflow:
  - subcategory map is explicit
  - first audited subcategories are:
    - live font/scale/atlas path
    - render-entry submission path
    - resize/grid-fit work in draw flow
    - terminal widget presentation invalidation path
    - backend frame begin/submit mechanics
    - debug/observability contamination of product execution
    - remaining Android host/UI-thread contamination
  - next code cuts should come from that audited queue, not ad hoc tuning
- live font-scale first cut landed:
  - Android pinch frames no longer run the full active-font teardown/cache-reset
    path
  - live pinch updates shared renderer font sizes and cell metrics cheaply
  - live pinch also applies temporary glyph visual scaling so glyph size follows
    the updated cell geometry
  - product-fit grid sizing now remains active during pinch so the terminal
    cell background continues filling the host surface instead of lagging until
    gesture end
  - pinch end commits the expensive font rebuild once, after the interaction
    settles
  - queued desktop/user zoom now follows the same staged live-scale model
  - remaining font-scale war work is shared renderer ownership, not Android
    gesture plumbing
- render-entry submission first cut landed:
  - viewport and pinch interaction paths now mark redraw intent instead of
    synchronously calling the shared renderer frame submission path
  - surface lifecycle/redraw-needed and direct input still submit immediately
    because they remain lifecycle-critical or latency-critical at this stage
- resize/grid-fit audit result:
  - the lower terminal resize path currently treats cell-pixel changes and
    row/column changes as the same resize operation
  - that forces shared terminal reflow/PTTY/publication work even when a live
    zoom step only needs cell-metric/pixel-size metadata updated
  - first shared split landed:
    - stable-grid cell width/height changes now use a metric-only terminal
      runtime/FFI path
    - Android product-fit only uses full resize/reflow when rows or cols change
    - regression coverage proves stable rows/cols survive metric-only updates
  - draw-path fallback removed:
    - surface-available/redraw-needed and paced frame ticks now flush dirty
      product-fit grid state before frame submission
    - `drawLiveTerminalWidgetFrame(...)` no longer performs resize/layout work
    - Android bridge now names that pre-draw seam explicitly as flush-dirty
      product-fit grid before frame
- font-scale reference audit result:
  - the remaining pinch-end thickness snap is not an Android gesture problem
  - it is the expected seam between a live-scaled hinted glyph atlas and a
    newly rasterized/hinted committed atlas
  - ASCII warmup was rejected because it does not address size-specific
    FreeType hinting changes
  - next renderer cut should build a size-keyed font/atlas lifecycle instead of
    more Java-side gesture tuning
  - first committed-size lifecycle cut landed:
    - `TerminalFont` records committed raster pixel size
    - renderer font config retains committed terminal-font atlases by render
      scale plus raster pixel size
    - settled zoom commits can reuse a prepared terminal atlas instead of
      always destroying/recreating the active terminal font
    - the cache now keeps a bounded neighbor set: twelve raster-pixel sizes
  - presentation invalidation cut:
    - backend target availability is now tracked separately from cached
      presentation readiness
    - target-unavailable invalidation no longer discards cached terminal
      presentation content
    - geometry/content/overlay invalidation still marks cached presentation
      content stale
  - Android gesture tracking bug fixed:
    - `ScaleGestureDetector.getScaleFactor()` is incremental per event, so the
      host must accumulate factors between choreographer frames
    - slow pinch events are no longer dropped by comparing each incremental
      factor against the previous incremental factor
  - prepared terminal raster-size swap added:
    - active pinch now attempts a terminal-only committed raster swap when the
      rounded terminal raster-pixel size crosses into a prepared neighbor
    - the hot path still avoids full app/editor/icon font rebuilds
    - prepared neighbor window is now intentionally widened to `+-12`
      raster-pixel sizes so current Android pinch jumps can still land on a
      prepared committed atlas during the gesture
  - fast-pinch audit result:
    - slow pinch now looks correct because the live geometry path is no longer
      the primary blocker
    - Android exposed the remaining renderer-core ownership gaps clearly enough
      to justify the deeper terminal-font preparation work below
    - first prerequisite cut for that lane is now in:
      visible terminal glyph demand can be collected from the actual shared
      direct/shaped draw path as deduped prep entries
    - second prerequisite cut is now in:
      the terminal draw path stages renderer-owned prep requests keyed by
      committed raster size, render scale, and visible glyph demand
    - third prerequisite cut is now in:
      a dedicated renderer worker consumes those requests and publishes
      CPU-only prepared glyph rasters back into renderer-owned result state
    - fourth prerequisite cut is now in:
      the render thread adopts ready glyph rasters into the live committed
      terminal atlas before terminal draw lookup falls back to inline glyph
      realization
    - shared renderer/core pressure exposed by Android:
      `TerminalFont` creation was still coupled to GPU atlas allocation on the
      fallback path, so Android/GLES could not safely prepare committed target
      font state off-thread
    - first unblock landed:
      the async worker now uses a backend-agnostic CPU-prepared `TerminalFont`
      init path instead of the old GL-backed fallback
    - current accepted boundary, 2026-04-12:
      - release-build device testing now puts pinch/zoom responsiveness in the
        accepted range for the current Android terminal product lane
      - do not keep this open as an active polish war
      - reopen only if a concrete future product need proves the deferred
        extreme-burst edge case matters again
  - backend frame begin/submit scrutiny:
    - Android GLES frame-resource warmup now runs through an explicit preframe
      seam instead of lazy `beginFrame(...)` initialization
    - Android GLES surface/context acquire now routes through one explicit
      helper shared by preframe warmup and steady-state `beginFrame(...)`
    - submit-time queued surface replay is now explicitly labeled as
      frame-critical replay-before-present work across Android GLES, OpenGL,
      and Metal
    - debug capture/readback work is now separated by name from ordinary
      product presentation
    - Metal's terminal snapshot-cache refresh is explicitly named as product
      presentable state, not debug capture
    - behavior is unchanged; the point of this cut is to make the remaining
      submit work auditable before moving ownership
  - debug/observability contamination first cut:
    - terminal debug sample state now has an explicit `samples_enabled` gate
    - ordinary product rendering no longer writes terminal presentation,
      cursor-overlay, text-paint, or Metal fallback debug sample structs by
      default
    - future diagnostic capture must explicitly arm those samples instead of
      relying on always-on product-path writes
    - `FrameFamilySummary` remains always-on correctness state for terminal
      publication feedback
    - optional `PresentTrace` counters now advance only when `renderer.present`
      logging is enabled by config
    - frame submission logging now exits before reading trace state when that
      tag is disabled
    - frame-family/submission/execution correctness state now lives in
      `present_feedback_state.zig` instead of being defined by the trace module
    - frame-family and terminal-presentation correctness updates now route
      through `present_feedback_host.zig`; trace only mirrors optional counters
      when enabled
    - stale `editor_surface_solid_family` trace state and set/clear helpers are
      removed because they had no active consumer
    - `renderer.font` glyph-prep/adopt logs now check tag enablement before
      formatting hot-path messages
    - pinch/UI-scale zoom logs now check tag enablement before formatting
      gesture-pressure diagnostics
    - terminal key-path and hover info logs now check tag enablement before
      formatting ordinary product input-frame diagnostics
    - remaining renderer-font info telemetry for font init metrics and
      glyph-prep worker lifecycle now checks tag enablement before formatting
    - `Logger.logf(...)` now returns before formatting when no file, console,
      or group sink can emit the requested tag/level
    - present-capture arm/path/frame state now lives in an explicit capture
      state object instead of flat fields beside correctness/trace state
    - capture arm/reset/captured-path mutation now routes through
      `present_capture_host.zig`
- first iteration cut landed from that queue:
  - narrowed Android host/UI-thread contamination around stale transcript-era
    ownership
  - `ShellInputView` no longer triggers broad `refreshShellState()` on ordinary
    input paths
  - stale auto-follow behavior no longer forces bottom-follow just because IME
    or insets changed
  - bootstrap-state reload and shell-session poll are now explicit separate
    operations; the 150ms loop now names itself as debug refresh upkeep
  - ordinary status updates now use tracked bootstrap state instead of
    reloading bootstrap stamp state from disk on every call
  - the 150ms debug shell refresh loop is removed; debug upkeep now refreshes
    from explicit events instead of periodic main-thread polling
  - product bootstrap-blocker visibility no longer controls the frame loop as
    a hidden side effect; product frame-loop reevaluation is now explicit
  - debug status formatting no longer runs on ordinary product events while
    the debug view is hidden
  - shell poll telemetry, product shell state upkeep, and debug status-surface
    refresh are now separated inside the activity instead of sharing one broad
    refresh operation
  - install-state transitions now route through one explicit activity seam for
    blocker visibility, product frame-loop reevaluation, and status upkeep
  - product/debug view-mode transitions now route through explicit owner
    methods instead of repeated open-coded toggle sequences
  - shell restart now routes through one explicit activity seam instead of
    repeated manual restart / debug start / install-success restart sequences
  - lifecycle and surface callbacks now route their shared post-event shell
    refresh / frame-loop / status aftermath through one explicit activity seam
  - Metal ordinary pre-present replay now routes through one explicit helper
    instead of spelling replay/cache-refresh/replay inline inside
    `submitFrame(...)`
  - this cut is aimed directly at the product scroll snap-back / host-thickness
    issue, not at renderer internals yet
  - validation:
    - `./ops/android_terminal_host.py apk` passed
    - repo-wide `zig build` is currently blocked by an unrelated existing
      `font_manager.zig` doc-comment regression outside this Java cut
  - current stop reading:
    - the Android host is no longer the dominant performance/ownership mystery
      for terminal progress
    - keep Android host cleanup paused unless a concrete product bug proves a
      remaining mixed-ownership seam still matters
- current Android product-shell rule is now explicit:
  - direct PTY input must own its own native poll + shared-renderer draw path
  - product shell redraw must not depend on the old Java refresh loop or other
    incidental invalidation events like resize
- small Android userland polish cut in progress:
  - Bash should start in `$HOME`
  - history should persist in app-owned `~/.bash_history`
  - local `~/.bashrc` / `~/.profile` / `~/.inputrc` should exist without
    touching stale Termux global rc paths
  - default prompt should stay lightweight and product-boring

### `AU-A1` Android Userland Bootstrap

Purpose:

- replace Android system `sh` with a repo-owned Bash baseline
- create the first honest Android package-management contract for terminal work

Acceptance:

- one versioned app-private prefix exists
- staged Bash is device-proven from that prefix
- device proof shows `bash --version`
- package-manager authority is explicit (`apt` / `dpkg`), not a custom Android
  manager

Status:

- met for live Bash shell handoff; package-manager authority continues in
  `AU-A2`
- owner doc: `app_architecture/platform/android/ANDROID_USERLAND_BOOTSTRAP_PLAN.md`
- current device truth:
  - latest upstream aarch64 bootstrap can be downloaded and staged from Linux
  - staged Bash runs on-device under `run-as`
  - terminal-host now targets SDK 28 and launches staged Bash as the live
    product shell
  - product shell proof shows Bash running on-device; input smoke `pwd`
    returned `/`
  - `apt-get` reaches the network with relocation overrides after adding
    `android.permission.INTERNET`
  - `apt-get update` refreshes package metadata with staged certs and current
    overrides
  - `./ops/android_terminal_host.py userland-stage-artifact` now consumes the
    published Android dev manifest and stages the produced
    prefix archive as Zide's normal dev artifact contract
  - `./ops/android_terminal_host.py userland-stage-packages neovim htop gotop`
    remains available as an explicit dev-provider path for package-lane
    investigation, not the default Zide consumer contract
  - device validation proves `bash --version`, `nvim --version`,
    `nvim --headless +qall`, `htop --version`, and `gotop --version`
  - `btop` is not in the current Termux main aarch64 package index
  - direct on-device `apt-get install` is blocked by package payloads rooted
    under `/data/data/com.termux/...`

Immediate next step:

- treat the artifact-staged prefix as the normal dev bootstrap path
- define Android provider policy around the mobile package authority model:
  - `termux-main` remains the first supported Android provider
  - Zide keeps provider provenance explicit instead of making Termux the
    product identity
  - future Zide-owned Android providers may become the default without changing
    the `zide-pm` surface
- add one app-owned userland install/update state machine before more
  user-facing flow lands
- wire first-run/user-facing install/update around the published artifact
  contract instead of requiring the developer ops command
- stop this lane only when the package/userland layer is functional, correct,
  and boring enough that we do not need near-term refactors before returning to
  native rendering:
  - artifact-only install/update contract
  - explicit missing/current/upgrade-needed state
  - `zide-pm` staged as the intended first-class package surface
  - provider semantics explicit and decoupled from product identity

## Parked (not blocking)

`AS-A3` is now locally strong enough to stop blocking the next lane.

Reopen it only if real shell use proves a concrete input gap.

## Completed Tickets

### `AH-A1` Shared Native Host Surface Truth — met

`native_host.zig` carries surface availability, size, density, redraw, and
Android native-window identity with epoch-based transition tracking.

### `AH-A2` First Android Host Mapper — met

`android_host.zig` owns Android lifecycle/surface semantics. Shared code
delegates there instead of embedding Android logic in SDL input paths.

### `AH-A3` Android Host Harness — met, superseded

Java-only host harness proved Note10 callback ordering. Now superseded by
`android/terminal-host/` for all active work.

### `AS-A1` Android First Shell Bring-Up — met

`android_shell_session.zig` runs `/system/bin/sh` through the real terminal
engine. Note10 proved repeatable shell I/O via terminal FFI.

### `AS-A2` Android Live-Shell Product View — met

Product view is shell-first: shared renderer surface, slim assist bar,
restart/debug in a left drawer. IME uses window insets; tap terminal opens IME.

### `AS-A3` Android Direct Shell Input — locally sufficient, parked

Purpose:

- own the full Android terminal input surface — not a Termux clone, but a
  mobile-first model that treats modifier state, key sequences, and the assist
  bar as first-class UX rather than bolted-on workarounds

Acceptance:

- the modifier-latch assist bar replaces the current hardcoded per-combo Ctrl
  path: each modifier (Ctrl, Alt, Esc, Tab) is a toggle that latches down,
  next IME key tap sends the modified input, modifier releases
- no per-combo special casing for common sequences — the latch model covers
  them all without explicit buttons for each
- the assist bar visually reflects modifier state (latched vs idle)
- the live `InputConnection` path stays the single active input surface

Status:

- parked — first modifier-latch cut is locally device-validated enough to stop
  more speculative polishing:
  `Ctrl` is shell-validated and `Alt` is emitted-byte-validated
- owner doc: `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- direct JNI → Zig → PTY input path now exists:
  - `android_shell_session.zig` exposes direct send helpers
  - `android_bridge_exports.zig` exports `nativeSendShellCodepointBridge`
  - `ZideTerminalActivity` now owns a real `InputConnection` surface
- device validation on the Note10 now proves:
  - character input reaches the shell immediately
  - Enter and Backspace work directly
  - Samsung text-editing arrows now work through the editor model
- stale file-based input indirection has been removed from the active path

Current result:

- product input is no longer limited to “type a whole line then send”
- input latency is now JNI call overhead instead of 150ms poll interval
- the Android input path is now based on a minimal editor model rather than a
  fragile `TextWatcher`
- Java ownership is now split into Android-owned components instead of one
  activity blob:
  - `ShellInputView`
  - `ShellSessionController`
  - `AndroidDebugFormatter`
- the product shell now also follows a more honest mobile layout:
  - main terminal area keeps the screen
  - IME opens from terminal tap instead of a permanent toggle
  - a slim bottom assist bar now exposes:
    - one-shot `Esc` and `Tab`
    - stateful `Ctrl` and `Alt` latches
    - direct punctuation/arrow helpers
  - restart/debug live in a hidden left drawer instead of the main bar
- `ShellInputView` now owns modifier-latch state too:
  - tapping `Ctrl` or `Alt` arms the next IME/hardware key
  - the next input consumes the latch and clears the button state
  - the old hardcoded `Ctrl+C` / `Ctrl+D` assist buttons are gone
- operator tooling also now handles the common dual-endpoint phone setup:
  - `ops/android_terminal_host.py` auto-prefers the one USB device when both
    USB and `adb tcpip` endpoints are connected
  - otherwise it requires `ZIDE_ANDROID_SERIAL` / `ANDROID_SERIAL`
- local Java tooling is now explicitly supported for this Android app module:
  - JDTLS/Buildship imports should target `android/terminal-host/`, not repo
    root
  - `app/build.gradle` now declares Eclipse/Buildship source and library
    entries for:
    - `src/main/java`
    - Android SDK `android.jar`
    - generated debug `R.jar`
  - that keeps Neovim/JDTLS Android Java resolution honest without tracked
    `.classpath` / `.project` files

Remaining for this ticket:

- `Ctrl` latch is now proven on-device against a real shell command:
  - `sleep 99`
  - arm `CTRL`
  - inject `c`
  - prompt returns, proving the latch sends `^C` through the IME path
- `Alt` latch is now also proved on-device at the emitted-byte level:
  - arm `ALT`
  - inject `a`
  - the host send seam emits `ESC` followed by `a`
  - the next UI dump shows the latch returned to idle
- a fresh plain-text rerun on the current build also no longer reproduced the
  earlier duplicate compose/commit report
- once that is confirmed, treat the old hardcoded hardware-only Ctrl mapping as
  compatibility for physical keyboards, not as the product assist model
- stop here: do not extend special-key coverage further unless a real shell-use
  gap proves the current latch model materially insufficient

### `AH-A4` Android Terminal Host Bridge

Purpose:

- create the first repo-owned Android terminal-host path for the real Zig runtime,
  so Android progress can move from host probing into native entry/bridge work

Acceptance:

- the repo contains an Android app project for the real runtime lane
- the app loads a repo-built native Zig library
- launch + pause/resume + surface-available/lost callbacks reach repo-owned
  native bridge code
- build/install/run instructions are recorded in the owning docs

Status:

- met
- `android/terminal-host/` is the active Android runtime lane app
- the Note10 loads the repo-built Zig library and routes lifecycle/focus/
  surface callbacks into repo-owned native code
- surface identity now has stable authority:
  - `acquired`
  - `unchanged`
  - `replaced`
  - `retired`
- terminal-host/native entry is no longer the Android blocker

### `AP-A1` Android PTY Lifetime Ownership

Purpose:

- define the Android PTY/process lifetime baseline under pause/stop/background
  pressure before any real Android terminal integration

Status:

- met
- Note10 proved the disposable baseline:
  - PTY can outlive visible surface lifetime briefly
  - PTY does not outlive app-process death
- disposable app-process-owned PTY lifetime remains the default Android
  terminal baseline
- the earlier legacy PTY probe implementation is retired from the live app;
  this result remains as architecture evidence only

### `AP-A2` Android PTY Service Survival Probe

Purpose:

- define and execute the narrowest honest foreground-service-owned PTY probe
  without implying terminal product approval

Status:

- met as a separate probe lane
- foreground-service PTY survival is technically viable
- it did not displace the disposable baseline as the default answer
- the earlier legacy service probe implementation is retired from the live
  app; this result remains as architecture evidence only

### `AH-A5` Android GLES Binding Authority

Purpose:

- define the first Android EGL/GLES binding cut precisely enough that it can
  be implemented next without drifting into a fake Android renderer backend

Status:

- met as terminal-host-owned authority
- the terminal host app proves EGL/GLES clear/swap against the live
  `ANativeWindow`
- Note10 proof includes both replacement stories:
  - `replaced`
  - `retired -> acquired`
- current device policy reuses one EGL context while recreating the window
  surface

### `AH-A6` Android GLES Upload/Update Probe

Purpose:

- prove whether one terminal-host-owned GLES texture can survive the already-proved
  surface transitions while also accepting repeated content upload/update

Status:

- met
- terminal-host GLES proof now tracks upload/update separately
- Note10 proved one texture survives redraw and surface replacement while
  accepting repeated content updates

### `AH-A7` Android GLES Texture-Resize Pressure

Purpose:

- prove whether the current terminal-host GLES policy can stay honest when content
  size changes materially, not just when the surface is recreated or the same
  texture receives repeated updates

Status:

- met as terminal-host runtime evidence
- holder-driven size pressure advances texture upload/resize counts without
  hidden context churn on the Note10
- this remains runtime evidence, not product resize authority

### `AR-B1` Android Renderer Adoption Unblock

Purpose:

- execute only the next renderer cut that materially unblocks first-class
  Android renderer adoption

Owner docs:

- `docs/todo/ui/renderer.md`
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`

Status:

- met
- renderer gate #5 family-summary work landed:
  - `chrome_band`
  - `editor_row_band`
  - `sample_section`
- Android renderer adoption is no longer blocked by terminal-only frame family
  reporting
- present feedback now consumes shared frame-family truth instead of
  terminal-only submission meaning

Acceptance:

- the next renderer cut is explicit about what Android backend adoption would
  stop having to special-case afterward
- Android queue and renderer queue both point at the same blocker
- Android work returns here after that renderer cut lands

Do not do:

- no reopening gate #2 for active work unless Mac validation is explicitly
  reopened
- no generic renderer cleanup with no Android leverage
- no pretending terminal-host EGL proof by itself is equivalent to shared Android
  renderer readiness

Current follow-up:

- `AR-B1` is structurally complete
- `AR-B2` is also structurally complete:
  widget/runtime no longer carries direct-vs-retained terminal-present path
  decisions
- the next Android renderer adoption unblock is `AR-B3`:
  presentable lifecycle parity behind neutral types

## Current Research Read

- Android host truth is clearly native-window lifecycle truth, not persistent
  desktop-window truth.
- Native PTY subprocesses are viable on Android (`/dev/ptmx` + JNI subprocess
  launch is established practice).
- The real PTY risk is Android background/process policy, especially on Android
  12+, not basic PTY availability.
