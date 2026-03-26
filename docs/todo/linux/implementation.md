# Linux Native Catch-Up

## Scope

Track the temporary Linux-native catch-up lane after the recent Win11
integration and UI-improvement sprint.

This queue owns:

- Linux regressions or parity gaps exposed by recent shared editor/UI/platform
  work
- Linux-native editor/IDE-host polish that should land before returning to
  broader cross-platform invention lanes
- Linux renderer/input/window-system validation when recent changes were
  primarily exercised on Windows
- Linux-specific packaging, config-path, shell, or desktop-integration cleanup
  when it materially affects normal native use

This queue does not own:

- stable editor feature sequencing already tracked in `docs/todo/editor/`
- terminal architecture redesign tracked in `docs/todo/terminal/`
- Windows packaged Explorer command follow-up tracked in
  `docs/todo/windows/implementation.md`
- architecture authority; durable design belongs in `app_architecture/`

## Why This Queue Exists

Recent `main` history was intentionally dominated by Win11 packaged shell
integration and the UI/runtime work needed to make that lane solid. That was
the right call, but it means Linux now needs an explicit recovery lane instead
of relying on incidental fixes spread across editor, UI, and terminal todos.

Use this file as the temporary coordination point for Linux catch-up until the
highest-value Linux gaps are either closed or pushed back into their normal
owning subsystem queues.

## Current Direction

1. Re-establish Linux as the primary native proving ground for shared
   editor/IDE behavior.
2. Audit recent Windows-led and shared UI changes on Linux before starting new
   invention work.
3. Close platform regressions and obvious parity gaps with small, reviewable
   diffs.
4. Move any durable subsystem-specific follow-up back to the owning editor/UI
   or architecture docs once the Linux gap is understood.

## Priority Order

1. Linux launch/build/run truth and normal local workflow.
2. Shared editor/IDE-host usability on Linux.
3. Linux renderer/input/window-system correctness and quality.
4. Linux-native platform integration and polish.
5. Only then: broader optimization or new platform scope.

## Entry Points

- `docs/AGENT_HANDOFF.md`
- `docs/todo/editor/app_baseline.md`
- `docs/todo/ui/README.md`
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `app_architecture/editor/DESIGN.md`
- `src/platform/*`
- `src/app/*`
- `src/ui/*`

## Baseline Reset

- [ ] `LNX-00` Reconfirm Linux-native build and launch truth on current `main`
  - Expected checks:
    - `zig build`
    - `zig build -Dmode=editor`
    - `zig build -Dmode=terminal`
    - manual GUI launch in the shared IDE/editor host shape
  - Capture any immediate regressions here before splitting them into narrower
    tasks.
  - 2026-03-25 checkpoint:
    - `zig build` passed on Linux.
    - `zig build -Dmode=editor` passed on Linux.
    - `zig build -Dmode=terminal` initially failed on `main` due to a focused-mode
      stub drift in `src/app/input_actions_hooks_runtime.zig`: the terminal-mode
      `openForConfirmDirtyClose(...)` stub still had the old 2-argument shape
      after the real editor prompt API gained a third `pending_action`
      parameter.
    - The stub signature was corrected and `zig build -Dmode=terminal` now
      passes again.
    - `zig build gui-smokes-manual` also passed and launched all three GUI
      binaries on the active Linux Wayland backend.
  - Remaining exit criteria:
    - one manual Linux interaction pass still needs to confirm the launched
      editor, IDE, and terminal windows behave correctly after startup
    - record any runtime-only regressions separately from compile/build truth

- [ ] `LNX-01` Audit editor-baseline flows on Linux after the Windows sprint
  - Focus:
    - open/save/save-as/new flow
    - close/dirty confirmation
    - top-bar/menu routing
    - CLI open behavior
    - expected shortcut behavior on Linux key conventions
  - Move durable editor work back into `docs/todo/editor/app_baseline.md` once
    the Linux-specific gap is understood.
  - 2026-03-25 code audit:
    - Linux still uses the shared status-bar/path-prompt file flow rather than
      a native file dialog path.
    - Current code truth:
      - `src/platform/file_dialog.zig` returns `null` for all non-Windows
        platforms, so there is no Linux-native dialog implementation today.
      - `src/app/editor/path_prompt_state.zig` seeds Linux `Open`/`Save As`
        prompts from the current working directory, which is the active
        fallback surface for Linux file flow.
    - Direction change:
      - do not prioritize Linux portal/native dialog integration as the next
        catch-up step
      - current preferred path is to mature the shared status-bar surface into
        a mode host and make file flow a real `path` mode with fuzzy
        completion
      - current editor-focused status content should become explicit passive
        `editor` mode instead of behaving like default bar content
    - 2026-03-25 implementation checkpoint:
      - the first status-bar mode-host cut is now in code
      - current implementation uses an explicit passive/active status-bar UI
        model even though visible behavior is intentionally unchanged so far
      - next step is to move current path entry behind a real active `path`
        mode implementation rather than continuing with ad hoc prompt framing
    - Cross-cutting performance/resource direction now lives in:
      - `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md`
    - Priority change:
      - status-bar mode implementation is intentionally deferred for now while
        runtime/resource-management foundation work starts
    - Runtime-lifecycle constraint:
      - terminal `visible_inactive` is not implemented yet because current
        terminal workspace/runtime truth only distinguishes the active tab from
        non-active tabs; no real split-visible or secondary-visible terminal
        signal exists yet, so background tabs remain modeled as `hidden_warm`
        until UI/runtime visibility truth improves

- [ ] `LNX-02` Audit Linux renderer/input/window behavior after recent UI work
  - Focus:
    - Wayland/X11 launch behavior
    - window resize, scale, and focus transitions
    - IME/text-input rect behavior
    - mouse hit-testing and drag/selection behavior
    - any Linux-only visual regressions from recent shared UI changes
  - Push design-level conclusions into `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
    or the owning UI queue if the issue is not Linux-specific.

- [ ] `LNX-03` Recheck Linux-native platform affordances and defaults
  - Focus:
    - config/cache/data-path behavior
    - shell/terminal-here defaults where applicable
    - file dialog behavior on Linux
    - desktop-environment expectations that affect normal editor use
  - 2026-03-25 KDE finding:
    - after the launcher-title fix, KDE now shows distinct window labels for
      IDE/editor/terminal, but all three still fall back to the generic
      Wayland/default icon.
    - A Linux runtime icon path has now been added at SDL window creation time
      using the existing bundled PNG assets:
      - IDE/editor: `assets/icon/color_icon.png`
      - terminal: `assets/icon/zide_terminal_taskbar.png`
    - Important scope note:
      - SDL’s own Wayland guidance implies runtime window-icon calls may still
        be secondary to desktop-file metadata on some setups.
      - If KDE still shows the generic icon after this runtime fix, the next
        step is not more renderer work; it is Linux install-layout / desktop
        entry integration for the focused launchers.

## Working Rules

- Keep this queue product-focused: Linux native user-visible behavior first.
- Prefer fixing shared seams over adding Linux-only forks unless the platform
  truly requires it.
- Keep `.zide.lua` logging minimal and bug-scoped during Linux investigations.
- When a Linux issue turns out to be general editor/UI architecture, update the
  owning subsystem docs and leave only the Linux-specific tracking here.

## First Suggested Pass

1. Re-run the baseline build and launch checks on Linux and log concrete
   failures under `LNX-00`.
2. Walk the editor-baseline flow on Linux and record any parity gaps under
   `LNX-01`.
3. Exercise recent shared UI changes on the active Linux stack
   (Wayland first if available) and turn the first real regressions into
   scoped tasks.

## Current Findings

- Closed immediately:
  - terminal-focused Linux build regression from stale `openForConfirmDirtyClose`
    stub signature drift in `src/app/input_actions_hooks_runtime.zig`
- Confirmed baseline:
  - all three Linux build targets now compile
  - `gui-smokes-manual` launches editor, IDE, and terminal on Wayland
- Open Linux-specific product gap:
  - no native Linux file dialog path exists yet; Linux file flow still depends
    on the shared status-bar/path-prompt surface
  - In progress:
  - KDE/Wayland launcher icon validation after adding runtime SDL window-icon
    setup for the focused launchers
  - tool/install-surface standardization research; current Linux local install
    channels (`stable` / `test`) should align with the shared cross-OS contract
    in `app_architecture/TOOLING_INSTALL_SURFACES.md`
  - first alignment cut now uses Linux local channel names `stable` / `dev`,
    with `test` retained only as a compatibility alias during migration
  - Linux stage-release is no longer terminal-only by default; the active local
    staging path is now `ops/linux/Stage-CurrentLinuxDist.sh` for IDE,
    editor, terminal, and both FFI artifacts together
  - Windows tooling standardization is intentionally deferred to a real Windows
    session; the next Windows-native agent should start from
    `app_architecture/TOOLING_INSTALL_SURFACES.md` and
    `app_architecture/windows/INSTALLATION.md`
  - verified 2026-03-25:
    - `bash ops/linux/Stage-CurrentLinuxDist.sh` completed and produced:
      - `zide-ide-bundle-0.1.0-beta.4-linux-x86_64.tar.gz`
      - `zide-editor-bundle-0.1.0-beta.4-linux-x86_64.tar.gz`
      - `zide-terminal-bundle-0.1.0-beta.4-linux-x86_64.tar.gz`
      - `zide-editor-ffi-0.1.0-beta.4-linux-x86_64.tar.gz`
      - `zide-terminal-ffi-0.1.0-beta.4-linux-x86_64.tar.gz`
      - `SHA256SUMS-linux-x86_64.txt`
  - 2026-03-26 resource-measurement checkpoint:
    - added `tools/observability/perf/linux_resource_monitor.py` as the supported local Linux
      process sampler for CPU, RSS, virtual memory, threads, fds, IO, context
      switches, and optional NVIDIA per-process graphics metrics
    - added `docs/reference/linux_resource_profiling.md` to define the
      operator workflow and the boundary between host-resource measurement and
      Zide-owned subsystem counters
    - added `app_architecture/tools/PERFORMANCE_TOOLING.md` to define the
      first-class tooling direction:
      - CLI remains canonical
      - capture artifacts become the contract
      - future internal viewer should be a TypeScript client of those artifacts
        rather than a second telemetry system
    - added `app_architecture/tools/STRUCTURED_LOGGING.md` to define the next
      logger/tooling seam:
      - one logger system
      - optional text vs JSONL output modes
      - grouped tag-family sinks for machine capture and easy grepping
    - first implementation cut is now in:
      - `src/app_logger.zig` supports `text` and `jsonl` output modes
      - Lua config now applies `logs.mode`, `logs.file_mode`,
        `logs.console_mode`, and direct `log_file_output_mode` /
        `log_console_output_mode`
      - grouped sink routing is now implemented through `logs.groups` with
        exact-tag and `prefix.*` wildcard matching
      - the first structured-field producers are now in for:
        - `terminal.frame`
        - `input.latency`
        - `terminal.wake`
        - `editor.perf`
      - `tools/observability/perf/linux_perf_run.py` now packages first-class perf run folders
        with:
        - `manifest.json`
        - `host_resources.jsonl`
        - `summary.json`
        - optional `subsystem_events.jsonl`
        - optional `notes.txt`
      - the perf runner can now temporarily wire grouped perf sink logging
        through `./.zide.lua` for launched Zide workloads and restore the
        prior file after capture
      - perf-tag selection is now exposed as named presets in the runner
        instead of only as hidden hard-coded defaults
      - broader subsystem migration still remains before text `msg` can be
        treated as human-only across the board
    - 2026-03-26 tooling-layout follow-up:
      - completed the `tools/` domain-layout cleanup end to end
      - `tools/` root now contains directories only; no loose root tool files
        remain
      - added `docs/reference/tools_layout.md` as the contributor/operator
        contract for tool-domain placement and update rules
      - fixed the moved input import-check wiring so `zig build
        check-input-imports` works again with the new layout
      - revalidated moved tooling surfaces with:
        - `zig build test`
        - `zig build check-build-report-tools`
        - `zig build check-app-imports`
        - `zig build check-editor-imports`
        - `zig build check-input-imports`
        - `zig build report-build-profiles`
        - `python3 -m py_compile ...` across moved Python entrypoints
        - `bash -n ...` across moved shell entrypoints and updated scripts
        - `python3 tools/observability/perf/linux_perf_run.py --help`
        - `python3 tools/observability/perf/linux_resource_monitor.py --help`
        - `python3 tools/observability/perf/linux_perf_run.py --label layout_smoke ...`
      - repo-wide path sweep for old flat tool-file references is now clean
      - remaining failures seen during the sweep are pre-existing repo issues,
        not layout regressions:
        - `zig build check-terminal-imports`
        - `zig build check-build-deps`
        - `zig build report-build-deps`
    - Linux `install-local` now installs the full launcher family per channel:
      - `zide[-stable|-dev]`
      - `zide-editor[-stable|-dev]`
      - `zide-terminal[-stable|-dev]`
    - Linux `install-local` now also has symmetric channel-family removal:
      - `ops/linux/install-local/remove_channel.sh <stable|dev>`
      - `ops/linux/install-local/remove_channels.sh`
    - Linux `install-local` now has explicit in-place sync entrypoints:
      - `ops/linux/install-local/sync_channel.sh <stable|dev>`
      - `ops/linux/install-local/sync_channels.sh`
    - install/remove scripts now refresh desktop, icon, and KDE cache indexes
      after mutating launcher metadata
    - canonical Linux `install-local` entrypoints now live under
      `ops/linux/install-local/`; the legacy `scripts/dev/*` wrappers were
      removed during the repo-structure cleanup
    - first desktop-entry maturity pass now adds richer metadata on Linux local
      launchers:
      - `GenericName`
      - `Comment`
      - `TryExec`
      - `Keywords`
      - sibling actions across the launcher family:
        - IDE: `Open Editor`, `Open Terminal`
        - editor: `Open IDE`, `Open Terminal`
        - terminal: `Open IDE`, `Open Editor`
    - first code adoption of runtime/resource-management architecture:
      - `src/app/runtime_policy.zig` now defines shared runtime vocabulary for:
        - runtime kind
        - lifecycle tier
        - work class
        - runtime intent
      - terminal poll-profile selection now routes through that shared runtime
        intent model instead of a raw `has_input` boolean
