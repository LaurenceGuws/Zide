# Docs Index

Repo-local docs map for contributors, operators, and agents.

Customer-facing entrypoints live outside this index:

- `README.md` — top-level product overview, docs link, and release discovery.
- hosted docs explorer — `https://laurenceguws.github.io/Zide/tools/docs_explorer/`

Use this file for repo workflow and doc ownership navigation, not as the public
project landing page.

## Start Here
- `docs/AGENT_HANDOFF.md` — current focus, constraints, and entrypoints.
- `AGENTS.md` — workflow rules and constraints.
- `docs/WORKFLOW.md` — doc roles and update rules.

## Task tracking (source of truth)
- `app_architecture/*todo*.md` — active task lists and status.
  - `app_architecture/repo_structure_todo.md` — non-product repo structure cleanup (tests, tools, stale docs/tests).
  - `app_architecture/file_layout_todo.md` — file/folder layout cleanup queue (split large folders/files, collapse low-value micro-files).
  - `app_architecture/terminal/vt_core_rearchitecture_todo.md` — next terminal-core redesign lane: VT core, FFI-first boundary, and transport separation.
  - `app_architecture/ui/renderer_todo.md` — renderer modularization + OS abstraction.
  - `app_architecture/ui/ui_widget_modularization_todo.md` — UI widget modularization (TerminalWidget/UI splits).
  - `app_architecture/ui/font_rendering_todo.md` — font rendering strategy + implementation plan (kitty/ghostty-tier goals).
  - `app_architecture/ui/sdl3_migration_todo.md` — SDL3 migration tracker.
  - `app_architecture/dependencies_todo.md` — Zig-managed dependency migration plan (SDL3/FreeType/HarfBuzz/Lua/tree-sitter).
  - `app_architecture/terminal/terminal_tabs_todo.md` — terminal-only tab/workspace lifecycle plan for `--mode terminal` and FFI follow-on.

## Architecture + design
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` — renderer plan and per-OS journey.
- `app_architecture/APP_LAYERING.md` — module boundaries and import rules.
- `app_architecture/DEPENDENCIES.md` — dependency packaging architecture notes and migration constraints.
- `app_architecture/tools/DOCS_EXPLORER.md` — local docs-explorer scope, ownership, and constraints.
- `app_architecture/editor/DESIGN.md` — editor architecture + references.
- `app_architecture/terminal/DESIGN.md` — terminal architecture + decisions.
- `app_architecture/terminal/TERMINAL_WORKSPACE.md` — backend tab/workspace ownership contract for terminal mode.
- `app_architecture/terminal/VT_CORE_DESIGN.md` — exact target split for terminal core, transport, host session, snapshot, and FFI.
- `app_architecture/terminal/ffi_bridge_todo.md` — terminal backend embeddability / FFI bridge plan.
- `app_architecture/terminal/ffi_host_migration_todo.md` — combined terminal/editor FFI host migration follow-up checklist.
- `app_architecture/terminal/FFI_BRIDGE_DESIGN.md` — terminal bridge shape, ownership model, and smoke-host plan.
- `app_architecture/terminal/FFI_EVENT_INVENTORY.md` — host-facing terminal events and export classification.
- `app_architecture/terminal/FFI_EVENT_ABI.md` — exported event buffer layout, payload semantics, and ownership rules.
- `app_architecture/terminal/FFI_SNAPSHOT_ABI.md` — exported snapshot layout and ownership rules.
- `app_architecture/terminal/FFI_PTY_ABI.md` — PTY/session ownership model for the bridge.
- `app_architecture/terminal/DAMAGE_TRACKING.md` — terminal damage/dirty tracking notes + todo.
- `app_architecture/DECISIONS.md` — decision log.
- `app_architecture/ENGINEERING.md` — engineering guidelines (ownership, threading, FFI).

## Setup + Usage
- `README.md` — customer-facing overview, links, and quick-start pointers.
- `tests/README.md` — repo-wide test layout policy.
- `app_architecture/BOOTSTRAP.md` — dependencies, bootstrap, build, run, test.
- `tools/docs_explorer/README.md` — run instructions for the local docs explorer.
- `app_architecture/CONFIG.md` — Lua config subsystem: parser surface, merge rules, runtime consumers, and reload truth.
- `app_architecture/config_todo.md` — config subsystem tracker: contract drift, reload gaps, validation, and binding semantics.
<<<<<<< HEAD
- `docs/DEPENDENCIES.md` — current dependency sourcing policy: Zig-managed app stack on Linux/macOS, platform-runtime requirements, and Windows `vcpkg` exception.
=======
- `docs/DEPENDENCIES.md` — current dependency sourcing policy: Zig-managed app stack on Linux/macOS, platform-runtime requirements, and Windows `vcpkg` exception.
>>>>>>> main
- `docs/terminal/compatibility.md` — current beta terminal support surface, TERM identity, and terminfo install instructions.

## Reviews And Audits
- `app_architecture/review/` — past review notes (scope + date in file).
  - `app_architecture/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md` — Ghostty-informed review of remaining terminal-core architectural blockers.
  - `app_architecture/review/PERFORMANCE_REVIEW_1.md` — historical UI/terminal performance audit that still contains useful ownership notes.

Historical evidence remains under `app_architecture/review/`, but most files in
that folder are no longer first-class navigation docs.

## Quick Ownership Rules

- Use `docs/WORKFLOW.md` as the normative doc-placement policy.
- `README.md` and the hosted docs explorer are customer-facing.
- `docs/` is for active workflow, contributor/operator guidance, and top-level reference docs.
- `app_architecture/` is for current designs, plans, and todo trackers.
- `app_architecture/review/` is for historical reviews, audits, and investigation records.
