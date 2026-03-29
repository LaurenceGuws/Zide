# Editor Work Queues

This folder holds active editor implementation queues.

Use it for:

- active editor/app feature work
- text-engine and editing semantics follow-up
- tree-sitter and grammar-pack rollout work
- modularization and boundary cleanup when it materially supports the feature lane

Current priority order:

- lifecycle/runtime correctness first
- observability and deterministic repro tooling where they materially improve
  runtime validation
- editor bug fixing only where it materially supports lifecycle/runtime policy,
  startup/resource behavior, or closely related validation seams
- modularization only where it keeps that lane clean or removes bad ownership

Current high-signal entrypoints:

- `app_baseline.md` — baseline editor/app queue when a concrete lifecycle or
  runtime slice depends on it
- `editor_action_baseline_register.md` — action-centric baseline checklist with reference bindings from common editors
- `protocol.md` — text-engine and editing semantics queue after the common app baseline
- `stress_and_reference.md` — active editor runtime/stress/proof queue
- `treesitter.md` — tree-sitter query/highlight integration queue
- `treesitter_dynamic_roadmap.md` — dynamic grammar-pack rollout order
- `theme_import.md` — resolved-theme export/import and schema-pressure queue

Maintenance or supporting queues:

- `widget.md` — mostly widget-specific follow-up after the current app-baseline lane
- `modularization.md` — structural cleanup only when it keeps the feature lane clean or removes bad ownership

Do not treat this folder as architecture authority. Durable design ownership
lives under `app_architecture/editor/`.

Current editor architecture authority entrypoints:

- `app_architecture/editor/DESIGN.md`
- `app_architecture/editor/FFI_DESIGN.md`
- `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
- `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`
