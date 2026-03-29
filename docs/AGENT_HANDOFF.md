## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- Primary active product lane: Linux native catch-up after the recent Win11 integration and UI-improvement sprint, with terminal work paused except for concrete regressions or contract follow-ups that already have clear authority.
- Current implementation lane on `main`: app-wide runtime scheduling/resource-management adoption, with terminal and editor as the first concrete adopters of the shared lifecycle/work-class policy seams.
- Linux catch-up should focus first on restoring parity and polish in the shared Linux native host: editor/IDE behavior, renderer/input quality, Linux platform integration, and any regressions or missing affordances that were deprioritized during the Windows lane.
- Within the editor lane, current product priority remains basic Notepad-grade usability and editor-only chrome: common shortcuts, expected mouse/selection behavior, file/open/save flows, friendly Lua config, and editor CLI behavior should land before optimization-focused work.
- Terminal quality bar remains: native terminal behavior should stay in the same band as `kitty` / `ghostty` for correctness, smoothness, compatibility, and steady-state cost.
- Native GUI remains the proving ground and reference host for both editor and terminal contracts. Keep native honest first, but do not let it become a privileged semantic path over FFI/embedded hosts.
- Windows shell scope is split intentionally:
  - packaged top-level Windows 11 Explorer integration is the supported surface
    and only needs follow-up for concrete regressions
  - legacy classic Explorer verbs are not the supported product surface
  - Windows default terminal integration is deferred indefinitely

### Current Direction

- The main VT/present rewrite is no longer the active invention lane on `main`.
- Default work now should be:
  - Linux native catch-up first, with one owning queue for parity gaps, regressions, and polish follow-up after the Windows week
  - editor app-level feature work and UX completion first
  - Linux renderer/input/platform follow-up where Windows integration work or recent UI changes left Linux behind
  - editor/widget bug fixing and quality passes
  - editor modularization/boundary cleanup only where it materially supports the feature lane or keeps the implementation clean
  - selective terminal follow-up only for already-open, high-confidence issues
  - selective Windows shell follow-up only for the packaged Explorer command lane
- Avoid optimization-led editor work until the common editor feature/config/CLI baseline is in place.
- Keep current runtime-policy work cohesive before widening scope:
  - shared runtime vocabulary should stay the single authority for lifecycle/work-class naming
  - terminal wake/frame/latency and editor perf/open-startup work should continue adopting that same policy surface
  - prefer closing the editor runtime-policy lane end-to-end before opening unrelated feature work
- Renderer architecture direction is already set:
  - narrow retained widget-local targets where they pay off
  - renderer-owned authoritative scene target
  - default framebuffer as present sink only

### Current State

- The scene-owned composition path is active on `main`.
- Rewrite-era present/debug baggage has been materially reduced from the live path.
- Recent git history closed a concentrated Win11 packaged-shell and UI-polish lane on `main`; the immediate follow-up is to bring Linux native behavior and product quality back up to the same bar before reopening broader platform work.
- The heaviest post-rewrite bug-hunting lane has cooled after recent fixes for `nvim`, `btop`, Codex inline history, Zig `std.Progress`, and focused input latency.
- The remaining Codex completion-tail terminal bug stays explicitly deferred; short re-checks against a candidate pacing/present seam change were encouraging, but not strong enough to close it.
- The main remaining engine gap is no longer random compatibility debt; it is that `TerminalSession` still carries more structural weight than a `libghostty-vt`-quality engine boundary would.
- The terminal FFI contract has now also survived an external peer-review host check in Flutty: the same widget/runtime layer works across bridge-owned PTY and Flutter-owned PTY transport, pending outbound input/report bytes keep focus/color-scheme reporting aligned across both modes, and a follow-up re-check confirmed external child-exit reporting keeps lifecycle truth aligned too. The remaining differences are transport-lifecycle mechanics, not terminal-semantics gaps.
- The latest Flutty re-check on `main` also confirmed the request-based metadata acquire cut was easy to adopt: hot scalar metadata reads now use explicit include flags cleanly, title/cwd became explicit cached host state instead of implicit always-present metadata payload, and redraw/viewport/lifecycle behavior did not regress.
- A later Flutty re-check against upstream `4c2a953e` confirmed the viewport-pinning regression is closed on current `main`: request-based snapshot adoption stayed straightforward, the redraw path naturally uses `include_flags = 0`, pinned viewport changes now affect acquired snapshot content, and no widget/runtime fork or local workaround logic was needed.
- The latest Flutty diff re-checks now close the first diff cut end-to-end: downstream removed the old cursor-preservation workaround, settled-baseline granular diff works after the upstream `present_ack(...)` retirement fix, one-acquire fallback remains clean, and startup PTY churn still stays outside the granular guarantee on purpose.
- Current implementation authority lives in the terminal architecture docs and owning todos, not in stale investigation notes.
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

### Where To Look

- Linux native catch-up queue:
  - `docs/todo/linux/implementation.md`
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
