# Docs Index

Repo-local docs map for contributors, operators, and agents.

Customer-facing entrypoints live outside this index:

- `README.md` — top-level product overview, docs link, and release discovery.
- docs explorer repo — `https://github.com/LaurenceGuws/docs-explorer`

Use this file for repo workflow and doc ownership navigation, not as the public
project landing page.

Quick reading guide:

- start with `docs/AGENT_HANDOFF.md` if you are joining an active work session
- if you are doing active product work, default to the core queue and
  authority docs first
- use `docs/todo/` for current execution queues
- use `app_architecture/` for current technical authority
- use `docs/reference/`, `docs/research/`, and `docs/review/` for supporting material

## Start Here
- `docs/AGENT_HANDOFF.md` — current focus, constraints, and entrypoints.
- `AGENTS.md` — workflow rules and constraints.
- `docs/WORKFLOW.md` — doc roles and update rules.
- `docs/todo/core/ACTIVE_QUEUE.md` — current core work focus and next steps.
- `app_architecture/platform/android/RENDER_BACKEND.md` — Android host/backend
  authority for the Android platform lane.
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md` — current-state audit
  for the same backend contract.

## Task tracking (source of truth)
- `docs/todo/README.md` — active work-queue policy and ownership split.
  - `docs/todo/core/ACTIVE_QUEUE.md` — active core queue.
  - `docs/todo/android/implementation.md` — active Android terminal execution queue.
  - `docs/todo/linux/implementation.md` — temporary Linux-native catch-up queue after the Win11 integration sprint.
  - `docs/todo/macos/implementation.md` — first-class macOS implementation journey and milestone tracker.
  - `docs/todo/terminal/README.md` — terminal queue map and ownership split.
  - `docs/todo/ui/README.md` — UI queue map and execution lanes.
  - `docs/todo/editor/README.md` — editor queue map and execution lanes.
  - `docs/todo/editor/app_baseline.md` — current editor-first execution lane for Notepad-grade behavior, shortcuts, file flow, config, and CLI.
  - `docs/todo/editor/editor_action_baseline_register.md` — practical editor action baseline checklist while bindings stay Lua-owned.
  - `docs/todo/editor/stress_and_reference.md` — editor stress-testing and cross-reference comparison queue.
  - `docs/todo/repo_structure.md` — non-product repo structure cleanup (tests, tools, stale docs/tests).
  - `docs/todo/file_layout.md` — file/folder layout cleanup queue (split large folders/files, collapse low-value micro-files).
  - `docs/todo/terminal/vt_core_rearchitecture.md` — active VT maturity purity
    queue; currently deferred as the repo-wide default focus.
  - `docs/todo/terminal/widget_scrutiny.md` — active native terminal widget
    scrutiny queue for the host-side part of VT maturity; currently deferred as
    the repo-wide default focus.
  - `docs/todo/terminal/ffi_bridge.md` — terminal FFI/embedding contract maturation.
  - `docs/todo/terminal/ffi_host_migration.md` — mixed terminal/editor host migration follow-up.
  - `docs/todo/terminal/tabs.md` — terminal-only tab/workspace lifecycle follow-up.
  - `docs/todo/terminal/wayland_present.md` — present-path execution queue and validation lane.
  - `docs/todo/editor/treesitter_dynamic_roadmap.md` — dynamic grammar-pack rollout queue and execution order.
  - `docs/todo/ui/terminal_special_glyphs.md` — active terminal UI quality lane for special glyphs.
  - `docs/todo/ui/font_rendering.md` — remaining text-rendering quality work.
  - `docs/todo/ui/window_scale_geometry.md` — active app-wide scale and
    geometry ownership queue for one resolved widget/terminal contract.
  - `docs/todo/dependencies.md` — Zig-managed dependency migration plan (SDL3/FreeType/HarfBuzz/Lua/tree-sitter).
  - `docs/todo/app_hygiene_cleanup.md` — app/build/platform hygiene cleanup queue for dependency boundaries, SDL3 residue, and repo-contract hardening.

## Architecture + Design
- `app_architecture/platform/NATIVE_HOST_CONTRACT.md` — strict shared native
  host contract for lifecycle, surface, focus, IME, and present semantics.
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` — high-level renderer journey
  and priority map; orientation only, not the active queue.
- `app_architecture/ui/RENDER_BACKEND_CONTRACT.md` — target backend
  abstraction contract, with OpenGL and Metal as the reference implementations.
- `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md` — current renderer
  contract audit and ranked contradictions.
- `app_architecture/platform/NATIVE_HOST_REFERENCE_CROSSCHECK.md` — current
  native-host architecture pressure: live SDL/GL truth versus macOS/Android
  native lifecycle and surface rules.
- `app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md` — naming authority
  for platform host truth, optional features, and current runtime graphics
  truth.
- `app_architecture/platform/macos/RENDER_BACKEND.md` — macOS AppKit + Metal
  host/backend authority.
- `app_architecture/platform/macos/METAL_BACKEND_IMPLEMENTATION.md` — live
  Metal backend structure, ownership truth, and contributor workflow.
- `app_architecture/platform/android/RENDER_BACKEND.md` — Android Activity +
  `ANativeWindow` host/backend authority.
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md` — first
  repo-owned Android terminal-host bridge: native library loading, lifecycle,
  and surface callbacks into native code.
- `app_architecture/ui/WINDOW_SCALE_GEOMETRY_DESIGN.md` — exact public widget
  and terminal geometry contract plus first API deletion list for the scale
  ownership lane.
- `app_architecture/linux/INSTALLATION.md` — Linux local install and staged-release authority.
- `app_architecture/TOOLING_INSTALL_SURFACES.md` — cross-OS tooling intent model for smoke, local install, and staged release.
- `app_architecture/APP_LAYERING.md` — module boundaries and import rules.
- `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md` — runtime classes, lifecycle tiers, resource-budget policy, and measurement requirements.
- `app_architecture/DEPENDENCIES.md` — dependency packaging architecture notes and migration constraints.
- `app_architecture/windows/INSTALLATION.md` — supported Windows install layout and first installer path.
- `app_architecture/windows/NATIVE_SHELL_INTEGRATION.md` — deferred-scope note for advanced Windows shell integration beyond the active packaged Explorer lane.
- `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md` — active packaged `IExplorerCommand` lane for top-level Win11 Explorer integration.
- `app_architecture/windows/CHROME_POLICY.md` — Windows shell-service vs product-chrome ownership split.
- `app_architecture/windows/SNAP_LAYOUT_INTEROP.md` — persistent sink design for Win11 Snap Layout hover in integrated terminal chrome.
- `app_architecture/tools/DOCS_EXPLORER.md` — local docs-explorer scope, ownership, and constraints.
- `app_architecture/tools/PERFORMANCE_TOOLING.md` — first-class performance CLI, capture-artifact, and viewer split aligned with runtime/resource-management architecture.
- `app_architecture/tools/STRUCTURED_LOGGING.md` — structured event logging, grouped sink routing, and the logger/tooling seam.
- `app_architecture/editor/DESIGN.md` — editor architecture + references.
- `app_architecture/editor/FFI_DESIGN.md` — editor FFI boundary, ABI shape, and ownership rules.
- `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md` — resolved editor-theme artifact contract for the current Neovim import lane.
- `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md` — deferred LSP/semantic-token overlay boundary for editor theming.
- `app_architecture/terminal/DESIGN.md` — terminal architecture + decisions.
- `app_architecture/terminal/TERMINAL_WORKSPACE.md` — backend tab/workspace ownership contract for terminal mode.
- `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md` — deferred VT
  maturity campaign authority; resume through `docs/deferred/VT_MATURITY_FOCUS.md`.
- `app_architecture/terminal/VT_CORE_DESIGN.md` — exact target split for terminal core, transport, host session, snapshot, and FFI.
- `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` — finer subsystem-layer ownership map for host, transport, engine, publication, and presentation.
- `app_architecture/terminal/TERMINAL_WIDGET_HOSTING_DESIGN.md` — target
  ownership zones and migration rules for the native terminal widget under the
  VT maturity standard.
- `app_architecture/terminal/TERMINAL_BETA_CHECKPOINT.md` — high-level terminal checkpoint orientation for the current beta.
- `app_architecture/terminal/present/WAYLAND_DESIGN_BRIEF.md` — high-level present-path design target.
- `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md` — present-path ownership and architecture authority.
- `docs/todo/terminal/ffi_bridge.md` — terminal backend embeddability / FFI bridge plan.
- `docs/todo/terminal/ffi_host_migration.md` — combined terminal/editor FFI host migration follow-up checklist.
- `app_architecture/terminal/ffi/BRIDGE_DESIGN.md` — terminal bridge shape, ownership model, and smoke-host plan.
- `app_architecture/terminal/ffi/EVENT_INVENTORY.md` — host-facing terminal events and export classification.
- `app_architecture/terminal/ffi/EVENT_ABI.md` — exported event buffer layout, payload semantics, and ownership rules.
- `app_architecture/terminal/ffi/SNAPSHOT_ABI.md` — exported snapshot layout and ownership rules.
- `app_architecture/terminal/ffi/PTY_ABI.md` — PTY/session ownership model for the bridge.
- `app_architecture/DECISIONS.md` — decision log.
- `app_architecture/ENGINEERING.md` — engineering guidelines (ownership, threading, FFI).

## Setup + Usage
- `README.md` — customer-facing overview, links, and quick-start pointers.
- `docs/releases/v0.1.0-beta.8.md` — current beta checkpoint release notes.
- `tests/README.md` — repo-wide test layout policy.
- `app_architecture/BOOTSTRAP.md` — dependencies, bootstrap, build, run, test.
- `dev_references/README.md` — local development reference corpus contract and setup entrypoint.
- docs explorer repo — `https://github.com/LaurenceGuws/docs-explorer`
- `app_architecture/docs_browser/` — Zide-owned explorer config and docs index.
- `app_architecture/CONFIG.md` — Lua config subsystem: parser surface, merge rules, runtime consumers, and reload truth.
- `docs/todo/config.md` — config subsystem tracker: contract drift, reload gaps, validation, and binding semantics.
- `docs/DEPENDENCIES.md` — current dependency sourcing policy: Zig-managed app stack across platforms and platform-runtime requirements.

## Research + Reference
- `docs/reference/README.md` — reference-doc placement and role.
- `docs/research/README.md` — research-doc placement and role.
- `docs/research/APP_HYGIENE_REFERENCE_SCRUTINY_2026-04-01.md` — official-doc and reference-repo scrutiny for the app hygiene cleanup lane.
- `docs/research/SDL_GL_RENDERER_SCRUTINY_2026-04-02.md` — SDL3/OpenGL renderer scrutiny brief for renderer ownership, host seam, scene/present drift, and backend maturity.
- `docs/research/VULKAN_FIT_AUDIT_2026-04-06.md` — Vulkan/backend fit audit:
  blockers and honest feasibility vs current contract implementation (Review Chunk 3).
- `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md` — initial
  Ghostty/Zed pressure scan for the backend abstraction campaign.
- `docs/research/editor/README.md` — editor research subtree entrypoint.
- `docs/research/windows/README.md` — Windows shell/context-menu research subtree entrypoint.
- `docs/research/editor/EDITOR_REFERENCE_COMPARISON_2026-03-18.md` — first focused editor reference comparison by concern.
- `docs/research/editor/EDITOR_STRESS_RITUAL_2026-03-18.md` — first repeatable local editor stress workload and recording ritual.
- `docs/research/terminal/README.md` — terminal research subtree entrypoint.
- `docs/research/windows/WIN11_EXPLORER_COMMAND_REFERENCE_2026-03-25.md` — packaged Win11 Explorer command reference shape and Zide alignment.
- `docs/research/windows/WIN11_EXPLORER_COMMAND_MULTISELECT_2026-03-25.md` — local evidence and option framing for Win11 Explorer multi-select behavior.
- `docs/research/windows/WIN11_EXPLORER_COMMAND_VALIDATION_2026-03-25.md` — current packaged Win11 Explorer validation ritual and open verification questions.
- `docs/research/terminal/TERMINAL_LAYER_REFERENCE_NOTES.md` — per-layer reference-terminal notes behind the high-level terminal design doc.
- `docs/research/terminal/TERMINAL_FFI_PERFORMANCE_REVIEW_2026-03-15.md` — current terminal FFI hot-path performance review and snapshot-boundary constraints.
- `docs/reference/terminal_compatibility.md` — terminal compatibility, TERM identity, and terminfo install instructions.
- `docs/reference/terminal_terminfo_reference/` — reference terminfo dumps used to compare Zide’s advertised capability surface against peer terminals.
- `docs/reference/linux_resource_profiling.md` — supported Linux workflow for measuring process resource usage and correlating it with Zide subsystem counters.
- `docs/reference/tools_layout.md` — repository contract for `tools/` domain layout and placement rules.
- `docs/reference/terminal_redraw_capture_workflow.md` — redraw capture and replay-authority workflow for real terminal repros.
- `docs/reference/terminal_flutter_adapter_notes.md` — Flutter-style host adapter notes for the terminal bridge.
- `docs/reference/windows_win11_shell_validation.md` — repeatable local build/install/manual-check ritual for packaged Win11 Explorer integration.
- `docs/research/terminal/wayland_present/` — platform/present research and reference writeups for the Wayland present lane.

## Reviews And Audits
- `docs/review/` — past review notes (scope + date in file).
  - `docs/review/SDL_GL_RENDERER_AUDIT_2026-04-02.md` — ranked SDL3/OpenGL renderer findings on ownership shape, host seam maturity, scene/present drift, and backend honesty.
  - `docs/review/TERMINAL_DOGFOOD_REVIEW_2026-03-17.md` — structured record of the first major native terminal dogfood pass, issue ids, and final dispositions.
  - `docs/review/TERMINAL_WIDGET_HOSTILE_AUDIT_2026-04-04.md` — hostile audit
    of the native terminal widget stack and the current evidence baseline for
    widget-side VT maturity pressure.
  - `docs/review/TERMINAL_WIDGET_POST_FRONT_RERANK_2026-04-04.md` — rerank
    after the first widget-hosting fronts, naming retained-surface update
    planning as the next strongest contradiction.
  - `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md` — Ghostty-informed review of remaining terminal-core architectural blockers.
  - `docs/review/PERFORMANCE_REVIEW_1.md` — historical UI/terminal performance audit that still contains useful ownership notes.
  - `docs/review/TERMINAL_PROTOCOL_ACCURACY_REVIEW_2026-02-23.md` — detailed protocol source-review evidence and implementation history behind the active parity tracker.
- `docs/review/archive/terminal/README.md` — terminal rollout/archive subtree entrypoint.

Historical evidence remains under `docs/review/`, but most files there are no
longer first-class navigation docs. Older completed rollout records are grouped
under `docs/review/archive/`.

## Deferred Focuses

- `docs/deferred/README.md` — deferred focus index.
- `docs/deferred/VT_MATURITY_FOCUS.md` — former repo-wide VT default focus,
  now paused while backend abstraction quality takes priority.

## Quick Ownership Rules

- Use `docs/WORKFLOW.md` as the normative doc-placement policy.
- `README.md` and the docs explorer repo are customer-facing.
- `docs/` is for active workflow, contributor/operator guidance, top-level reference docs, and active work queues.
- `app_architecture/` is for current designs, boundaries, and technical authority.
- `docs/research/` and `docs/reference/` are for exploratory and reference material that should not masquerade as current architecture authority.
- `docs/review/` is for historical reviews, audits, and investigation records.
