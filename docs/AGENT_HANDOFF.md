## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- Primary active product lane: Linux native rendering-correctness catch-up after the recent Win11 integration and UI-improvement sprint, with current emphasis on finishing the scene-target / present migration cleanly on the native terminal path.
- Current implementation lane on `main`: renderer/present correctness and lifecycle-policy adoption, with terminal and editor sharing the same runtime vocabulary but terminal owning the immediate native-host rendering bug lane.
- Linux catch-up should focus first on restoring parity and polish in the shared Linux native host: renderer/input quality, Linux platform integration, runtime/lifecycle behavior, and concrete regressions or missing affordances left behind during the Windows lane.
- Editor work is currently in scope only where it advances lifecycle management, runtime policy, startup/resource behavior, or closely related observability/validation seams.
- Keep focused validation lanes healthy while runtime-policy work continues: terminal/editor targeted tests should stay runnable, and environment-sensitive host checks should not spill into focused behavior lanes without a clear reason.
- For editor visual/runtime defects, live GUI scripted repro is now the proving standard; focused scripted smokes and internal counters support it but do not replace it.
- Terminal quality bar remains: native terminal behavior should stay in the same band as `kitty` / `ghostty` for correctness, smoothness, compatibility, and steady-state cost, but terminal is not the active product invention lane right now.
- Native GUI remains the proving ground and reference host for both editor and terminal contracts. Keep native honest first, but do not let it become a privileged semantic path over FFI/embedded hosts.
- Windows shell scope is split intentionally:
  - packaged top-level Windows 11 Explorer integration is the supported surface
    and only needs follow-up for concrete regressions
  - legacy classic Explorer verbs are not the supported product surface
  - Windows default terminal integration is deferred indefinitely

### Current Direction

- The main VT/present rewrite is no longer the active invention lane on `main`, but post-rewrite rendering correctness remains an active cleanup lane where incomplete migration seams are still being closed.
- Default work now should be:
  - Linux native catch-up first, with one owning queue for parity gaps, regressions, and polish follow-up after the Windows week
  - terminal rendering correctness first where the scene-target / present migration still leaves native-host regressions
  - lifecycle/resource-management implementation and cleanup first
  - observability improvements that make lifecycle/runtime-policy behavior easier to validate and compare
  - Linux renderer/input/platform follow-up where Windows integration work or recent UI changes left Linux behind
  - targeted test/build-root cleanup where it materially improves validation quality for the active lanes
  - editor bug fixing only where it materially supports the lifecycle/runtime-policy lane
  - selective Windows shell follow-up only for the packaged Explorer command lane
- Keep current runtime-policy work cohesive before widening scope:
  - shared runtime vocabulary should stay the single authority for lifecycle/work-class naming
  - terminal wake/frame/latency and editor perf/open-startup work should continue adopting that same policy surface
  - prefer closing the current lifecycle/observability/test-hygiene loop before opening unrelated feature work
- Renderer architecture direction is already set:
  - narrow retained widget-local targets where they pay off
  - renderer-owned authoritative scene target
  - default framebuffer as present sink only

### Current State

- The scene-owned composition path is active on `main`.
- Rewrite-era present/debug baggage has been materially reduced from the live path.
- Recent terminal rendering-correctness work on `main` closed several real quality seams:
  - canonical per-frame terminal cell geometry now drives terminal-space consumers under fractional scale
  - duplicate focused block-cursor glyph drawing is removed
  - focused `.bar` cursor height now stays in logical space, so it matches row text at both `render_scale=1.00` and `render_scale=1.65`
- The next active terminal bug is a proven incomplete migration seam from the old `ascii-rain` / scene-target rewrite lane:
  - on some idle frames, the scene target is cleared and presented with `terminal_texture_draws=0`
  - input restores the foreground because a real redraw reintroduces the terminal blit
  - the remaining work is to make retained terminal presentation mandatory on any cleared frame that is submitted
- Recent git history closed a concentrated Win11 packaged-shell and UI-polish lane on `main`; the immediate follow-up is to bring Linux native behavior and product quality back up to the same bar before reopening broader platform work.
- The heaviest post-rewrite bug-hunting lane has cooled after recent fixes for `nvim`, `btop`, Codex inline history, Zig `std.Progress`, and focused input latency.
- The remaining Codex completion-tail terminal bug stays explicitly deferred; short re-checks against a candidate pacing/present seam change were encouraging, but not strong enough to close it.
- The main remaining engine gap is no longer random compatibility debt; it is that `TerminalSession` still carries more structural weight than a `libghostty-vt`-quality engine boundary would.
- The terminal FFI contract has now also survived an external peer-review host check in Flutty: the same widget/runtime layer works across bridge-owned PTY and Flutter-owned PTY transport, pending outbound input/report bytes keep focus/color-scheme reporting aligned across both modes, and a follow-up re-check confirmed external child-exit reporting keeps lifecycle truth aligned too. The remaining differences are transport-lifecycle mechanics, not terminal-semantics gaps.
- The latest Flutty re-check on `main` also confirmed the request-based metadata acquire cut was easy to adopt: hot scalar metadata reads now use explicit include flags cleanly, title/cwd became explicit cached host state instead of implicit always-present metadata payload, and redraw/viewport/lifecycle behavior did not regress.
- A later Flutty re-check against upstream `4c2a953e` confirmed the viewport-pinning regression is closed on current `main`: request-based snapshot adoption stayed straightforward, the redraw path naturally uses `include_flags = 0`, pinned viewport changes now affect acquired snapshot content, and no widget/runtime fork or local workaround logic was needed.
- The latest Flutty diff re-checks now close the first diff cut end-to-end: downstream removed the old cursor-preservation workaround, settled-baseline granular diff works after the upstream `present_ack(...)` retirement fix, one-acquire fallback remains clean, and startup PTY churn still stays outside the granular guarantee on purpose.
- Current implementation authority lives in the terminal architecture docs and owning todos, not in stale investigation notes.
- Recent lifecycle checkpoints on `main` are now closed:
  - editor workers stop and join before shell teardown
  - terminal PTY read/parse threads and transport teardown complete before shell teardown
  - terminal startup rollback is proven on both workspace and single-session app paths
  - terminal FFI handles reject host-visible calls once destroy begins
  - terminal `close_on_child_exit` is accepted frame-driven behavior: same-frame close when the child is already dead before the check, next-frame close when the child dies just after a prior check
- Recent `main` commits advanced the shared runtime-policy lane:
  - terminal lifecycle tiers now drive background polling behavior and poll-epoch resets
  - perf events and compare tooling now align on shared runtime/lifecycle/work-class fields across terminal and editor
  - editor visible background precompute now uses runtime-policy budget caps
  - editor file-open startup deferrals now route through runtime policy instead of hardcoded frame counts
- Local validation for that lane was completed with `zig build test` and `zig build` before the latest push.
- Current cross-machine setup blocker: `zig build grammar-update` can fail on `tree-sitter-proto` because the pinned upstream commit is no longer fetchable; retry with `--continue-on-error` if you only need the rest of the grammars, and treat the proto pin as follow-up work.
- Current Windows shell follow-up should focus on the packaged Explorer commands:
  - only reopen this lane for concrete packaged Explorer regressions
  - keep Windows default terminal integration deferred
- Working model for bug slices:
  - prove the boundary
  - make the smallest fix
  - validate on the real host path
  - commit the checkpoint

### Where To Look

- Linux native catch-up queue:
  - `docs/todo/linux/implementation.md`
- Terminal rendering correctness / present migration cleanup:
  - `docs/todo/terminal/wayland_present.md`
  - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
  - `docs/review/archive/TERMINAL_240HZ_RAIN_INVESTIGATION.md`
- Editor implementation authority:
  - `app_architecture/editor/DESIGN.md`
  - `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md`
  - `docs/todo/editor/README.md`
  - `docs/todo/editor/app_baseline.md`
- Present implementation authority:
  - `app_architecture/terminal/present/WAYLAND_DESIGN_BRIEF.md`
  - `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`
- Present execution queue:
  - `docs/todo/terminal/wayland_present.md`
- Terminal core architecture and active queue:
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
  - `docs/todo/terminal/vt_core_rearchitecture.md`
  - `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
  - `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`
  - `docs/todo/terminal/modularization.md`
- Repo workflow and doc ownership:
  - `AGENTS.md`
  - `docs/WORKFLOW.md`
  - `docs/INDEX.md`
 - Active Windows shell docs:
   - `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md`
   - `docs/todo/windows/implementation.md`
 - Grammar/setup follow-up if bootstrapping a new machine:
   - `tools/editor/grammar/grammar_update.zig`
   - `tools/editor/grammar/grammar_fetch.zig`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the relevant `app_architecture/` authority docs.
- `main` is the default branch unless isolation materially reduces risk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
