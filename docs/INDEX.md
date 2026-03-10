# Docs Index

Quick map of where to look for common needs.

## Start here (current focus + workflow)
- `docs/AGENT_HANDOFF.md` — current focus, constraints, and entrypoints.
- `AGENTS.md` — workflow rules and constraints.
- `docs/WORKFLOW.md` — doc roles and update rules.

## Task tracking (source of truth)
- `app_architecture/**/_todo.yaml` — active task lists and status.
  - `app_architecture/repo_structure_todo.yaml` — non-product repo structure cleanup (tests, tools, stale docs/tests).
  - `app_architecture/file_layout_todo.yaml` — file/folder layout cleanup queue (split large folders/files, collapse low-value micro-files).
  - `app_architecture/terminal/vt_core_rearchitecture_todo.yaml` — next terminal-core redesign lane: VT core, FFI-first boundary, and transport separation.
  - `app_architecture/ui/renderer_todo.yaml` — renderer modularization + OS abstraction.
  - `app_architecture/ui/ui_widget_modularization_todo.yaml` — UI widget modularization (TerminalWidget/UI splits).
  - `app_architecture/ui/font_rendering_todo.yaml` — font rendering strategy + implementation plan (kitty/ghostty-tier goals).
  - `app_architecture/ui/sdl3_migration_todo.yaml` — SDL3 migration tracker.
  - `app_architecture/dependencies_todo.yaml` — Zig-managed dependency migration plan (SDL3/FreeType/HarfBuzz/Lua/tree-sitter).
  - `app_architecture/terminal/terminal_tabs_todo.yaml` — terminal-only tab/workspace lifecycle plan for `--mode terminal` and FFI follow-on.

## Architecture + design
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` — renderer plan and per-OS journey.
- `app_architecture/APP_LAYERING.md` — module boundaries and import rules.
- `app_architecture/DEPENDENCIES.md` — dependency packaging architecture notes and migration constraints.
- `app_architecture/editor/DESIGN.md` — editor architecture + references.
- `app_architecture/terminal/DESIGN.md` — terminal architecture + decisions.
- `app_architecture/terminal/TERMINAL_WORKSPACE.md` — backend tab/workspace ownership contract for terminal mode.
- `app_architecture/terminal/VT_CORE_DESIGN.md` — exact target split for terminal core, transport, host session, snapshot, and FFI.
- `app_architecture/terminal/ffi_bridge_todo.yaml` — terminal backend embeddability / FFI bridge plan.
- `app_architecture/terminal/ffi_host_migration_todo.md` — combined terminal/editor FFI host migration follow-up checklist.
- `app_architecture/terminal/FFI_BRIDGE_DESIGN.md` — terminal bridge shape, ownership model, and smoke-host plan.
- `app_architecture/terminal/FFI_EVENT_INVENTORY.md` — host-facing terminal events and export classification.
- `app_architecture/terminal/FFI_EVENT_ABI.md` — exported event buffer layout, payload semantics, and ownership rules.
- `app_architecture/terminal/FFI_SNAPSHOT_ABI.md` — exported snapshot layout and ownership rules.
- `app_architecture/terminal/FFI_PTY_ABI.md` — PTY/session ownership model for the bridge.
- `app_architecture/terminal/DAMAGE_TRACKING.md` — terminal damage/dirty tracking notes + todo.
- `app_architecture/DECISIONS.md` — decision log.
- `app_architecture/ENGINEERING.md` — engineering guidelines (ownership, threading, FFI).

## Setup + usage
- `README.md` — user-facing overview.
- `tests/README.md` — repo-wide test layout policy.
- `app_architecture/BOOTSTRAP.md` — dependencies, bootstrap, build, run, test.
- `app_architecture/CONFIG.md` — Lua config subsystem: parser surface, merge rules, runtime consumers, and reload truth.
- `app_architecture/config_todo.yaml` — config subsystem tracker: contract drift, reload gaps, validation, and binding semantics.
- `docs/DEPENDENCIES.md` — native dependency setup (vcpkg + system packages).
- `docs/terminal/compatibility.md` — current beta terminal support surface, TERM identity, and terminfo install instructions.

## Reviews and audits
- `app_architecture/review/` — past review notes (scope + date in file).
  - `app_architecture/review/FILE_LAYOUT_HOTSPOTS_REVIEW.md` — current structure smell review and reference-repo comparison.
  - `app_architecture/review/REPO_STRUCTURE_REVIEW.md` — repo hygiene review for tests, tooling roots, and stale docs/tests.
  - `app_architecture/review/SRC_APP_DOMAIN_MAP.md` — authoritative `src/app` ownership map for the ongoing folder cleanup.
  - `app_architecture/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md` — Ghostty-informed review of remaining terminal-core architectural blockers.
  - `app_architecture/review/app_mode_layering_todo.yaml` — completed mode-layering extraction tracker retained as historical rollout record.
  - `app_architecture/review/app_mode_layering_validation.md` — mode-layering extraction validation matrix and gate bundle authority.
  - `app_architecture/review/mode_binary_size_baseline.md` — focused-binary size snapshot used by the mode extraction lane.

## Doc ownership quick rule
- `docs/` — active workflow and top-level contributor/operator guidance.
- `app_architecture/` — active designs, plans, and todo trackers.
- `app_architecture/review/` — historical reviews, audits, and investigation records.
