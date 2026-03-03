# Docs Index

Quick map of where to look for common needs.

## Start here (current focus + workflow)
- `docs/AGENT_HANDOFF.md` — current focus, constraints, and entrypoints.
- `AGENTS.md` — workflow rules and constraints.
- `docs/WORKFLOW.md` — doc roles and update rules.

## Task tracking (source of truth)
- `app_architecture/**/_todo.yaml` — active task lists and status.
  - `app_architecture/ui/renderer_todo.yaml` — renderer modularization + OS abstraction.
  - `app_architecture/ui/ui_widget_modularization_todo.yaml` — UI widget modularization (TerminalWidget/UI splits).
  - `app_architecture/ui/font_rendering_todo.yaml` — font rendering strategy + implementation plan (kitty/ghostty-tier goals).
  - `app_architecture/ui/sdl3_migration_todo.yaml` — SDL3 migration tracker.
  - `app_architecture/terminal/terminal_tabs_todo.yaml` — terminal-only tab/workspace lifecycle plan for `--mode terminal` and FFI follow-on.

## Architecture + design
- `app_architecture/ui/DEVELOPMENT_JOURNEY.md` — renderer plan and per-OS journey.
- `app_architecture/APP_LAYERING.md` — module boundaries and import rules.
- `app_architecture/editor/DESIGN.md` — editor architecture + references.
- `app_architecture/terminal/DESIGN.md` — terminal architecture + decisions.
- `app_architecture/terminal/TERMINAL_WORKSPACE.md` — backend tab/workspace ownership contract for terminal mode.
- `app_architecture/terminal/ffi_bridge_todo.yaml` — terminal backend embeddability / FFI bridge plan.
- `app_architecture/terminal/FFI_BRIDGE_DESIGN.md` — terminal bridge shape, ownership model, and smoke-host plan.
- `app_architecture/terminal/FFI_EVENT_INVENTORY.md` — host-facing terminal events and export classification.
- `app_architecture/terminal/FFI_EVENT_ABI.md` — exported event buffer layout, payload semantics, and ownership rules.
- `app_architecture/terminal/FFI_SNAPSHOT_ABI.md` — exported snapshot layout and ownership rules.
- `app_architecture/terminal/FFI_PTY_ABI.md` — PTY/session ownership model for the bridge.
- `app_architecture/terminal/DAMAGE_TRACKING.md` — terminal damage/dirty tracking notes + todo.
- `app_architecture/DECISIONS.md` — decision log.
- `app_architecture/ENGINEERING.md` — engineering guidelines (ownership, threading, FFI).
- `app_architecture/PLANNING.md` — active plans with status.

## Setup + usage
- `README.md` — user-facing overview.
- `app_architecture/BOOTSTRAP.md` — dependencies, bootstrap, build, run, test.
- `app_architecture/CONFIG.md` — Lua config subsystem: parser surface, merge rules, runtime consumers, and reload truth.
- `app_architecture/config_todo.yaml` — config subsystem tracker: contract drift, reload gaps, validation, and binding semantics.
- `docs/DEPENDENCIES.md` — native dependency setup (vcpkg + system packages).
- `docs/terminal/compatibility.md` — current beta terminal support surface, TERM identity, and terminfo install instructions.

## Reviews and audits
- `app_architecture/review/` — past review notes (scope + date in file).
